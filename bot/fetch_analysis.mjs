/**
 * fetch_analysis.mjs
 *
 * Fetches finished matches for today + yesterday from ESPN.
 * Exports to matches_analysis.csv with computed columns:
 *   result (H/D/A), total_goals, over_0_5, over_1_5, over_2_5, over_3_5, btts
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_FILE = path.join(__dirname, 'matches_analysis.csv');

function isoDateStr(d) {
  return d.toISOString().slice(0, 10);
}

function espnDateStr(d) {
  return isoDateStr(d).replace(/-/g, '');
}

async function safeFetch(url, retries = 2, headers = {}) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, { headers, signal: AbortSignal.timeout(15000) });
      if (res.ok) return res;
      console.warn(`  HTTP ${res.status} for ${url}`);
    } catch (e) {
      if (attempt < retries) {
        await new Promise(r => setTimeout(r, 1500 * (attempt + 1)));
      } else {
        console.warn(`  Fetch failed: ${url} — ${e.message}`);
      }
    }
  }
  return null;
}

// ─── ESPN fetcher ─────────────────────────────────────────────────────────────

async function fetchEspnDay(dateEspn) {
  try {
    const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${dateEspn}`;
    const res = await safeFetch(url, 2);
    if (!res) return [];
    const data = await res.json();
    const results = [];
    for (const block of (data.scores || [])) {
      const league = block.leagues?.[0]?.name || 'International League';
      for (const ev of (block.events || [])) {
        const comp = ev.competitions?.[0];
        if (!comp) continue;
        const home = comp.competitors?.find(c => c.homeAway === 'home');
        const away = comp.competitors?.find(c => c.homeAway === 'away');
        if (!home || !away) continue;
        const type = ev.status?.type || comp.status?.type || {};
        const completed = type.completed || type.state === 'post';
        const evDate = ev.date ? new Date(ev.date) : null;
        results.push({
          date: evDate ? isoDateStr(evDate) : '',
          kickoff: evDate ? evDate.toISOString().slice(11, 16) : '',
          league,
          homeName: home.team?.displayName || home.team?.name || '',
          awayName: away.team?.displayName || away.team?.name || '',
          homeScore: (home.score !== undefined && home.score !== '') ? home.score : '',
          awayScore: (away.score !== undefined && away.score !== '') ? away.score : '',
          status: completed ? 'FT' : (type.state || 'pre'),
          source: 'espn',
        });
      }
    }
    return results;
  } catch (e) {
    console.warn(`  ESPN error: ${e.message}`);
    return [];
  }
}

// ─── CSV helpers ─────────────────────────────────────────────────────────────

function csvCell(val) {
  if (val === null || val === undefined) return '';
  const s = String(val);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function rowToCsv(fields) {
  return fields.map(csvCell).join(',');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  const dates = [yesterday, today];

  console.log(`Fetching finished matches for ${isoDateStr(yesterday)} and ${isoDateStr(today)}...\n`);

  const allRows = [];

  for (const d of dates) {
    const iso = isoDateStr(d);
    const espn = espnDateStr(d);
    process.stdout.write(`  ${iso} ... `);

    const rows = await fetchEspnDay(espn);
    console.log(`${rows.length} total, ${rows.filter(r => r.status === 'FT').length} finished`);
    allRows.push(...rows);
  }

  // Keep only finished matches with valid scores
  const finished = allRows.filter(r => {
    if (r.status !== 'FT') return false;
    const hs = parseInt(r.homeScore, 10);
    const as = parseInt(r.awayScore, 10);
    return !isNaN(hs) && !isNaN(as);
  });

  // Dedup
  const seen = new Set();
  const deduped = finished.filter(r => {
    const key = `${r.date}|${r.homeName.toLowerCase()}|${r.awayName.toLowerCase()}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  deduped.sort((a, b) => `${a.date}${a.kickoff}`.localeCompare(`${b.date}${b.kickoff}`));

  console.log(`\nFinished unique matches: ${deduped.length}`);

  // ─── Compute analysis columns ───────────────────────────────────────────────
  const HEADERS = [
    'date', 'kickoff_utc', 'league',
    'home_team', 'away_team',
    'home_score', 'away_score', 'total_goals',
    'result', 'over_0_5', 'over_1_5', 'over_2_5', 'over_3_5', 'btts',
  ];

  const lines = [HEADERS.join(',')];
  let totalMatches = 0;
  let homeWins = 0, draws = 0, awayWins = 0;
  let over05 = 0, over15 = 0, over25 = 0, over35 = 0, bttsCount = 0;
  let totalGoalsSum = 0;

  for (const r of deduped) {
    const hs = parseInt(r.homeScore, 10);
    const as = parseInt(r.awayScore, 10);
    const total = hs + as;
    const result = hs > as ? 'H' : (hs < as ? 'A' : 'D');
    const isOver05 = total > 0 ? 'Y' : 'N';
    const isOver15 = total >= 2 ? 'Y' : 'N';
    const isOver25 = total >= 3 ? 'Y' : 'N';
    const isOver35 = total >= 4 ? 'Y' : 'N';
    const isBtts = (hs > 0 && as > 0) ? 'Y' : 'N';

    totalMatches++;
    if (result === 'H') homeWins++;
    else if (result === 'D') draws++;
    else awayWins++;
    if (total > 0) over05++;
    if (total >= 2) over15++;
    if (total >= 3) over25++;
    if (total >= 4) over35++;
    if (hs > 0 && as > 0) bttsCount++;
    totalGoalsSum += total;

    lines.push(rowToCsv([
      r.date, r.kickoff, r.league,
      r.homeName, r.awayName,
      hs, as, total,
      result, isOver05, isOver15, isOver25, isOver35, isBtts,
    ]));
  }

  fs.writeFileSync(OUT_FILE, lines.join('\n'), 'utf8');

  // ─── Print summary ──────────────────────────────────────────────────────────
  const pct = (n) => totalMatches > 0 ? ((n / totalMatches) * 100).toFixed(1) : '0.0';
  const avgGoals = totalMatches > 0 ? (totalGoalsSum / totalMatches).toFixed(2) : '0.00';

  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  ANALYSIS SUMMARY — ${isoDateStr(yesterday)} & ${isoDateStr(today)}`);
  console.log(`${'═'.repeat(60)}`);
  console.log(`  Total finished matches: ${totalMatches}`);
  console.log(`  Average goals per match: ${avgGoals}`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  RESULTS:`);
  console.log(`    Home Wins (H):  ${homeWins}  (${pct(homeWins)}%)`);
  console.log(`    Draws (D):      ${draws}  (${pct(draws)}%)`);
  console.log(`    Away Wins (A):  ${awayWins}  (${pct(awayWins)}%)`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  GOALS MARKETS:`);
  console.log(`    Over 0.5:  ${over05} / ${totalMatches}  (${pct(over05)}%)`);
  console.log(`    Over 1.5:  ${over15} / ${totalMatches}  (${pct(over15)}%)`);
  console.log(`    Over 2.5:  ${over25} / ${totalMatches}  (${pct(over25)}%)`);
  console.log(`    Over 3.5:  ${over35} / ${totalMatches}  (${pct(over35)}%)`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  BTTS (Both Teams To Score): ${bttsCount} / ${totalMatches}  (${pct(bttsCount)}%)`);
  console.log(`${'═'.repeat(60)}`);
  console.log(`\n✅ CSV saved to: ${OUT_FILE}`);
}

main().catch(e => { console.error(e); process.exit(1); });
