import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function evaluatePrediction(rec, hScore, aScore, hTeam, aTeam) {
  const h = parseInt(hScore, 10);
  const a = parseInt(aScore, 10);
  if (isNaN(h) || isNaN(a)) return { result: 'PENDING', isDraw: false };

  const total = h + a;
  const isDraw = (h === a);
  const recStr = rec || '';

  let result = 'UNKNOWN';

  if (recStr.includes('to Win (1)')) {
    result = h > a ? 'WON' : 'LOST';
  } else if (recStr.includes('to Win (2)')) {
    result = a > h ? 'WON' : 'LOST';
  } else if (recStr.includes('or Draw') || recStr.includes('Double Chance') || recStr.includes('1X') || recStr.includes('X2')) {
    const isHome = recStr.includes(hTeam) || recStr.includes('1X');
    const isAway = recStr.includes(aTeam) || recStr.includes('X2');
    if (isHome && !isAway) result = h >= a ? 'WON' : 'LOST';
    else if (isAway && !isHome) result = a >= h ? 'WON' : 'LOST';
    else if (recStr.includes('12')) result = h !== a ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 0.5')) {
    result = total >= 1 ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 1.5')) {
    result = total >= 2 ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 2.5')) {
    result = total >= 3 ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 3.5')) {
    result = total >= 4 ? 'WON' : 'LOST';
  } else if (recStr.includes('Under 1.5')) {
    result = total < 2 ? 'WON' : 'LOST';
  } else if (recStr.includes('Under 2.5')) {
    result = total < 3 ? 'WON' : 'LOST';
  } else if (recStr.includes('Under 3.5')) {
    result = total < 4 ? 'WON' : 'LOST';
  } else if (recStr.includes('Both Teams To Score') || recStr.includes('BTTS')) {
    result = (h > 0 && a > 0) ? 'WON' : 'LOST';
  } else if (recStr.toLowerCase().includes('draw')) {
    result = h === a ? 'WON' : 'LOST';
  }

  return { result, isDraw };
}

async function run() {
  const API_URL = 'https://ai-football-bot.xantechs00.workers.dev';
  
  let json = {};
  try {
    const res = await fetch(API_URL);
    json = await res.json();
  } catch (e) {
    console.error('Error fetching worker:', e.message);
  }

  const rollingMatches = json.matchesData?.matches || json.matches || [];
  const historicalMatches = Array.isArray(json.historicalMatches) ? json.historicalMatches : [];

  let staticHistory = [];
  try {
    const historyPath = path.resolve(__dirname, '../docs/data/history.json');
    if (fs.existsSync(historyPath)) {
      staticHistory = JSON.parse(fs.readFileSync(historyPath, 'utf8'));
    }
  } catch (e) {
    console.error('Error reading static history:', e.message);
  }

  const matchMap = new Map();
  [...staticHistory, ...historicalMatches].forEach(m => {
    if (m && m.id) matchMap.set(m.id, m);
  });
  rollingMatches.forEach(m => {
    if (m && m.id) matchMap.set(m.id, m);
  });

  const allMatches = Array.from(matchMap.values()).map(m => {
    const rec = m.prediction?.recommendation || '';
    const evalRes = (m.status === 'finished' || m.statusShort === 'FT')
      ? evaluatePrediction(rec, m.homeScore, m.awayScore, m.homeTeam, m.awayTeam)
      : { result: 'PENDING', isDraw: false };
    return {
      ...m,
      evalResult: evalRes.result,
      isDraw: evalRes.isDraw
    };
  });

  const won = allMatches.filter(m => m.evalResult === 'WON');
  const lost = allMatches.filter(m => m.evalResult === 'LOST');
  const pending = allMatches.filter(m => m.evalResult === 'PENDING');
  const unknown = allMatches.filter(m => m.evalResult === 'UNKNOWN');

  console.log(`Total Matches: ${allMatches.length}`);
  console.log(`Won: ${won.length}, Lost: ${lost.length}, Pending: ${pending.length}, Unknown: ${unknown.length}`);

  console.log('\n--- BREAKDOWN OF 35 LOSSES ---');

  // Breakdown by recommendation type
  const recStats = {};
  const leagueStats = {};
  const scoreStats = {};

  lost.forEach(m => {
    const rec = m.prediction?.recommendation || 'No Rec';
    recStats[rec] = (recStats[rec] || 0) + 1;

    const league = m.league || 'Unknown';
    leagueStats[league] = (leagueStats[league] || 0) + 1;

    const score = `${m.homeScore}-${m.awayScore}`;
    scoreStats[score] = (scoreStats[score] || 0) + 1;
  });

  console.log('\nBy Recommendation:');
  console.table(recStats);

  console.log('\nBy Scoreline:');
  console.table(scoreStats);

  console.log('\nBy League:');
  console.table(leagueStats);

  console.log('\n--- DETAILED LIST OF ALL LOST MATCHES ---');
  lost.forEach((m, idx) => {
    const rec = m.prediction?.recommendation || 'N/A';
    const hp = m.prediction?.homeWinProbability ?? '?';
    const dp = m.prediction?.drawProbability ?? '?';
    const ap = m.prediction?.awayWinProbability ?? '?';
    const totalGoals = (parseInt(m.homeScore, 10) || 0) + (parseInt(m.awayScore, 10) || 0);
    console.log(`${idx + 1}. [${m.league}] ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam} | Date: ${m.date}`);
    console.log(`   Recommendation: "${rec}" | Odds Rating: ${m.oddsRating} | Probs: H:${hp}% D:${dp}% A:${ap}% | Total Goals: ${totalGoals}`);
    console.log(`   Analysis Note: ${m.prediction?.analysis?.replace(/\n/g, ' ') || 'None'}`);
    console.log('');
  });
}

run();
