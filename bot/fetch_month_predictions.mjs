/**
 * fetch_month_predictions.mjs
 *
 * Downloads 30 days of completed football matches from ESPN (no API key needed),
 * applies the same prediction strategy used in the app, and writes two CSVs:
 *
 *   matches_month_raw.csv         – raw match data + blank mapping columns
 *   matches_month_predictions.csv – predictions vs actual result (backtest)
 *
 * Usage:
 *   node fetch_month_predictions.mjs
 *   DAYS_BACK=30 node fetch_month_predictions.mjs
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname  = path.dirname(fileURLToPath(import.meta.url));
const DAYS_BACK  = parseInt(process.env.DAYS_BACK || '30', 10);
const RAW_FILE   = path.join(__dirname, 'matches_month_raw.csv');
const PRED_FILE  = path.join(__dirname, 'matches_month_predictions.csv');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function isoDate(d) { return d.toISOString().slice(0, 10); }
function espnDate(d) { return isoDate(d).replace(/-/g, ''); } // YYYYMMDD

function daysAgo(n) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  return d;
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function safeFetch(url, retries = 2) {
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
      if (res.ok) return res;
      if (res.status === 429) { await sleep(3000); continue; }
      console.warn(`  HTTP ${res.status}: ${url}`);
    } catch (e) {
      if (i < retries) await sleep(1500 * (i + 1));
      else console.warn(`  Fetch error: ${e.message}`);
    }
  }
  return null;
}

function csvCell(v) {
  if (v === null || v === undefined) return '';
  const s = String(v);
  return (s.includes(',') || s.includes('"') || s.includes('\n'))
    ? `"${s.replace(/"/g, '""')}"` : s;
}
const row = (...cols) => cols.map(csvCell).join(',');

// ─── ESPN Fetcher ─────────────────────────────────────────────────────────────

async function fetchEspnDay(dateYmd) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${dateYmd}&limit=500`;
  const res = await safeFetch(url);
  if (!res) return [];

  const data = await res.json();
  const results = [];

  for (const block of (data.scores || [])) {
    const league = block.leagues?.[0]?.name || 'International League';
    const leagueSlug = block.leagues?.[0]?.slug || '';
    const leagueId = block.leagues?.[0]?.id || '';

    for (const ev of (block.events || [])) {
      const comp = ev.competitions?.[0];
      if (!comp) continue;

      const home = comp.competitors?.find(c => c.homeAway === 'home');
      const away = comp.competitors?.find(c => c.homeAway === 'away');
      if (!home || !away) continue;

      const statusType = ev.status?.type || comp.status?.type || {};
      const state = statusType.state || '';        // 'pre' | 'in' | 'post'
      const completed = statusType.completed === true || state === 'post';

      // Only include finished matches for backtest
      if (!completed) continue;

      const detail = statusType.shortDetail || statusType.detail || 'FT';
      const evDate = ev.date ? new Date(ev.date) : null;

      const homeScore = (home.score !== undefined && home.score !== null && home.score !== '')
        ? parseInt(home.score, 10) : null;
      const awayScore = (away.score !== undefined && away.score !== null && away.score !== '')
        ? parseInt(away.score, 10) : null;

      const homeName = home.team?.displayName || home.team?.name || '';
      const awayName = away.team?.displayName || away.team?.name || '';

      let result = 'D';
      if (homeScore !== null && awayScore !== null) {
        if (homeScore > awayScore) result = 'H';
        else if (awayScore > homeScore) result = 'A';
      }

      results.push({
        date: evDate ? isoDate(evDate) : '',
        kickoff: evDate ? evDate.toISOString().slice(11, 16) : '',
        espnEventId: ev.id || '',
        league,
        leagueSlug,
        leagueId,
        homeName,
        awayName,
        homeId: home.team?.id || '',
        awayId: away.team?.id || '',
        homeScore,
        awayScore,
        result,
        status: detail,
      });
    }
  }

  return results;
}

// ─── Prediction engine (mirrored from scraper.mjs) ───────────────────────────

function probs(r) {
  if (r <= -15) return [70, 18, 12];
  if (r <= -10) return [60, 23, 17];
  if (r < 0)    return [52, 28, 20];
  if (r >= 15)  return [12, 18, 70];
  if (r >= 10)  return [17, 23, 60];
  if (r > 0)    return [20, 28, 52];
  return [33, 34, 33];
}

/**
 * Runs the same strategy rules as makePrediction() in scraper.mjs.
 * Without odds/rating, everything falls into the "Balanced → 12" bucket —
 * which is intentional: this establishes a baseline you can improve by
 * adding odds data later.
 */
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
      rec = `Over 0.5 Goals`;
      strategy = 'Underdog volatile league → 12'; // Keep strategy name for consistency or rename? Wait, I will rename it in serve_dashboard if I rename here. The user didn't specify volatile league so I'll leave the strategy string as is for now, just change rec to Over 0.5 Goals. Wait, serve_dashboard left it as 'Underdog volatile league → 12'.
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

function evalPrediction(rec, homeScore, awayScore) {
  if (homeScore === null || awayScore === null) return 'N/A';
  const h = Number(homeScore), a = Number(awayScore);
  const homeWon = h > a, draw = h === a, awayWon = a > h;
  const r = rec.toLowerCase();

  if (r.startsWith('1x + over 1.5') || r.includes('& goals')) {
    return ((homeWon || draw) && (h + a) > 1) ? 'WIN' : 'LOSS';
  }
  if (r.startsWith('1x')) return (homeWon || draw) ? 'WIN' : 'LOSS';
  if (r.startsWith('x2')) return (awayWon || draw) ? 'WIN' : 'LOSS';
  if (r.startsWith('12')) return (homeWon || awayWon) ? 'WIN' : 'LOSS';
  return 'UNKNOWN';
}

// ─── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n=== Football Month Prediction Backtest (ESPN) ===`);
  console.log(`Fetching ${DAYS_BACK} days of completed matches...\n`);

  const allMatches = [];
  const seenKeys = new Set();

  // Oldest first → chronological CSV
  for (let d = DAYS_BACK; d >= 0; d--) {
    const dateObj = daysAgo(d);
    const dateStr  = isoDate(dateObj);
    const espnStr  = espnDate(dateObj);

    process.stdout.write(`  ${dateStr} ... `);

    const events = await fetchEspnDay(espnStr);

    // Deduplicate across days (ESPN sometimes returns same event on adjacent date queries)
    let added = 0;
    for (const ev of events) {
      const key = `${ev.date}|${ev.homeName.toLowerCase()}|${ev.awayName.toLowerCase()}`;
      if (seenKeys.has(key)) continue;
      seenKeys.add(key);

      const pred    = makePrediction(ev.homeName, ev.awayName, 0, null, null, null, ev.league);
      const correct = evalPrediction(pred.rec, ev.homeScore, ev.awayScore);

      allMatches.push({ ...ev, pred, correct });
      added++;
    }

    console.log(`${added} finished`);
    await sleep(300); // be polite to ESPN
  }

  console.log(`\nTotal unique finished matches: ${allMatches.length}`);

  // ── RAW CSV ───────────────────────────────────────────────────────────────
  const RAW_HEADERS = [
    'date', 'kickoff_utc', 'espn_event_id', 'league', 'league_slug', 'league_id',
    'home_name_raw', 'away_name_raw', 'home_id', 'away_id',
    'home_name_mapped', 'away_name_mapped',  // ← fill manually
    'home_score', 'away_score', 'result', 'status',
  ];
  const rawLines = [RAW_HEADERS.join(',')];
  for (const m of allMatches) {
    rawLines.push(row(
      m.date, m.kickoff, m.espnEventId, m.league, m.leagueSlug, m.leagueId,
      m.homeName, m.awayName, m.homeId, m.awayId,
      '', '',  // home_name_mapped, away_name_mapped
      m.homeScore, m.awayScore, m.result, m.status,
    ));
  }
  fs.writeFileSync(RAW_FILE, rawLines.join('\n'), 'utf8');
  console.log(`\n✅ Raw data saved:       ${RAW_FILE}`);

  // ── PREDICTIONS CSV ───────────────────────────────────────────────────────
  const PRED_HEADERS = [
    'date', 'kickoff_utc', 'league',
    'home_team', 'away_team',
    'home_score', 'away_score', 'result',
    'prediction', 'strategy',
    'prob_home%', 'prob_draw%', 'prob_away%',
    'correct',
  ];
  const predLines = [PRED_HEADERS.join(',')];
  for (const m of allMatches) {
    predLines.push(row(
      m.date, m.kickoff, m.league,
      m.homeName, m.awayName,
      m.homeScore, m.awayScore, m.result,
      m.pred.rec, m.pred.strategy,
      m.pred.hp, m.pred.dp, m.pred.ap,
      m.correct,
    ));
  }
  fs.writeFileSync(PRED_FILE, predLines.join('\n'), 'utf8');
  console.log(`✅ Predictions saved:    ${PRED_FILE}`);

  // ── Accuracy summary ─────────────────────────────────────────────────────
  const scored = allMatches.filter(m => m.correct !== 'N/A' && m.correct !== 'UNKNOWN');
  const wins   = scored.filter(m => m.correct === 'WIN').length;

  if (scored.length === 0) {
    console.log('\n  No scoreable matches found.');
    return;
  }

  const pct = ((wins / scored.length) * 100).toFixed(1);
  console.log(`\n📊 Overall accuracy: ${wins}/${scored.length} = ${pct}%`);

  // Per-strategy breakdown
  const byStrategy = {};
  for (const m of scored) {
    const s = m.pred.strategy;
    if (!byStrategy[s]) byStrategy[s] = { wins: 0, total: 0 };
    byStrategy[s].total++;
    if (m.correct === 'WIN') byStrategy[s].wins++;
  }
  console.log('\n  Strategy breakdown:');
  for (const [s, v] of Object.entries(byStrategy).sort((a, b) => b[1].total - a[1].total)) {
    const p = ((v.wins / v.total) * 100).toFixed(0);
    console.log(`    ${p.padStart(3)}% (${String(v.wins).padStart(4)}/${String(v.total).padStart(4)})  ${s}`);
  }

  // Per-result-type distribution
  const dist = { H: 0, D: 0, A: 0 };
  for (const m of allMatches) dist[m.result] = (dist[m.result] || 0) + 1;
  const total = allMatches.length;
  console.log(`\n  Result distribution over ${total} matches:`);
  console.log(`    Home wins: ${dist.H} (${((dist.H/total)*100).toFixed(1)}%)`);
  console.log(`    Draws:     ${dist.D} (${((dist.D/total)*100).toFixed(1)}%)`);
  console.log(`    Away wins: ${dist.A} (${((dist.A/total)*100).toFixed(1)}%)`);
}

main().catch(e => { console.error(e); process.exit(1); });
