// Cloudflare Worker: 24/7 Live Score Poller & Edge Cache
// Runs every 1 minute via Cron Trigger (* * * * *)
// - Fetches ESPN open scoreboards for ALL tracked leagues globally (70+ leagues)
// - Detects when a GOAL is scored or match state changes
// - Authenticates securely with Google Firebase v1 API using Web Crypto RSA-SHA256 (0 dependencies)
// - Sends instant FCM Push Notifications to topic 'live_scores'
// - Caches live data in KV for instant Flutter app retrieval (<15ms)

// Every league the app tracks — synced 1:1 with scraper.mjs ESPN_LEAGUES list.
// All fetched concurrently via Promise.all, so adding more leagues costs ~0ms.
const WATCHED_LEAGUES = [
  // ── England ──────────────────────────────
  'eng.1',            // Premier League
  'eng.2',            // Championship
  'eng.3',            // League One
  'eng.4',            // League Two
  'eng.fa',           // FA Cup
  'eng.league_cup',   // EFL Cup

  // ── Spain ────────────────────────────────
  'esp.1',            // La Liga
  'esp.2',            // Segunda División
  'esp.copa_del_rey', // Copa del Rey

  // ── Italy ────────────────────────────────
  'ita.1',            // Serie A
  'ita.2',            // Serie B
  'ita.coppa_italia', // Coppa Italia

  // ── Germany ──────────────────────────────
  'ger.1',            // Bundesliga
  'ger.2',            // 2. Bundesliga
  'ger.dfb_pokal',    // DFB Pokal

  // ── France ───────────────────────────────
  'fra.1',            // Ligue 1
  'fra.2',            // Ligue 2
  'fra.coupe_de_france', // Coupe de France

  // ── Other European Leagues ────────────────
  'ned.1',            // Netherlands - Eredivisie
  'por.1',            // Portugal - Primeira Liga
  'tur.1',            // Turkey - Süper Lig
  'bel.1',            // Belgium - Pro League
  'sco.1',            // Scotland - Premiership
  'gre.1',            // Greece - Super League
  'rus.1',            // Russia - Premier League
  'ukr.1',            // Ukraine - Premier League
  'aut.1',            // Austria - Bundesliga
  'sui.1',            // Switzerland - Super League
  'den.1',            // Denmark - Superliga
  'nor.1',            // Norway - Eliteserien
  'swe.1',            // Sweden - Allsvenskan
  'pol.1',            // Poland - Ekstraklasa
  'cze.1',            // Czech Republic - First League

  // ── Americas ─────────────────────────────
  'mex.1',            // Mexico - Liga MX
  'usa.1',            // USA - MLS
  'bra.1',            // Brazil - Série A
  'arg.1',            // Argentina - Liga Profesional
  'chi.1',            // Chile - Primera División
  'col.1',            // Colombia - Primera A

  // ── Middle East & Africa ─────────────────
  'ksa.1',            // Saudi Arabia - Pro League (ESPN official slug)
  'sau.1',            // Fallback alias
  'zaf.1',            // South Africa - Premier League

  // ── Global Catch-All ─────────────────────
  'all',              // All worldwide soccer events for today (catches friendlies, cups, regional leagues)

  // ── UEFA Club Competitions ────────────────
  'uefa.champions',   // Champions League
  'uefa.europa',      // Europa League
  'uefa.europa.conf', // Conference League

  // ── CONMEBOL Club Competitions ────────────
  'conmebol.libertadores', // Copa Libertadores
  'conmebol.sudamericana', // Copa Sudamericana

  // ── International / Major Tournaments ─────
  'fifa.world',       // FIFA World Cup
  'uefa.euro',        // UEFA Euro
  'uefa.nations',     // UEFA Nations League
  'caf.nations',      // Africa Cup of Nations
  'conmebol.america', // Copa America
  'concacaf.gold',    // CONCACAF Gold Cup
  'afc.asian',        // AFC Asian Cup
];

export default {
  // 1. Flutter App reads data from here (Edge CDN, <15ms)
  async fetch(request, env, ctx) {
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, HEAD',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Max-Age': '86400',
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }

    try {
      const url = new URL(request.url);
      const isManualRefresh = url.searchParams.get('refresh') === '1' || url.pathname === '/refresh';

      if (isManualRefresh) {
        // Trigger live cycle immediately on demand
        await this.scheduled({ scheduledTime: Date.now() }, env, ctx);
      }

      const data = await env.SCORES_KV.get('latest_soccer_data', { type: 'text' });

      if (!data) {
        return new Response(
          JSON.stringify({ status: 'waiting', message: 'First live cycle running...' }),
          { status: 200, headers }
        );
      }

      return new Response(data, { status: 200, headers });
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'KV read error', message: e.message }),
        { status: 500, headers }
      );
    }
  },

  // 2. Scheduled Cron Trigger — Runs every 1 minute
  async scheduled(event, env, ctx) {
    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10).replace(/-/g, '');

    let hasLiveGame = false;

    // Fetch scoreboards concurrently for speed
    const requests = WATCHED_LEAGUES.map(async (slug) => {
      try {
        const limitParam = slug === 'all' ? '&limit=200' : '';
        const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${slug}/scoreboard?dates=${dateStr}${limitParam}`;
        const res = await fetch(url, {
          headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
        });
        if (!res.ok) return [];
        const json = await res.json();
        return json.events || [];
      } catch (_) {
        return [];
      }
    });

    const results = await Promise.all(requests);
    const allEvents = results.flat();

    if (allEvents.length === 0) {
      return; // No events scheduled today; sleep immediately
    }

    // Process event snapshot
    const snapshot = {};
    for (const evt of allEvents) {
      const comp = evt.competitions?.[0];
      if (!comp) continue;

      const home = comp.competitors?.find(c => c.homeAway === 'home');
      const away = comp.competitors?.find(c => c.homeAway === 'away');
      const state = comp.status?.type?.state; // 'pre', 'in', 'post'
      const detail = comp.status?.type?.detail || '';
      const shortDetail = comp.status?.type?.shortDetail || detail;
      const clock = comp.status?.displayClock || '';

      if (state === 'in') {
        hasLiveGame = true;
      }

      const homeTeam = home?.team?.displayName || home?.team?.name || 'Home';
      const awayTeam = away?.team?.displayName || away?.team?.name || 'Away';
      const homeScore = parseInt(home?.score || '0', 10);
      const awayScore = parseInt(away?.score || '0', 10);
      const slugKey = `${homeTeam}-${awayTeam}`.replace(/\s+/g, '-');
      const normKey = `${homeTeam.toLowerCase().replace(/[^a-z0-9]/g, '')}-${awayTeam.toLowerCase().replace(/[^a-z0-9]/g, '')}`;

      // Extract goal scorers and match events (cards, goals, subs)
      const homeId = String(home?.id || '');
      const details = comp.details || [];
      const events = details.map(d => {
        const athlete = d.athletesInvolved?.[0] || {};
        const teamId = String(d.team?.id || '');
        const isHome = teamId === homeId;
        const player = athlete.displayName || athlete.shortName || 'Unknown';
        const typeText = d.type?.text || (d.scoringPlay ? 'Goal' : (d.redCard ? 'Red Card' : (d.yellowCard ? 'Yellow Card' : 'Event')));
        return {
          type: typeText,
          clock: d.clock?.displayValue || '',
          team: isHome ? 'home' : 'away',
          player: player,
          scoringPlay: !!d.scoringPlay,
          redCard: !!d.redCard,
          yellowCard: !!d.yellowCard,
          penalty: !!d.penaltyKick,
          ownGoal: !!d.ownGoal
        };
      });

      const homeScorers = events
        .filter(ev => ev.team === 'home' && ev.scoringPlay)
        .map(ev => `${ev.player} ${ev.clock}${ev.penalty ? ' (P)' : ''}${ev.ownGoal ? ' (OG)' : ''}`);

      const awayScorers = events
        .filter(ev => ev.team === 'away' && ev.scoringPlay)
        .map(ev => `${ev.player} ${ev.clock}${ev.penalty ? ' (P)' : ''}${ev.ownGoal ? ' (OG)' : ''}`);

      const matchData = {
        id: evt.id,
        name: evt.name,
        state: state,
        clock: clock,
        detail: detail,
        shortDetail: shortDetail,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeScore: homeScore,
        awayScore: awayScore,
        events: events,
        homeScorers: homeScorers,
        awayScorers: awayScorers,
      };

      // Index by ESPN event ID, team slug, and normalized name
      snapshot[evt.id] = matchData;
      snapshot[slugKey] = matchData;
      snapshot[normKey] = matchData;
    }

    // Retrieve previous snapshot from KV
    const prevRaw = await env.SCORES_KV.get('live_snapshot', { type: 'json' });
    const prevSnapshot = prevRaw || {};

    // Detect Goals and State Changes
    const goalAlerts = [];
    for (const [id, match] of Object.entries(snapshot)) {
      // Only process numeric event IDs to avoid duplicate alerts from slug keys
      if (!/^\d+$/.test(id)) continue;

      const prev = prevSnapshot[id];
      if (prev && match.state === 'in') {
        // Goal scored!
        if (match.homeScore > prev.homeScore) {
          const latestGoal = (match.events || []).filter(e => e.team === 'home' && e.scoringPlay).slice(-1)[0];
          const scorerName = latestGoal ? latestGoal.player : match.homeTeam;
          goalAlerts.push({
            title: `⚽ GOAL! ${scorerName} (${match.homeTeam})`,
            body: `${scorerName} scored! (${match.clock || match.shortDetail})\n${match.homeTeam} ${match.homeScore} - ${match.awayScore} ${match.awayTeam}`,
            matchId: id,
          });
        } else if (match.awayScore > prev.awayScore) {
          const latestGoal = (match.events || []).filter(e => e.team === 'away' && e.scoringPlay).slice(-1)[0];
          const scorerName = latestGoal ? latestGoal.player : match.awayTeam;
          goalAlerts.push({
            title: `⚽ GOAL! ${scorerName} (${match.awayTeam})`,
            body: `${scorerName} scored! (${match.clock || match.shortDetail})\n${match.homeTeam} ${match.homeScore} - ${match.awayScore} ${match.awayTeam}`,
            matchId: id,
          });
        }
      }
    }

    // Send FCM Push notifications for any detected goals
    if (goalAlerts.length > 0 && env.FIREBASE_SERVICE_ACCOUNT && ctx?.waitUntil) {
      ctx.waitUntil(broadcastGoalAlerts(goalAlerts, env.FIREBASE_SERVICE_ACCOUNT));
    }

    // Save live snapshot
    const newSnapshotStr = JSON.stringify(snapshot);
    await env.SCORES_KV.put('live_snapshot', newSnapshotStr);

    // Load existing full dataset to preserve AI predictions, form, standings
    let existingData = await env.SCORES_KV.get('latest_soccer_data', { type: 'json' });
    if (!existingData) existingData = { matchesData: { matches: [] } };
    if (!existingData.matchesData) existingData.matchesData = { matches: [] };

    const existingMatches = existingData.matchesData.matches || [];

    // Update live score, elapsed minute, status, and goal scorers for matching games
    for (const m of existingMatches) {
      const slugKey = `${m.homeTeam}-${m.awayTeam}`.replace(/\s+/g, '-');
      const normKey = `${(m.homeTeam || '').toLowerCase().replace(/[^a-z0-9]/g, '')}-${(m.awayTeam || '').toLowerCase().replace(/[^a-z0-9]/g, '')}`;
      const live = (m.espnEventId && snapshot[m.espnEventId]) || snapshot[m.id] || snapshot[slugKey] || snapshot[normKey];

      if (live) {
        m.homeScore = live.homeScore;
        m.awayScore = live.awayScore;
        m.events = live.events || [];
        m.homeScorers = live.homeScorers || [];
        m.awayScorers = live.awayScorers || [];

        if (live.state === 'in') {
          m.status = 'live';
          m.statusShort = live.shortDetail || live.detail || live.clock || 'LIVE';
          const parsedMin = parseInt(live.clock || live.detail || '0', 10);
          if (!isNaN(parsedMin) && parsedMin > 0) {
            m.elapsed = parsedMin;
          }
        } else if (live.state === 'post') {
          m.status = 'finished';
          m.statusShort = 'FT';
        }
      }
    }

    existingData.matchesData.lastUpdated = now.toISOString();
    existingData.matchesData.hasLiveGame = hasLiveGame;

    await env.SCORES_KV.put('latest_soccer_data', JSON.stringify(existingData));
  },
};

// ─── Firebase HTTP v1 Modern Authentication & Push Sender ────────────────────

async function broadcastGoalAlerts(alerts, saJsonString) {
  try {
    const sa = typeof saJsonString === 'string' ? JSON.parse(saJsonString) : saJsonString;
    const token = await getGoogleOAuth2Token(sa);
    if (!token) return;

    const projectId = sa.project_id || 'ai-football-predictions-a6ff9';
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    for (const alert of alerts) {
      await fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            topic: 'live_scores',
            notification: {
              title: alert.title,
              body: alert.body,
            },
            data: {
              matchId: String(alert.matchId),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channel_id: 'live_scores_channel',
              },
            },
          },
        }),
      });
    }
  } catch (err) {
    console.error('Failed to send goal alerts via Firebase v1:', err);
  }
}

// Generate Google OAuth2 Access Token using Web Crypto RSA-SHA256
async function getGoogleOAuth2Token(serviceAccount) {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const privateKey = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedJwt,
    }),
  });

  if (!res.ok) {
    console.error('OAuth token exchange failed:', await res.text());
    return null;
  }

  const json = await res.json();
  return json.access_token;
}

function base64UrlEncode(input) {
  let base64;
  if (typeof input === 'string') {
    base64 = btoa(unescape(encodeURIComponent(input)));
  } else {
    base64 = btoa(String.fromCharCode(...new Uint8Array(input)));
  }
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem) {
  const cleanPem = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = atob(cleanPem);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
}
