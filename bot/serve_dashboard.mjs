import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ─── Helpers ──────────────────────────────────────────────────────────────────
function isoDate(d) { return d.toISOString().slice(0, 10); }
function espnDate(d) { return isoDate(d).replace(/-/g, ''); }

function probs(r) {
  if (r <= -15) return [70, 18, 12];
  if (r <= -10) return [60, 23, 17];
  if (r < 0)    return [52, 28, 20];
  if (r >= 15)  return [12, 18, 70];
  if (r >= 10)  return [17, 23, 60];
  if (r > 0)    return [20, 28, 52];
  return [33, 34, 33];
}

function isWomensMatch(league, home, away) {
  const str = `${league} ${home} ${away}`.toLowerCase();
  return str.includes('women') || 
         str.includes('(w)') || 
         str.includes(' nwsl') || 
         str.match(/^nwsl/) ||
         str.includes('liga f') ||
         str.includes('femenina') ||
         str.includes('feminina') ||
         str.includes('frauen') ||
         str.includes('dames');
}

function isObscureMatch(league, home, away) {
  const str = `${league} ${home} ${away}`.toLowerCase();
  return str.includes('u19') || str.includes('u20') || str.includes('u21') || str.includes('u23') ||
         str.includes('u-19') || str.includes('u-21') ||
         str.includes('youth') ||
         str.includes('reserve') ||
         str.includes('club friendly') ||
         str.includes('friendlies') ||
         str.includes('tercera') ||
         str.includes('serie c') ||
         str.includes('serie d') ||
         str.includes('national league') ||
         str.includes('division 3') ||
         str.includes('division 4') ||
         str.includes('league one') ||
         str.includes('league two') ||
         str.includes('regional');
}

function makePrediction(home, away, rating = 0, hOdds = null, dOdds = null, aOdds = null, league = '') {
  const [hp, dp, ap] = probs(rating);
  const hasOdds = hOdds > 0 && aOdds > 0;
  const oddsDiff = hasOdds ? hOdds - aOdds : 0;
  const isUCL = league.toLowerCase().includes('champions league') || league.toLowerCase().includes('ucl');
  const isEvenOdds = hasOdds ? Math.abs(oddsDiff) <= 0.15 : rating === 0;
  const isHomeUnderdog = hasOdds ? hOdds >= aOdds + 1.5 : rating >= 2 || ap > hp + 10;
  const isHomeFavorite = hasOdds ? hOdds <= 1.5 : rating <= -5 || hp >= ap + 25;
  const isVolatileLeague = league.toLowerCase().includes('mls') || league.toLowerCase().includes('bundesliga');

  let rec = '', strategy = '';
  let fHp = hp, fDp = dp, fAp = ap;

  if (isUCL) {
    rec = rating < 0 ? `1X (${home} or Draw)` : `X2 (${away} or Draw)`;
    strategy = 'UCL protection';
  } else if (isEvenOdds) {
    rec = `Over 0.5 Goals`;
    strategy = 'Even odds → Over 0.5';
    fHp = 45; fDp = 10; fAp = 45;
  } else if (isHomeFavorite) {
    rec = `1X + Over 1.5 (${home} or Draw & Goals)`;
    strategy = 'Home favourite → 1X + O1.5';
    fHp = Math.max(hp, 65); fDp = 22; fAp = 13;
  } else if (isHomeUnderdog) {
    if (isVolatileLeague) {
      rec = `12 (${home} or ${away} Win)`;
      strategy = 'Underdog volatile league → 12';
      fHp = 42; fDp = 10; fAp = 48;
    } else {
      rec = `X2 (${away} or Draw)`;
      strategy = 'Away favoured → X2';
      fAp = Math.max(ap, 60); fDp = 25; fHp = 15;
    }
  } else {
    if (rating < -5 || (hasOdds && hOdds < aOdds)) {
      rec = `1X (${home} or Draw)`;
      strategy = 'Market home → 1X';
      fHp = 55; fDp = 27; fAp = 18;
    } else if (rating > 5 || (hasOdds && aOdds < hOdds)) {
      rec = `X2 (${away} or Draw)`;
      strategy = 'Market away → X2';
      fHp = 18; fDp = 27; fAp = 55;
    } else {
      rec = `Over 0.5 Goals`;
      strategy = 'Balanced → Over 0.5';
      fHp = 45; fDp = 10; fAp = 45;
    }
  }

  return { rec, strategy, hp: fHp, dp: fDp, ap: fAp };
}

function evalPrediction(rec, homeScore, awayScore, status) {
  if (status !== 'FT' && !status.includes('FT') && status !== 'post') return 'PENDING';
  if (homeScore === null || awayScore === null) return 'PENDING';
  
  const h = Number(homeScore), a = Number(awayScore);
  const homeWon = h > a, draw = h === a, awayWon = a > h;
  const r = rec.toLowerCase();

  if (r.startsWith('1x + over 1.5') || r.includes('& goals')) {
    return ((homeWon || draw) && (h + a) > 1) ? 'WIN' : 'LOSS';
  }
  if (r.startsWith('over 0.5')) return (h + a) > 0 ? 'WIN' : 'LOSS';
  if (r.startsWith('1x')) return (homeWon || draw) ? 'WIN' : 'LOSS';
  if (r.startsWith('x2')) return (awayWon || draw) ? 'WIN' : 'LOSS';
  if (r.startsWith('12')) return (homeWon || awayWon) ? 'WIN' : 'LOSS';
  return 'UNKNOWN';
}

async function fetchEndpoint(url, seenKeys) {
  const res = await fetch(url, { signal: AbortSignal.timeout(15000) }).catch(() => null);
  if (!res || !res.ok) return [];

  const data = await res.json();
  const results = [];

  for (const block of (data.scores || data.events ? [data] : [])) {
    // Scorepanel has data.scores[].events, Scoreboard has data.events
    const eventsList = block.scores ? block.scores.flatMap(s => s.events) : block.events;
    if (!eventsList) continue;

    for (const ev of eventsList) {
      const comp = ev.competitions?.[0];
      if (!comp) continue;

      const home = comp.competitors?.find(c => c.homeAway === 'home');
      const away = comp.competitors?.find(c => c.homeAway === 'away');
      if (!home || !away) continue;

      const league = ev.season?.slug === 'eng.1' ? 'English Premier League' 
                   : ev.season?.slug === 'esp.1' ? 'Spanish LALIGA'
                   : (block.leagues?.[0]?.name || ev.league?.name || 'League');

      const homeName = home.team?.displayName || home.team?.name || '';
      const awayName = away.team?.displayName || away.team?.name || '';

      if (isWomensMatch(league, homeName, awayName) || isObscureMatch(league, homeName, awayName)) continue;

      const statusType = ev.status?.type || comp.status?.type || {};
      const state = statusType.state || '';        
      const detail = statusType.shortDetail || statusType.detail || 'FT';
      
      const homeScore = (home.score !== undefined && home.score !== null && home.score !== '') ? parseInt(home.score, 10) : null;
      const awayScore = (away.score !== undefined && away.score !== null && away.score !== '') ? parseInt(away.score, 10) : null;
      const evDate = new Date(ev.date);
      const dateStr = isNaN(evDate) ? '' : evDate.toISOString().slice(0, 10);
      const kickoff = isNaN(evDate) ? '' : evDate.toISOString().slice(11, 16);

      const key = `${dateStr}|${homeName}|${awayName}`;
      if (seenKeys.has(key)) continue;
      seenKeys.add(key);

      // EXTRACT ESPN ODDS
      const oddsObj = comp.odds?.[0];
      let hOdds = null, dOdds = null, aOdds = null;
      let rating = 0;
      let p_h = 45, p_d = 10, p_a = 45;

      if (oddsObj) {
        const amToDec = (am) => {
          if (!am) return null;
          if (am > 0) return (am / 100) + 1;
          if (am < 0) return (100 / Math.abs(am)) + 1;
          return null;
        };
        hOdds = amToDec(oddsObj.homeTeamOdds?.moneyLine);
        dOdds = amToDec(oddsObj.drawOdds?.moneyLine);
        aOdds = amToDec(oddsObj.awayTeamOdds?.moneyLine);
        
        if (hOdds && aOdds) {
          const rawPh = (1 / hOdds) * 100;
          const rawPd = dOdds ? (1 / dOdds) * 100 : 0;
          const rawPa = (1 / aOdds) * 100;
          
          // SYNTHETIC RATING ALGORITHM
          // Difference in win probability mapped to -25 (Home Fav) to +25 (Away Fav) scale
          const diff = rawPh - rawPa;
          rating = Math.round(-(diff / 3.0)); 
          rating = Math.max(-25, Math.min(25, rating));
          
          // Normalize probabilities for the UI display
          if (dOdds) {
            const total = rawPh + rawPd + rawPa;
            p_h = Math.round((rawPh / total) * 100);
            p_d = Math.round((rawPd / total) * 100);
            p_a = Math.round((rawPa / total) * 100);
          } else {
            p_h = Math.round(rawPh);
            p_a = Math.round(rawPa);
          }
        }
      }

      const pred = makePrediction(homeName, awayName, rating, hOdds, dOdds, aOdds, league);
      const isFinished = statusType.completed === true || state === 'post';
      const evalStatus = isFinished ? 'FT' : 'PENDING';
      
      const correct = evalPrediction(pred.rec, homeScore, awayScore, evalStatus);
      const probs = { h: p_h, d: p_d, a: p_a };

      results.push({
        date: dateStr,
        kickoff,
        league,
        homeName,
        awayName,
        homeScore,
        awayScore,
        status: isFinished ? 'FT' : detail,
        pred,
        probs,
        correct
      });
    }
  }
  return results;
}

async function fetchUpcomingWeek() {
  const allResults = [];
  const seenKeys = new Set();
  
  const fetchPromises = [];
  
  // Loop from Yesterday (-1) to next 6 days (total 8 days)
  for (let i = -1; i < 7; i++) {
    const d = new Date();
    d.setDate(d.getDate() + i);
    const espnStr = espnDate(d);
    
    const urls = [
      `https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard?dates=${espnStr}`,
      `https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=${espnStr}`,
      `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${espnStr}&limit=500`
    ];

    for (const url of urls) {
      fetchPromises.push(fetchEndpoint(url, seenKeys));
    }
  }

  // Execute all 24 API requests concurrently for lightning speed
  const resultsArrays = await Promise.all(fetchPromises);
  for (const matches of resultsArrays) {
    allResults.push(...matches);
  }

  // Sort by date then kickoff
  allResults.sort((a, b) => (a.date + a.kickoff).localeCompare(b.date + b.kickoff));
  return allResults;
}

async function fetchTodayMatches() {
  const dateObj = new Date();
  const espnStr = espnDate(dateObj);
  const seenKeys = new Set();
  
  // Explicitly fetch Major Leagues + Default Global
  const urls = [
    `https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard?dates=${espnStr}`, // EPL
    `https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=${espnStr}`, // La Liga
    `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${espnStr}&limit=500` // Rest of the world
  ];

  const allResults = [];
  for (const url of urls) {
    const matches = await fetchEndpoint(url, seenKeys);
    allResults.push(...matches);
  }

  // Sort by kickoff
  allResults.sort((a, b) => a.kickoff.localeCompare(b.kickoff));
  return allResults;
}

// ─── CSV Parser ───────────────────────────────────────────────────────────────
async function parseMonthCSV() {
  const filePath = path.join(__dirname, 'matches_month_predictions.csv');
  if (!fs.existsSync(filePath)) return [];
  
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n').filter(l => l.trim() !== '');
  const matches = [];
  
  for (let i = 1; i < lines.length; i++) {
    // Basic CSV parser handling quotes
    const row = [];
    let cur = '';
    let inQuotes = false;
    for (const char of lines[i]) {
      if (char === '"') inQuotes = !inQuotes;
      else if (char === ',' && !inQuotes) { row.push(cur); cur = ''; }
      else cur += char;
    }
    row.push(cur);
    
    if (row.length < 14) continue;
    
    let rec = row[8].replace(/^"|"$/g, '').trim();
    let strategy = row[9].replace(/^"|"$/g, '').trim();
    let correct = row[13].replace(/^"|"$/g, '').trim();
    
    const hScore = parseInt(row[5], 10);
    const aScore = parseInt(row[6], 10);
    
    const hProb = parseInt(row[10], 10);
    const aProb = parseInt(row[12], 10);
    
    const league = row[2].replace(/^"|"$/g, '').trim();
    const homeName = row[3].replace(/^"|"$/g, '').trim();
    const awayName = row[4].replace(/^"|"$/g, '').trim();
    
    // Filter out women's matches and obscure youth/friendlies
    if (isWomensMatch(league, homeName, awayName) || isObscureMatch(league, homeName, awayName)) continue;
    
    // Inject new Tight Match rule dynamically for backtesting
    if (Math.abs(hProb - aProb) <= 10) {
      rec = 'Over 0.5 Goals';
      strategy = 'Tight Probs → Over 0.5';
      correct = (hScore + aScore > 0) ? 'WIN' : 'LOSS';
    } else if (strategy === 'Balanced → 12' || strategy === 'Even odds → 12') {
      rec = 'Over 0.5 Goals';
      strategy = strategy.replace('12', 'Over 0.5');
      correct = (hScore + aScore > 0) ? 'WIN' : 'LOSS';
    }
    
    matches.push({
      date: row[0],
      kickoff: row[1],
      league: league,
      homeName: homeName,
      awayName: awayName,
      homeScore: isNaN(hScore) ? null : hScore,
      awayScore: isNaN(aScore) ? null : aScore,
      probs: { h: row[10], d: row[11], a: row[12] },
      pred: {
        rec: rec,
        strategy: strategy
      },
      correct: correct,
      status: 'FT' // CSV only has finished matches
    });
  }
  return matches;
}

// ─── Server ──────────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  if (req.url === '/') {
    const htmlPath = path.join(__dirname, 'dashboard.html');
    fs.readFile(htmlPath, 'utf8', (err, data) => {
      if (err) {
        res.writeHead(500);
        res.end('Error loading dashboard.html');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(data);
    });
  } else if (req.url === '/api/today') {
    try {
      const matches = await fetchTodayMatches();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(matches));
    } catch (e) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    }
  } else if (req.url === '/api/upcoming') {
    try {
      const matches = await fetchUpcomingWeek();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(matches));
    } catch (e) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    }
  } else if (req.url === '/api/month') {
    try {
      const matches = await parseMonthCSV();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(matches));
    } catch (e) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    }
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

const PORT = 3000;
server.listen(PORT, () => {
  console.log(`\n🚀 Dashboard running!`);
  console.log(`   Open your browser and visit: http://localhost:${PORT}\n`);
});
