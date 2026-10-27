import http from 'http';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
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
  'eng.1', 'esp.1', 'ita.1', 'ger.1', 'fra.1',
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
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
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
async function seedInitialData() {
  console.log('🔄 Seeding initial predictions and matches data...');
  try {
    const data = await safeFetchJson(CLOUDFLARE_SEED_URL, 10000);
    if (data && data.matchesData && Array.isArray(data.matchesData.matches)) {
      soccerData = data;
      console.log(`✅ Seeded ${soccerData.matchesData.matches.length} matches from Cloudflare KV.`);
      initScoresMap();
      return;
    }
  } catch (err) {
    console.warn('Could not seed from Cloudflare:', err.message);
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
      }
    }
  } catch (err) {
    console.warn('Could not seed from history.json:', err.message);
  }
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

      const homeId = String(home?.id || '');
      const details = comp.details || [];
      const events = details.map(d => {
        const athlete = d.athletesInvolved?.[0] || {};
        const isHome = String(d.team?.id || '') === homeId;
        const player = athlete.displayName || athlete.shortName || 'Unknown';
        const typeText = d.type?.text || (d.scoringPlay ? 'Goal' : (d.redCard ? 'Red Card' : 'Event'));
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

  // 1. Keep-Alive / Health Endpoint for UptimeRobot (Keeps Render awake 24/7)
  if (url.pathname === '/health' || url.pathname === '/ping') {
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

  // 4. Default: Return full soccer dataset to Flutter
  res.writeHead(200, headers);
  res.end(JSON.stringify(soccerData));
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
