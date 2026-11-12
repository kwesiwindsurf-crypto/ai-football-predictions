import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');

const { preservePredictionLock } = await import('../scraper.mjs');

const EVENT_ID = '401880777';

const preMatch = (league) => ({
  id: 'Barnsley-Oldham-Athletic-2026-11-11',
  espnEventId: EVENT_ID,
  league,
  status: 'notStarted',
  statusShort: 'NS',
  homeOdds: 1.69,
  drawOdds: 4.4,
  awayOdds: 3.65,
  oddsRating: 12,
  prediction: {
    homeWinProbability: 62,
    drawProbability: 21,
    awayWinProbability: 17,
    recommendation: 'Barnsley to Win (1)',
    analysis: 'Domestic Cup: Overwhelming Home Giant (Prob >= 70%).\nOddsSource: market'
  }
});

const afterKickoff = (league, eventId = EVENT_ID) => ({
  id: 'Barnsley-Oldham-Athletic-2026-11-11',
  espnEventId: eventId,
  league,
  status: 'finished',
  statusShort: 'FT',
  homeOdds: null,
  drawOdds: null,
  awayOdds: null,
  homeScore: 5,
  awayScore: 2
});

test('cup competitions keep their pre-match odds after kickoff', () => {
  // These all failed before: the analysis says "Domestic Cup" but the league
  // name has no literal "cup" in it.
  const leagues = [
    'English EFL Trophy',
    'England - FA Trophy',
    'Spain - Copa del Rey',
    'Italy - Coppa Italia',
    'France - Coupe de France',
    'Germany - DFB Pokal',
    'Portugal - Taca de Portugal',
    'England - FA Cup'
  ];

  for (const league of leagues) {
    const match = afterKickoff(league);
    preservePredictionLock(match, preMatch(league), false);
    assert.equal(match.homeOdds, 1.69, `${league}: homeOdds`);
    assert.equal(match.drawOdds, 4.4, `${league}: drawOdds`);
    assert.equal(match.awayOdds, 3.65, `${league}: awayOdds`);
    assert.equal(match.oddsRating, 12, `${league}: oddsRating`);
    assert.equal(match.prediction.recommendation, 'Barnsley to Win (1)', `${league}: pick`);
  }
});

test('a different fixture is never reused', () => {
  const match = afterKickoff('English EFL Trophy', '999999999');
  preservePredictionLock(match, preMatch('English EFL Trophy'), false);
  assert.equal(match.homeOdds, null);
  assert.equal(match.prediction, undefined);
});

test('an upcoming match is not frozen to the old snapshot', () => {
  const match = {
    id: 'Barnsley-Oldham-Athletic-2026-11-11',
    espnEventId: EVENT_ID,
    league: 'English EFL Trophy',
    status: 'notStarted',
    statusShort: 'NS',
    date: '2099-01-01T19:00Z',
    homeOdds: 2.1,
    drawOdds: 3.9,
    awayOdds: 3.2,
    prediction: { recommendation: 'Barnsley refresh' }
  };
  preservePredictionLock(match, preMatch('English EFL Trophy'), false, Date.parse('2026-01-01T00:00:00Z'));
  assert.equal(match.homeOdds, 2.1, 'fresh price kept');
  assert.equal(match.prediction.recommendation, 'Barnsley refresh', 'fresh prediction kept');
});

test('odds erased before kickoff are restored', () => {
  const match = {
    id: 'Barnsley-Oldham-Athletic-2026-11-11',
    espnEventId: EVENT_ID,
    league: 'English EFL Trophy',
    status: 'notStarted',
    statusShort: 'NS',
    date: '2099-01-01T19:00Z',
    homeOdds: null,
    drawOdds: null,
    awayOdds: null
  };
  preservePredictionLock(match, preMatch('English EFL Trophy'), false, Date.parse('2026-01-01T00:00:00Z'));
  assert.equal(match.homeOdds, 1.69);
});

// ─── Web merge (docs/index.html) ──────────────────────────────────────────────
// The site merges the static archive, Cloudflare history and the live feed.
// A later record with null odds used to overwrite the archived price.
function loadWebMerge() {
  const html = fs.readFileSync(path.join(repoRoot, 'docs', 'index.html'), 'utf8');
  const start = html.indexOf('// >>> match-merge');
  const end = html.indexOf('// <<< match-merge');
  assert.ok(start > -1 && end > start, 'match-merge markers present in docs/index.html');
  const block = html.slice(start, end);
  return new Function(`${block}; return mergeMatch;`)();
}

test('web merge keeps archived odds when the live record has none', () => {
  const mergeMatch = loadWebMerge();
  const archived = preMatch('English EFL Trophy');
  const live = afterKickoff('English EFL Trophy');

  const merged = mergeMatch(archived, live);

  assert.equal(merged.homeOdds, 1.69);
  assert.equal(merged.drawOdds, 4.4);
  assert.equal(merged.awayOdds, 3.65);
  assert.equal(merged.prediction.recommendation, 'Barnsley to Win (1)');
  assert.equal(merged.homeScore, 5, 'live score still wins');
  assert.equal(merged.status, 'finished', 'live status still wins');
});

test('web merge lets a fresher priced record win', () => {
  const mergeMatch = loadWebMerge();
  const archived = preMatch('English EFL Trophy');
  const live = { ...preMatch('English EFL Trophy'), homeOdds: 1.55, awayOdds: 3.9, prediction: { recommendation: 'Barnsley to Win (1)' } };

  const merged = mergeMatch(archived, live);

  assert.equal(merged.homeOdds, 1.55, 'newer price kept');
  assert.equal(merged.awayOdds, 3.9, 'newer price kept');
});

test('web merge records a single match when only one source exists', () => {
  const mergeMatch = loadWebMerge();
  const archived = preMatch('English EFL Trophy');
  const merged = mergeMatch(undefined, archived);
  assert.equal(merged.homeOdds, 1.69);
});
