/**
 * eval_h2h.mjs — controlled A/B backtest for the head-to-head fix.
 *
 * Replays finished matches from docs/data/history.json through the real
 * makePrediction() twice, changing only the H2H input:
 *   A = H2H off (what production has been shipping: weights 55/40/0/5)
 *   B = H2H on  (the fixed reader: weights 45/30/20/5)
 *
 * Everything else — odds, form, records, league — comes from the archive, so
 * the two variants differ by exactly one input. ESPN supplies the season
 * series; results are cached locally. Render, Cloudflare KV and Telegram are
 * never touched.
 *
 * Usage: node eval_h2h.mjs [sampleSize]     (default 300, 0 = every match)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { makePrediction, parseH2HStr, evaluatePrediction } from './scraper.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const HISTORY_FILE = path.join(__dirname, '..', 'docs', 'data', 'history.json');
const CACHE_FILE = path.join(__dirname, 'h2h_eval_cache.json');
const OUT_FILE = path.join(__dirname, 'h2h_eval.csv');

const SAMPLE_SIZE = parseInt(process.argv[2] || '300', 10);
const CONCURRENCY = 5;

// ESPN resolves summary?event=<id> by event id and ignores the league segment
// of the path, so one slug serves every archived fixture.
const SUMMARY_URL = (id) =>
  `https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event=${id}`;

function loadCache() {
  try { return JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8')); } catch { return {}; }
}

function saveCache(cache) {
  fs.writeFileSync(CACHE_FILE, JSON.stringify(cache), 'utf8');
}

async function fetchSeries(eventId, cache) {
  if (Object.prototype.hasOwnProperty.call(cache, eventId)) return cache[eventId];

  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const res = await fetch(SUMMARY_URL(eventId), {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
        signal: AbortSignal.timeout(25000),
      });
      if (res.status === 429) { await new Promise(r => setTimeout(r, 3000)); continue; }
      if (!res.ok) { cache[eventId] = null; return null; }
      const data = await res.json();
      // Keep only the series — the full summary is ~300 KB per event.
      cache[eventId] = Array.isArray(data?.seasonseries) ? data.seasonseries : null;
      return cache[eventId];
    } catch {
      if (attempt === 0) await new Promise(r => setTimeout(r, 1200));
    }
  }
  cache[eventId] = null;
  return null;
}

function seededShuffle(arr, seed = 20261110) {
  const out = arr.slice();
  let s = seed >>> 0;
  const rand = () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

const num = (v) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
};

function argmax(p) {
  const h = p.homeWinProbability, d = p.drawProbability, a = p.awayWinProbability;
  if (h > d && h > a) return 'H';
  if (a > d && a > h) return 'A';
  return 'D';
}

function scores(p, actual) {
  const probs = { H: p.homeWinProbability / 100, D: p.drawProbability / 100, A: p.awayWinProbability / 100 };
  const sum = probs.H + probs.D + probs.A || 1;
  for (const k of ['H', 'D', 'A']) probs[k] /= sum;
  let brier = 0;
  for (const k of ['H', 'D', 'A']) brier += (probs[k] - (k === actual ? 1 : 0)) ** 2;
  const clamped = Math.min(0.99, Math.max(0.01, probs[actual]));
  return { brier, logLoss: -Math.log(clamped), confidence: Math.max(probs.H, probs.D, probs.A) * 100 };
}

function tally() {
  return { n: 0, argmaxHits: 0, brier: 0, logLoss: 0, confidence: 0, recWon: 0, recLost: 0, recUnknown: 0 };
}

function add(t, p, actual, rec, home, away, hs, as) {
  const s = scores(p, actual);
  t.n++;
  if (argmax(p) === actual) t.argmaxHits++;
  t.brier += s.brier;
  t.logLoss += s.logLoss;
  t.confidence += s.confidence;
  const verdict = evaluatePrediction(rec, hs, as, home, away).result;
  if (verdict === 'WON') t.recWon++;
  else if (verdict === 'LOST') t.recLost++;
  else t.recUnknown++;
}

function report(label, t) {
  if (t.n === 0) { console.log(`  ${label}: no matches`); return; }
  const pct = (x) => ((x / t.n) * 100).toFixed(1);
  const graded = t.recWon + t.recLost;
  console.log(`  ${label}`);
  console.log(`    1X2 argmax accuracy : ${t.argmaxHits}/${t.n} (${pct(t.argmaxHits)}%)`);
  console.log(`    Brier score         : ${(t.brier / t.n).toFixed(4)}  (lower is better)`);
  console.log(`    Log loss            : ${(t.logLoss / t.n).toFixed(4)}  (lower is better)`);
  console.log(`    Avg top probability : ${(t.confidence / t.n).toFixed(1)}%`);
  console.log(`    Recommendation hit  : ${t.recWon}/${graded} (${graded ? ((t.recWon / graded) * 100).toFixed(1) : '0.0'}%)  ungraded=${t.recUnknown}`);
}

function csvCell(v) {
  const s = String(v ?? '');
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

// Two-sided exact sign test on the discordant pairs. With a paired A/B only
// the matches where the two variants disagree carry information about which
// one is better; the agreements cancel out.
function signTest(aOnly, bOnly) {
  const n = aOnly + bOnly;
  if (n === 0) return 1;
  const k = Math.min(aOnly, bOnly);
  let term = Math.pow(0.5, n); // C(n,0) * 0.5^n
  let tail = term;
  for (let i = 1; i <= k; i++) {
    term *= (n - i + 1) / i;
    tail += term;
  }
  return Math.min(1, 2 * tail);
}

async function main() {
  const history = JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8'));
  const cache = loadCache();

  const eligible = history.filter((m) => {
    const hs = num(m.homeScore), as = num(m.awayScore);
    if (hs === null || as === null) return false;
    const state = String(m.status || '').toLowerCase();
    const short = String(m.statusShort || '').toUpperCase();
    const finished = state === 'finished' || ['FT', 'AET', 'PEN'].includes(short);
    return finished && !!m.espnEventId && !!m.homeTeam && !!m.awayTeam;
  });

  console.log(`Archive: ${history.length} matches, ${eligible.length} finished with a usable score`);
  console.log(`Null h2hSummary in archive: ${history.filter(m => !m.h2hSummary).length}/${history.length}`);

  const picked = SAMPLE_SIZE > 0 ? seededShuffle(eligible).slice(0, SAMPLE_SIZE) : seededShuffle(eligible);
  console.log(`Evaluating ${picked.length} fixtures (deterministic sample, seed 20261110)\n`);

  // Fetch the series first so the model runs are pure and repeatable.
  let done = 0, fetched = 0;
  const queue = picked.slice();
  async function worker() {
    while (queue.length) {
      const m = queue.shift();
      const id = String(m.espnEventId);
      if (!Object.prototype.hasOwnProperty.call(cache, id)) fetched++;
      await fetchSeries(id, cache);
      done++;
      if (done % 25 === 0) {
        saveCache(cache);
        console.log(`  series fetched ${done}/${picked.length} (network calls this run: ${fetched})`);
      }
      await new Promise(r => setTimeout(r, 60));
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  saveCache(cache);
  console.log(`  series fetched ${done}/${picked.length} (network calls this run: ${fetched})\n`);

  const base = tally(), withH2H = tally();
  const baseOdds = tally(), h2hOdds = tally();
  let coverage = 0, noSeries = 0, unreadable = 0, roundTripMismatch = 0;
  let storedBaselineMatch = 0, storedBaselineComparable = 0;
  let recFlips = 0, argmaxFlips = 0, flipBaseHits = 0, flipH2HHits = 0;
  let recAOnly = 0, recBOnly = 0;
  const rows = [];
  const perLeague = new Map();

  for (const m of picked) {
    const hs = num(m.homeScore), as = num(m.awayScore);
    const actual = hs > as ? 'H' : (hs < as ? 'A' : 'D');
    const series = cache[String(m.espnEventId)];

    let h2hSummary = null;
    if (!series || series.length === 0) {
      noSeries++;
    } else {
      const parsed = parseH2HStr({ seasonseries: series }, m.homeTeam, m.awayTeam);
      if (!parsed) {
        unreadable++;
      } else {
        coverage++;
        h2hSummary = parsed.summaryStr;
        // Production feeds the stored sentence back into makePrediction, so
        // verify the text round-trips to the same percentages.
        const again = parseH2HStr(h2hSummary, m.homeTeam, m.awayTeam);
        if (!again || Math.abs(again.h - parsed.h) > 0.51 || Math.abs(again.d - parsed.d) > 0.51 || Math.abs(again.a - parsed.a) > 0.51) {
          roundTripMismatch++;
          console.warn(`  round-trip mismatch: ${m.homeTeam} vs ${m.awayTeam} | ${h2hSummary.slice(0, 90)}`);
        }
      }
    }

    const args = [m.homeTeam, m.awayTeam, m.homeOdds, m.drawOdds, m.awayOdds, m.league, m.homeForm, m.awayForm];
    const tail = [m.homeRecord, m.awayRecord];
    // Variant B passes the sentence, exactly as the scraper's re-prediction does.
    const pBase = makePrediction(...args, null, ...tail);
    const pH2H = makePrediction(...args, h2hSummary, ...tail);

    add(base, pBase, actual, pBase.recommendation, m.homeTeam, m.awayTeam, hs, as);
    add(withH2H, pH2H, actual, pH2H.recommendation, m.homeTeam, m.awayTeam, hs, as);

    const hasMarketOdds = m.homeOdds > 0 && m.awayOdds > 0;
    if (hasMarketOdds) {
      add(baseOdds, pBase, actual, pBase.recommendation, m.homeTeam, m.awayTeam, hs, as);
      add(h2hOdds, pH2H, actual, pH2H.recommendation, m.homeTeam, m.awayTeam, hs, as);
    }

    if (m.prediction && Number.isFinite(m.prediction.homeWinProbability)) {
      storedBaselineComparable++;
      if (m.prediction.homeWinProbability === pBase.homeWinProbability &&
          m.prediction.drawProbability === pBase.drawProbability &&
          m.prediction.awayWinProbability === pBase.awayWinProbability) storedBaselineMatch++;
    }

    const baseArg = argmax(pBase), h2hArg = argmax(pH2H);
    if (pBase.recommendation !== pH2H.recommendation) recFlips++;
    if (baseArg !== h2hArg) {
      argmaxFlips++;
      if (baseArg === actual) flipBaseHits++;
      if (h2hArg === actual) flipH2HHits++;
    }

    const recA = evaluatePrediction(pBase.recommendation, hs, as, m.homeTeam, m.awayTeam).result;
    const recB = evaluatePrediction(pH2H.recommendation, hs, as, m.homeTeam, m.awayTeam).result;
    if (recA === 'WON' && recB === 'LOST') recAOnly++;
    else if (recA === 'LOST' && recB === 'WON') recBOnly++;

    const lg = perLeague.get(m.league) || { base: tally(), h2h: tally() };
    add(lg.base, pBase, actual, pBase.recommendation, m.homeTeam, m.awayTeam, hs, as);
    add(lg.h2h, pH2H, actual, pH2H.recommendation, m.homeTeam, m.awayTeam, hs, as);
    perLeague.set(m.league, lg);

    rows.push([
      m.date, m.league, m.homeTeam, m.awayTeam, hs, as, actual,
      hasMarketOdds ? 'market' : 'proxy',
      h2hSummary ? 'yes' : 'no',
      pBase.homeWinProbability, pBase.drawProbability, pBase.awayWinProbability, baseArg,
      pH2H.homeWinProbability, pH2H.drawProbability, pH2H.awayWinProbability, h2hArg,
      pBase.recommendation, pH2H.recommendation,
      recA, recB,
      scores(pBase, actual).brier.toFixed(4), scores(pH2H, actual).brier.toFixed(4),
      h2hSummary || ''
    ]);
  }

  console.log('─'.repeat(66));
  console.log('  H2H COVERAGE');
  console.log('─'.repeat(66));
  console.log(`  usable series        : ${coverage}/${picked.length} (${((coverage / picked.length) * 100).toFixed(1)}%)`);
  console.log(`  no series on ESPN    : ${noSeries}`);
  console.log(`  series but unreadable: ${unreadable}`);
  console.log(`  text round-trip errors: ${roundTripMismatch}`);
  console.log(`  recomputed A matches the archived prediction: ${storedBaselineMatch}/${storedBaselineComparable}`);

  console.log('\n' + '─'.repeat(66));
  console.log(`  ALL ${picked.length} FIXTURES`);
  console.log('─'.repeat(66));
  report('A — H2H off (production today)', base);
  report('B — H2H on  (the fix)', withH2H);

  console.log('\n' + '─'.repeat(66));
  console.log(`  MARKET-ODDS SUBSET (${baseOdds.n} fixtures)`);
  console.log('─'.repeat(66));
  report('A — H2H off', baseOdds);
  report('B — H2H on', h2hOdds);

  console.log('\n' + '─'.repeat(66));
  console.log('  WHAT CHANGED');
  console.log('─'.repeat(66));
  console.log(`  recommendations flipped : ${recFlips}/${picked.length}`);
  console.log(`  1X2 argmax flipped      : ${argmaxFlips}/${picked.length}`);
  console.log(`    of those, A correct   : ${flipBaseHits}`);
  console.log(`    of those, B correct   : ${flipH2HHits}`);
  const deltaBrier = (withH2H.brier - base.brier) / (base.n || 1);
  console.log(`  Brier delta (B - A)     : ${deltaBrier.toFixed(5)}  ${deltaBrier < 0 ? '→ B better' : deltaBrier > 0 ? '→ A better' : '→ identical'}`);

  console.log('\n' + '─'.repeat(66));
  console.log('  PAIRED SIGNIFICANCE (only disagreements count)');
  console.log('─'.repeat(66));
  const pRec = signTest(recAOnly, recBOnly);
  const pArg = signTest(flipBaseHits, flipH2HHits);
  console.log(`  recommendation : A-only wins ${recAOnly}, B-only wins ${recBOnly}, exact p=${pRec.toFixed(3)}`);
  console.log(`  1X2 argmax     : A-only wins ${flipBaseHits}, B-only wins ${flipH2HHits}, exact p=${pArg.toFixed(3)}`);
  const verdict = (p) => p < 0.05 ? 'SIGNIFICANT' : 'not significant — within noise';
  console.log(`  recommendation verdict : ${verdict(pRec)}`);
  console.log(`  1X2 argmax verdict     : ${verdict(pArg)}`);

  console.log('\n' + '─'.repeat(66));
  console.log('  PER LEAGUE (argmax accuracy A → B, n ≥ 8)');
  console.log('─'.repeat(66));
  [...perLeague.entries()]
    .filter(([, v]) => v.base.n >= 8)
    .sort((a, b) => b[1].base.n - a[1].base.n)
    .forEach(([league, v]) => {
      const a = ((v.base.argmaxHits / v.base.n) * 100).toFixed(0);
      const b = ((v.h2h.argmaxHits / v.h2h.n) * 100).toFixed(0);
      console.log(`  ${league.padEnd(34)} n=${String(v.base.n).padStart(3)}  ${a}% → ${b}%`);
    });

  const headers = [
    'date', 'league', 'home', 'away', 'home_score', 'away_score', 'actual', 'odds_source', 'has_h2h',
    'A_home', 'A_draw', 'A_away', 'A_argmax', 'B_home', 'B_draw', 'B_away', 'B_argmax',
    'A_rec', 'B_rec', 'A_rec_result', 'B_rec_result', 'A_brier', 'B_brier', 'h2h_summary'
  ];
  fs.writeFileSync(OUT_FILE, [headers.join(','), ...rows.map(r => r.map(csvCell).join(','))].join('\n'), 'utf8');
  console.log(`\nPer-match detail: ${OUT_FILE}`);
  console.log(`Series cache:     ${CACHE_FILE}`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });