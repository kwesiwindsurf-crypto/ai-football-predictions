import test from 'node:test';
import assert from 'node:assert/strict';

const { selectDigestPicks, pickConfidence, formatDigestMessage, DIGEST_PICKS_PER_DAY } =
  await import('../scraper.mjs');

const DATE = '2026-11-12';

let seq = 0;
function fixture({
  homeTeam = `Home ${++seq}`,
  awayTeam = `Away ${seq}`,
  date = `${DATE}T19:00Z`,
  home = 60,
  draw = 25,
  away = 15,
  priced = true,
  status = 'notStarted',
  statusShort = 'NS'
} = {}) {
  return {
    id: `${homeTeam}-${awayTeam}-${DATE}`.replace(/\s+/g, '-'),
    date,
    homeTeam,
    awayTeam,
    league: 'Test League',
    status,
    statusShort,
    homeOdds: priced ? 1.8 : null,
    drawOdds: priced ? 3.4 : null,
    awayOdds: priced ? 4.2 : null,
    prediction: {
      homeWinProbability: home,
      drawProbability: draw,
      awayWinProbability: away,
      recommendation: `${homeTeam} to Win (1)`
    }
  };
}

test('publishes exactly two picks per day', () => {
  const picks = selectDigestPicks([
    fixture({ home: 84 }), fixture({ home: 78 }), fixture({ home: 71 }), fixture({ home: 55 })
  ], DATE);

  assert.equal(DIGEST_PICKS_PER_DAY, 2);
  assert.equal(picks.length, 2);
});

test('ranks by confidence and never repeats a fixture', () => {
  const picks = selectDigestPicks([
    fixture({ home: 55 }), fixture({ home: 88 }), fixture({ home: 74 }), fixture({ home: 61 })
  ], DATE);

  assert.deepEqual(picks.map(pickConfidence), [88, 74]);
  assert.equal(new Set(picks.map(p => p.id)).size, 2);
});

test('a single qualifying fixture still publishes one pick', () => {
  const picks = selectDigestPicks([fixture({ home: 80 })], DATE);
  assert.equal(picks.length, 1);
});

test('odds-less fixtures never reach the channel', () => {
  const picks = selectDigestPicks([
    fixture({ home: 95, priced: false }),   // highest confidence, no market price
    fixture({ home: 70 }),
    fixture({ home: 66 })
  ], DATE);

  assert.equal(picks.length, 2);
  assert.deepEqual(picks.map(pickConfidence), [70, 66]);
});

test('finished fixtures are skipped while bettable ones remain', () => {
  const finished = fixture({ home: 99, status: 'finished', statusShort: 'FT' });
  const picks = selectDigestPicks([finished, fixture({ home: 64 }), fixture({ home: 58 })], DATE);

  assert.deepEqual(picks.map(pickConfidence), [64, 58]);
});

test('falls back to the whole day if every fixture has already finished', () => {
  const picks = selectDigestPicks([
    fixture({ home: 81, status: 'finished', statusShort: 'FT' }),
    fixture({ home: 75, status: 'finished', statusShort: 'FT' }),
    fixture({ home: 60, status: 'finished', statusShort: 'FT' })
  ], DATE);

  assert.deepEqual(picks.map(pickConfidence), [81, 75]);
});

test('postponed fixtures and other dates are ignored', () => {
  const picks = selectDigestPicks([
    fixture({ home: 96, status: 'postponed', statusShort: 'POSTP' }),
    fixture({ home: 94, date: '2026-11-13T19:00Z' }),
    fixture({ home: 72 }),
    fixture({ home: 68 })
  ], DATE);

  assert.deepEqual(picks.map(pickConfidence), [72, 68]);
});

test('no priced fixtures means no message', () => {
  assert.deepEqual(selectDigestPicks([fixture({ priced: false })], DATE), []);
  assert.deepEqual(selectDigestPicks([], DATE), []);
});

test('predictions without probabilities are ranked last, never first', () => {
  const noProbs = fixture({ home: 0, draw: 0, away: 0 });
  const picks = selectDigestPicks([noProbs, fixture({ home: 51 }), fixture({ home: 49 })], DATE);

  assert.deepEqual(picks.map(pickConfidence), [51, 49]);
});

test('the card shows both picks, numbered, with the matching header', () => {
  const picks = selectDigestPicks([
    fixture({ homeTeam: 'Alpha FC', awayTeam: 'Beta FC', home: 84, away: 10 }),
    fixture({ homeTeam: 'Gamma FC', awayTeam: 'Delta FC', home: 71, away: 20 })
  ], DATE);

  const card = formatDigestMessage(picks, DATE);

  assert.match(card, /TOP 2 PICKS/);
  assert.match(card, /#1 {2}ALPHA FC {2}v {2}BETA FC/);
  assert.match(card, /#2 {2}GAMMA FC {2}v {2}DELTA FC/);
  assert.match(card, /84%/);
  assert.match(card, /71%/);
  assert.ok(!card.includes('PICK OF THE DAY'), 'two picks must not be labelled a single Pick of the Day');
  assert.ok(card.trimEnd().endsWith('/'), 'dashboard link closes the message');
});

test('the card degrades to PICK OF THE DAY when only one fixture qualifies', () => {
  const picks = selectDigestPicks([fixture({ homeTeam: 'Solo FC', awayTeam: 'Only FC' })], DATE);
  const card = formatDigestMessage(picks, DATE);

  assert.match(card, /PICK OF THE DAY/);
  assert.match(card, /#1 {2}SOLO FC/);
  assert.ok(!card.includes('#2'));
});
