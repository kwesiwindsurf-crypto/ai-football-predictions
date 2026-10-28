import http from 'http';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import zlib from 'zlib';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ─── Environment & Config ────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
const CLOUDFLARE_SEED_URL = process.env.CLOUDFLARE_SEED_URL || 'https://ai-football-bot.xantechs00.workers.dev';
const POLL_INTERVAL_MS = 30 * 1000; // Poll ESPN every 30 seconds in memory (0 quota!)

// Load Firebase Service Account if available (for goal push notifications)
let serviceAccount = null;
const saPath = path.join(__dirname, 'service_account.json');
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } catch (e) {
    console.warn('⚠️ Could not parse FIREBASE_SERVICE_ACCOUNT env:', e.message);
  }
} else if (fs.existsSync(saPath)) {
  try {
    serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf8'));
    console.log('✅ Loaded Firebase service account from service_account.json');
  } catch (e) {
    console.warn('⚠️ Could not read local service_account.json:', e.message);
  }
}

// ─── Watched ESPN League Slugs ────────────────────────────────────────────────
// The 'all' slug catches worldwide matches; top leagues are queried for rich details
const ESPN_WATCHED_LEAGUES = [
  'all',
  'eng.1', 'eng.league_cup', 'eng.fa', 'esp.1', 'ita.1', 'ger.1', 'fra.1',
  'uefa.champions', 'uefa.europa', 'uefa.europa.conf',
  'ned.1', 'por.1', 'tur.1', 'bel.1', 'sco.1',
  'mex.1', 'usa.1', 'bra.1', 'arg.1', 'sau.1'
];

// ─── In-Memory State (Lives in RAM — ZERO Write Quotas) ────────────────────────
let soccerData = {
  matchesData: {
    lastUpdated: new Date().toISOString(),
    scrapedBy: 'render-live-node',
    hasLiveGame: false,
    matches: []
  },
  standingsData: {
    lastUpdated: new Date().toISOString(),
    standingsByLeague: []
  }
};

let previousScoresMap = new Map(); // id -> { homeScore, awayScore }
let isPolling = false;

// ─── Safe Network Fetch Helper ────────────────────────────────────────────────
async function safeFetchJson(url, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9'
      }
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// ─── Seed Initial State from Cloudflare / Local History on Startup ────────────
async function seedInitialData(retries = 3) {
  console.log('🔄 Seeding initial predictions and matches data from Cloudflare KV...');
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const data = await safeFetchJson(CLOUDFLARE_SEED_URL, 12000);
      if (data && data.matchesData && Array.isArray(data.matchesData.matches) && data.matchesData.matches.length > 0) {
        soccerData = data;
        console.log(`✅ Seeded ${soccerData.matchesData.matches.length} matches from Cloudflare KV (attempt ${attempt}).`);
        initScoresMap();
        return true;
      }
    } catch (err) {
      console.warn(`Seed attempt ${attempt} failed:`, err.message);
    }
    if (attempt < retries) {
      await new Promise(r => setTimeout(r, 2000));
    }
  }

  // Fallback to local history.json if available
  try {
    const historyPath = path.join(__dirname, '..', 'docs', 'data', 'history.json');
    if (fs.existsSync(historyPath)) {
      const history = JSON.parse(fs.readFileSync(historyPath, 'utf8'));
      if (Array.isArray(history)) {
        soccerData.matchesData.matches = history.slice(0, 50);
        console.log(`✅ Seeded ${soccerData.matchesData.matches.length} matches from local history.`);
        initScoresMap();
        return true;
      }
    }
  } catch (err) {
    console.warn('Could not seed from history.json:', err.message);
  }
  return false;
}

function initScoresMap() {
  previousScoresMap.clear();
  for (const m of (soccerData.matchesData.matches || [])) {
    if (m.id) {
      previousScoresMap.set(String(m.id), {
        homeScore: m.homeScore || 0,
        awayScore: m.awayScore || 0
      });
    }
  }
}

// ─── Live Poller Engine (Runs in RAM every 30 seconds) ─────────────────────────
async function pollLiveScores() {
  if (isPolling) return;
  isPolling = true;

  try {
    // If RAM is empty (e.g. server restarted or spun up), seed from Cloudflare KV immediately
    if (!soccerData.matchesData?.matches || soccerData.matchesData.matches.length === 0) {
      console.log('⚠️ RAM empty before poll, seeding from Cloudflare KV...');
      await seedInitialData(2);
    }

    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10).replace(/-/g, '');

    // Fetch scoreboards concurrently
    const requests = ESPN_WATCHED_LEAGUES.map(async (slug) => {
      const limitParam = slug === 'all' ? '&limit=300' : '';
      const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${slug}/scoreboard?dates=${dateStr}${limitParam}`;
      const json = await safeFetchJson(url);
      return json?.events || [];
    });

    const results = await Promise.all(requests);
    const allEvents = results.flat();

    if (allEvents.length === 0) {
      soccerData.matchesData.hasLiveGame = false;
      return;
    }

    let hasLiveGame = false;
    const liveSnapshot = new Map();

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
      const slugKey = `${homeTeam}-${awayTeam}`.replace(/\s+/g, '-').toLowerCase();
      const normKey = `${homeTeam.toLowerCase().replace(/[^a-z0-9]/g, '')}-${awayTeam.toLowerCase().replace(/[^a-z0-9]/g, '')}`;

// ─── Extract Team Telemetry Statistics Helper ──────────────────────────────
function extractTeamStats(statistics) {
  if (!Array.isArray(statistics)) return {};
  const map = {};
  for (const s of statistics) {
    if (s.name && s.displayValue !== undefined) {
      map[s.name] = s.displayValue;
    }
  }
  return {
    possession: parseFloat(map.possessionPct || '0') || 0,
    shots: parseInt(map.totalShots || '0', 10) || 0,
    shotsOnTarget: parseInt(map.shotsOnTarget || '0', 10) || 0,
    corners: parseInt(map.wonCorners || '0', 10) || 0,
    fouls: parseInt(map.foulsCommitted || '0', 10) || 0,
    yellowCards: parseInt(map.yellowCards || '0', 10) || 0,
    redCards: parseInt(map.redCards || '0', 10) || 0,
    saves: parseInt(map.saves || '0', 10) || 0,
    offsides: parseInt(map.offsides || '0', 10) || 0,
    accuratePasses: parseInt(map.accuratePasses || '0', 10) || 0,
    totalPasses: parseInt(map.totalPasses || '0', 10) || 0,
    passAccuracy: parseFloat(map.passPct || '0') ? Math.round(parseFloat(map.passPct) * (parseFloat(map.passPct) <= 1 ? 100 : 1)) : 0,
    tackles: parseInt(map.effectiveTackles || map.totalTackles || '0', 10) || 0,
    interceptions: parseInt(map.interceptions || '0', 10) || 0,
  };
}

      const homeId = String(home?.id || '');
      const details = comp.details || [];
      const events = details.map(d => {
        const isHome = String(d.team?.id || '') === homeId;
        const athlete1 = d.athletesInvolved?.[0] || {};
        const athlete2 = d.athletesInvolved?.[1] || {};
        const isSub = d.type?.text?.toLowerCase().includes('substitution') || d.type?.id === '11';
        const playerIn = athlete1.displayName || athlete1.shortName || '';
        const playerOut = athlete2.displayName || athlete2.shortName || '';
        const playerName = isSub
          ? (playerIn ? `▲ ${playerIn}${playerOut ? ' (for ▼ ' + playerOut + ')' : ''}` : 'Substitution')
          : (athlete1.displayName || athlete1.shortName || 'Unknown');
        const typeText = d.type?.text || (d.scoringPlay ? 'Goal' : (d.redCard ? 'Red Card' : (d.yellowCard ? 'Yellow Card' : 'Event')));

        return {
          type: typeText,
          clock: d.clock?.displayValue || '',
          team: isHome ? 'home' : 'away',
          player: playerName,
          playerIn: playerIn || null,
          playerOut: playerOut || null,
          scoringPlay: !!d.scoringPlay,
          redCard: !!d.redCard || typeText.toLowerCase().includes('red card'),
          yellowCard: !!d.yellowCard || typeText.toLowerCase().includes('yellow card'),
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

      const hStats = extractTeamStats(home?.statistics);
      const aStats = extractTeamStats(away?.statistics);
      const hasStats = (hStats.shots > 0 || aStats.shots > 0 || hStats.possession > 0 || hStats.corners > 0);

      const stats = hasStats ? {
        possessionHome: hStats.possession || (aStats.possession ? Math.round((100 - aStats.possession) * 10) / 10 : 50),
        possessionAway: aStats.possession || (hStats.possession ? Math.round((100 - hStats.possession) * 10) / 10 : 50),
        shotsHome: hStats.shots,
        shotsAway: aStats.shots,
        shotsOnTargetHome: hStats.shotsOnTarget,
        shotsOnTargetAway: aStats.shotsOnTarget,
        cornersHome: hStats.corners,
        cornersAway: aStats.corners,
        foulsHome: hStats.fouls,
        foulsAway: aStats.fouls,
        yellowCardsHome: hStats.yellowCards,
        yellowCardsAway: aStats.yellowCards,
        redCardsHome: hStats.redCards,
        redCardsAway: aStats.redCards,
        savesHome: hStats.saves,
        savesAway: aStats.saves,
        offsidesHome: hStats.offsides,
        offsidesAway: aStats.offsides,
        accuratePassesHome: hStats.accuratePasses,
        accuratePassesAway: aStats.accuratePasses,
        totalPassesHome: hStats.totalPasses,
        totalPassesAway: aStats.totalPasses,
        passAccuracyHome: hStats.passAccuracy,
        passAccuracyAway: aStats.passAccuracy,
        tacklesHome: hStats.tackles,
        tacklesAway: aStats.tackles,
        interceptionsHome: hStats.interceptions,
        interceptionsAway: aStats.interceptions
      } : null;

      const venueName = comp.venue?.fullName || '';
      const venueCity = comp.venue?.address?.city || '';
      const venue = venueName ? `${venueName}${venueCity ? ', ' + venueCity : ''}` : null;
      const attendance = comp.attendance || null;
      const seriesSummary = comp.series?.summary || (comp.series?.description ? `${comp.series.title || 'Aggregate'}: ${comp.series.description}` : null);
      const referee = (comp.officials && comp.officials[0]?.displayName) || null;

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
        stats: stats,
        venue: venue,
        venueName: venueName || null,
        venueCity: venueCity || null,
        attendance: attendance,
        seriesSummary: seriesSummary,
        referee: referee,
      };

      liveSnapshot.set(String(evt.id), matchData);
      liveSnapshot.set(slugKey, matchData);
      liveSnapshot.set(normKey, matchData);
    }

    // ── Detect Goals & Send FCM Push Alerts ──
    const goalAlerts = [];
    for (const [id, match] of liveSnapshot.entries()) {
      if (!/^\d+$/.test(id)) continue; // Only process numeric IDs once

      const prev = previousScoresMap.get(id);
      if (prev && match.state === 'in') {
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

      // Update scores in memory map
      previousScoresMap.set(id, {
        homeScore: match.homeScore,
        awayScore: match.awayScore
      });
    }

    if (goalAlerts.length > 0 && serviceAccount) {
      broadcastGoalAlerts(goalAlerts, serviceAccount).catch(err =>
        console.error('Push notification error:', err.message)
      );
    }

    // ── Update In-Memory Match Records for Flutter ──
    const existingMatches = soccerData.matchesData?.matches || [];
    for (const m of existingMatches) {
      const slugKey = `${m.homeTeam}-${m.awayTeam}`.replace(/\s+/g, '-').toLowerCase();
      const normKey = `${(m.homeTeam || '').toLowerCase().replace(/[^a-z0-9]/g, '')}-${(m.awayTeam || '').toLowerCase().replace(/[^a-z0-9]/g, '')}`;
      const live = (m.espnEventId && liveSnapshot.get(String(m.espnEventId))) ||
                   liveSnapshot.get(String(m.id)) ||
                   liveSnapshot.get(slugKey) ||
                   liveSnapshot.get(normKey);

      if (live) {
        m.homeScore = live.homeScore;
        m.awayScore = live.awayScore;
        m.events = live.events || [];
        m.homeScorers = live.homeScorers || [];
        m.awayScorers = live.awayScorers || [];
        if (live.stats) m.stats = live.stats;
        if (live.venue) m.venue = live.venue;
        if (live.attendance) m.attendance = live.attendance;
        if (live.seriesSummary) m.seriesSummary = live.seriesSummary;
        if (live.referee) m.referee = live.referee;

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

    soccerData.matchesData.lastUpdated = now.toISOString();
    soccerData.matchesData.hasLiveGame = hasLiveGame;

  } catch (err) {
    console.error('❌ Poller error (silently recovered):', err.message);
  } finally {
    isPolling = false;
  }
}

// ─── Firebase HTTP v1 Modern Push Sender ─────────────────────────────────────
let cachedAccessToken = null;
let tokenExpiresAt = 0;

async function getGoogleOAuth2Token(sa) {
  const nowSec = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && nowSec < tokenExpiresAt - 60) {
    return cachedAccessToken;
  }

  const iat = nowSec;
  const exp = iat + 3600;

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };

  const b64Url = (str) => Buffer.from(str).toString('base64url');
  const unsignedToken = `${b64Url(JSON.stringify(header))}.${b64Url(JSON.stringify(payload))}`;

  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsignedToken);
  signer.end();
  const signature = signer.sign(sa.private_key, 'base64url');
  const signedJwt = `${unsignedToken}.${signature}`;

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
  cachedAccessToken = json.access_token;
  tokenExpiresAt = nowSec + (json.expires_in || 3600);
  return cachedAccessToken;
}

async function broadcastGoalAlerts(alerts, sa) {
  try {
    const token = await getGoogleOAuth2Token(sa);
    if (!token) return;

    const projectId = sa.project_id || 'ai-football-predictions-a6ff9';
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    for (const alert of alerts) {
      console.log(`📢 Sending FCM Push Alert: ${alert.title}`);
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
    console.error('Failed to send goal alerts via Firebase v1:', err.message);
  }
}

// ─── HTTP Web Server (Serves Flutter App & UptimeRobot Ping) ─────────────────
const server = http.createServer(async (req, res) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, HEAD',
    'Access-Control-Allow-Headers': '*',
    'Content-Type': 'application/json'
  };

  if (req.method === 'OPTIONS') {
    res.writeHead(204, headers);
    return res.end();
  }

  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  const userAgent = (req.headers['user-agent'] || '').toLowerCase();

  // 1. Keep-Alive / Health Endpoint for cron-job.org & Uptime monitors (Keeps Render awake 24/7)
  if (
    url.pathname === '/health' ||
    url.pathname === '/ping' ||
    userAgent.includes('cron-job.org') ||
    userAgent.includes('uptimerobot') ||
    userAgent.includes('better uptime')
  ) {
    res.writeHead(200, { ...headers, 'Content-Type': 'text/plain' });
    return res.end('OK');
  }

  // 2. Manual Refresh Trigger
  if (url.pathname === '/refresh') {
    pollLiveScores();
    res.writeHead(200, headers);
    return res.end(JSON.stringify({ status: 'ok', message: 'Live refresh triggered' }));
  }

  // 3. Receive Webhook or Scraper Push (to update base predictions and standings)
  if (req.method === 'POST' && url.pathname === '/api/update') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        if (payload.matchesData) {
          soccerData = payload;
          initScoresMap();
          res.writeHead(200, headers);
          return res.end(JSON.stringify({ success: true, count: payload.matchesData?.matches?.length }));
        }
      } catch (e) {
        res.writeHead(400, headers);
        return res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // 4. Lightweight Live Scores Endpoint (/live or ?live=1)
  // Returns live matches and matches finished today with live telemetry (< 20 KB)
  if (url.pathname === '/live' || url.searchParams.get('live') === '1') {
    const todayStr = new Date().toISOString().slice(0, 10);
    const now = Date.now();
    const liveMatches = (soccerData.matchesData?.matches || []).filter(m => {
      // 1. All currently active matches
      if (m.status === 'live') return true;

      // 2. Any match finished today (FT) or within the last 24 hours
      if (m.status === 'finished' || m.statusShort === 'FT') {
        if (m.date && m.date.startsWith(todayStr)) return true;
        const matchTime = new Date(m.date).getTime();
        if (!isNaN(matchTime) && (now - matchTime) > 0 && (now - matchTime) < 24 * 60 * 60 * 1000) {
          return true;
        }
      }

      // 3. Any match scheduled today that changed state from notStarted (postponed, etc.)
      if (m.status && m.status !== 'notStarted' && m.date && m.date.startsWith(todayStr)) {
        return true;
      }

      return false;
    }).map(m => ({
      id: m.id,
      homeTeam: m.homeTeam,
      awayTeam: m.awayTeam,
      homeLogo: m.homeLogo,
      awayLogo: m.awayLogo,
      league: m.league,
      date: m.date,
      status: m.status,
      statusShort: m.statusShort,
      homeScore: m.homeScore,
      awayScore: m.awayScore,
      elapsed: m.elapsed,
      events: m.events || [],
      homeScorers: m.homeScorers || [],
      awayScorers: m.awayScorers || [],
      homeLineup: m.homeLineup || null,
      awayLineup: m.awayLineup || null,
      stats: m.stats || null,
      referee: m.referee || null,
      venue: m.venue || null,
      attendance: m.attendance || null,
      seriesSummary: m.seriesSummary || null,
    }));
    const livePayload = {
      status: 'ok',
      lastUpdated: soccerData.matchesData?.lastUpdated || new Date().toISOString(),
      hasLiveGame: liveMatches.some(m => m.status === 'live'),
      count: liveMatches.length,
      matches: liveMatches
    };
    res.writeHead(200, {
      ...headers,
      'Cache-Control': 'public, max-age=5, s-maxage=5, stale-while-revalidate=2'
    });
    return res.end(JSON.stringify(livePayload));
  }

  // 5. Default: Return full soccer dataset to Flutter (with GZIP compression support)
  const acceptEncoding = (req.headers['accept-encoding'] || '').toLowerCase();
  const jsonStr = JSON.stringify(soccerData);

  const defaultHeaders = {
    ...headers,
    'Cache-Control': 'public, max-age=60, s-maxage=60, stale-while-revalidate=30'
  };

  if (acceptEncoding.includes('gzip')) {
    zlib.gzip(jsonStr, (err, compressed) => {
      if (err) {
        res.writeHead(200, defaultHeaders);
        return res.end(jsonStr);
      }
      res.writeHead(200, {
        ...defaultHeaders,
        'Content-Encoding': 'gzip',
        'Content-Type': 'application/json'
      });
      res.end(compressed);
    });
    return;
  }

  res.writeHead(200, defaultHeaders);
  res.end(jsonStr);
});

// ─── Startup Sequence ────────────────────────────────────────────────────────
server.listen(PORT, async () => {
  console.log(`\n======================================================`);
  console.log(`🚀 24/7 Unlimited Live Score Server started on port ${PORT}`);
  console.log(`   Health Check: http://localhost:${PORT}/health`);
  console.log(`   Flutter API:  http://localhost:${PORT}/`);
  console.log(`======================================================\n`);

  // Seed data on boot
  await seedInitialData();

  // Run initial poll immediately
  await pollLiveScores();

  // Poll continuously every 30 seconds
  setInterval(pollLiveScores, POLL_INTERVAL_MS);
});
