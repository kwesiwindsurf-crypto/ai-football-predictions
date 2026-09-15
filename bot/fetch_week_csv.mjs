/**
 * fetch_week_csv.mjs
 *
 * Downloads match data for the past 3 days + next 4 days (7-day window)
 * from API-Sports and ESPN, then writes them to matches_week.csv.
 *
 * Usage:
 *   node fetch_week_csv.mjs
 *   SPORTS_API_KEY=your_key node fetch_week_csv.mjs
 *
 * Output: matches_week.csv  (in the same directory)
 *
 * CSV columns:
 *   date, kickoff_utc, league, home_name_raw, away_name_raw,
 *   home_name_mapped, away_name_mapped, home_score, away_score,
 *   status, source
 *
 * Fill in home_name_mapped / away_name_mapped manually to create
 * the canonical team-name mapping.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT_FILE = path.join(__dirname, 'matches_week.csv');

const SPORTS_API_KEY = process.env.SPORTS_API_KEY || '3d923c01afee89b7b9ae92761979ef56';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function isoDateStr(d) {
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}

function espnDateStr(d) {
  return isoDateStr(d).replace(/-/g, ''); // YYYYMMDD
}

function dateRange(daysBack = 3, daysAhead = 4) {
  const dates = [];
  const now = new Date();
  for (let i = -daysBack; i <= daysAhead; i++) {
    const d = new Date(now);
    d.setUTCDate(d.getUTCDate() + i);
    dates.push(d);
  }
  return dates;
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

// ─── API-Sports fetcher ───────────────────────────────────────────────────────

async function fetchApiSportsDay(dateIso) {
  if (!SPORTS_API_KEY) return [];
  try {
    const url = `https://v3.football.api-sports.io/fixtures?date=${dateIso}`;
    const res = await safeFetch(url, 2, { 'x-apisports-key': SPORTS_API_KEY });
    if (!res) return [];
    const data = await res.json();
    const fixtures = data.response || [];
    return fixtures.map(f => {
      const sShort = f.fixture?.status?.short || '';
      const isFinished = ['FT', 'AET', 'PEN'].includes(sShort);
      const isLive = ['1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE'].includes(sShort);
      const kickoff = f.fixture?.date ? new Date(f.fixture.date).toISOString().slice(11, 16) : '';
      return {
        date: dateIso,
        kickoff,
        league: `${f.league?.country ? f.league.country + ' - ' : ''}${f.league?.name || 'Soccer'}`,
        homeName: f.teams?.home?.name || '',
        awayName: f.teams?.away?.name || '',
        homeScore: f.goals?.home ?? '',
        awayScore: f.goals?.away ?? '',
        status: isFinished ? 'FT' : (isLive ? 'LIVE' : (sShort || 'pre')),
        source: 'api-sports',
      };
    });
  } catch (e) {
    console.warn(`  API-Sports error for ${dateIso}: ${e.message}`);
    return [];
  }
}

// ─── ESPN fetcher ─────────────────────────────────────────────────────────────

async function fetchEspnDay(dateEspn) {
  try {
    const url = dateEspn
      ? `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${dateEspn}`
      : `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel`;
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
        const state = type.state || '';
        const completed = type.completed || state === 'post';
        const sShort = type.shortDetail || type.detail || '';
        const evDate = ev.date ? new Date(ev.date) : null;
        results.push({
          date: evDate ? isoDateStr(evDate) : (dateEspn ? `${dateEspn.slice(0,4)}-${dateEspn.slice(4,6)}-${dateEspn.slice(6,8)}` : ''),
          kickoff: evDate ? evDate.toISOString().slice(11, 16) : '',
          league,
          homeName: home.team?.displayName || home.team?.name || '',
          awayName: away.team?.displayName || away.team?.name || '',
          homeScore: (home.score !== undefined && home.score !== null && home.score !== '') ? home.score : '',
          awayScore: (away.score !== undefined && away.score !== null && away.score !== '') ? away.score : '',
          status: completed ? (sShort || 'FT') : (state === 'in' ? (sShort || 'LIVE') : (sShort || 'pre')),
          source: 'espn',
        });
      }
    }
    return results;
  } catch (e) {
    console.warn(`  ESPN error for ${dateEspn}: ${e.message}`);
    return [];
  }
}

// ─── Dedup ────────────────────────────────────────────────────────────────────

function dedupMatches(rows) {
  const seen = new Set();
  return rows.filter(r => {
    const key = `${r.date}|${r.homeName.toLowerCase()}|${r.awayName.toLowerCase()}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const dates = dateRange(3, 4); // 3 days back, 4 days ahead = 8 days total
  console.log(`Fetching matches for ${dates.length} days (${isoDateStr(dates[0])} → ${isoDateStr(dates[dates.length - 1])})...`);

  const allRows = [];

  for (const d of dates) {
    const iso = isoDateStr(d);
    const espn = espnDateStr(d);
    process.stdout.write(`  ${iso} ... `);

    // Try API-Sports first (more complete)
    let rows = await fetchApiSportsDay(iso);
    if (rows.length === 0) {
      // Fallback to ESPN
      rows = await fetchEspnDay(espn);
      if (rows.length > 0) process.stdout.write(`(ESPN fallback) `);
    }

    console.log(`${rows.length} matches`);
    allRows.push(...rows);
  }

  const deduped = dedupMatches(allRows);
  // Sort by date then kickoff
  deduped.sort((a, b) => `${a.date}${a.kickoff}`.localeCompare(`${b.date}${b.kickoff}`));

  console.log(`\nTotal unique matches: ${deduped.length}`);

  const HEADERS = [
    'date', 'kickoff_utc', 'league',
    'home_name_raw', 'away_name_raw',
    'home_name_mapped', 'away_name_mapped',
    'home_score', 'away_score', 'status', 'source'
  ];

  const lines = [HEADERS.join(',')];
  for (const r of deduped) {
    lines.push(rowToCsv([
      r.date, r.kickoff, r.league,
      r.homeName, r.awayName,
      '', '',  // home_name_mapped, away_name_mapped — blank for manual entry
      r.homeScore, r.awayScore, r.status, r.source,
    ]));
  }

  fs.writeFileSync(OUT_FILE, lines.join('\n'), 'utf8');
  console.log(`\n✅ Saved to: ${OUT_FILE}`);
  console.log(`   Fill in 'home_name_mapped' and 'away_name_mapped' columns to build your name mapping.`);
}

main().catch(e => { console.error(e); process.exit(1); });
