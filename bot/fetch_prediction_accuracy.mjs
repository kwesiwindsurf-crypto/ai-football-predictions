/**
 * fetch_prediction_accuracy.mjs
 * 
 * Fetches our live predictions from the Cloudflare Worker, then compares
 * them against actual finished results to calculate prediction accuracy.
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WORKER_URL = 'https://ai-football-bot.xantechs00.workers.dev';
const OUT_FILE = path.join(__dirname, 'prediction_accuracy.csv');

async function main() {
  console.log('Fetching predictions from Cloudflare Worker...\n');
  
  const res = await fetch(WORKER_URL);
  if (!res.ok) {
    console.error(`Worker returned ${res.status}`);
    process.exit(1);
  }
  
  const data = await res.json();
  
  // The worker returns { matchesData: { matches: [...] } }
  const matches = data?.matchesData?.matches || data?.matches || data || [];
  
  if (!Array.isArray(matches)) {
    console.log('Response structure:', Object.keys(data));
    console.log('Sample:', JSON.stringify(data).slice(0, 500));
    process.exit(1);
  }
  
  console.log(`Total matches from worker: ${matches.length}`);
  
  // Filter finished matches only
  const finished = matches.filter(m => {
    const s = (m.status || '').toLowerCase();
    const ss = (m.statusShort || '').toUpperCase();
    return s === 'finished' || ss === 'FT' || ss === 'AET' || ss === 'PEN';
  });
  
  console.log(`Finished matches: ${finished.length}\n`);
  
  if (finished.length === 0) {
    console.log('No finished matches found. Let me check the data structure...');
    console.log('First match sample:', JSON.stringify(matches[0], null, 2));
    
    // Try alternative: check for matches with scores
    const withScores = matches.filter(m => 
      m.homeScore !== null && m.homeScore !== undefined && m.homeScore !== '' &&
      m.awayScore !== null && m.awayScore !== undefined && m.awayScore !== ''
    );
    console.log(`Matches with scores: ${withScores.length}`);
    if (withScores.length > 0) {
      console.log('Sample with score:', JSON.stringify(withScores[0], null, 2));
    }
  }
  
  // Analyze each finished match
  const HEADERS = [
    'date', 'league', 'home_team', 'away_team',
    'home_score', 'away_score', 'total_goals', 'actual_result',
    'predicted_rec', 'home_prob', 'draw_prob', 'away_prob',
    'predicted_result', 'rec_correct', 'prob_correct',
    'over_1_5', 'over_2_5', 'btts'
  ];
  
  const lines = [HEADERS.join(',')];
  let totalAnalyzed = 0;
  let recCorrect = 0;  // recommendation was correct
  let probCorrect = 0; // highest probability outcome was correct
  let over15Hit = 0;
  let over25Hit = 0;
  let bttsHit = 0;
  
  for (const m of finished) {
    const hs = parseInt(m.homeScore, 10);
    const as = parseInt(m.awayScore, 10);
    if (isNaN(hs) || isNaN(as)) continue;
    
    const totalGoals = hs + as;
    const actualResult = hs > as ? 'H' : (hs < as ? 'A' : 'D');
    
    const pred = m.prediction || {};
    const hp = pred.homeWinProbability || 33;
    const dp = pred.drawProbability || 33;
    const ap = pred.awayWinProbability || 33;
    const rec = pred.recommendation || '';
    
    // What did our probabilities predict?
    let probPredicted = 'D';
    if (hp > dp && hp > ap) probPredicted = 'H';
    else if (ap > dp && ap > hp) probPredicted = 'A';
    
    // Check if recommendation was correct
    const recLower = rec.toLowerCase();
    let recIsCorrect = false;
    
    // Direct win predictions
    if (recLower.includes('to win (1)') || recLower.includes('home win')) {
      recIsCorrect = actualResult === 'H';
    } else if (recLower.includes('to win (2)') || recLower.includes('away win')) {
      recIsCorrect = actualResult === 'A';
    }
    // Double chance
    else if (recLower.includes('1x') || (recLower.includes('or draw') && recLower.includes(m.homeTeam?.toLowerCase() || ''))) {
      recIsCorrect = actualResult === 'H' || actualResult === 'D';
    } else if (recLower.includes('x2') || (recLower.includes('or draw') && recLower.includes(m.awayTeam?.toLowerCase() || ''))) {
      recIsCorrect = actualResult === 'A' || actualResult === 'D';
    }
    // 12 (No Draw)
    else if (recLower.includes('12') || recLower.includes('home/away')) {
      recIsCorrect = actualResult !== 'D';
    }
    // Goals markets
    else if (recLower.includes('over 0.5')) {
      recIsCorrect = totalGoals > 0;
    } else if (recLower.includes('over 1.5')) {
      recIsCorrect = totalGoals >= 2;
    } else if (recLower.includes('over 2.5')) {
      recIsCorrect = totalGoals >= 3;
    } else if (recLower.includes('under 2.5')) {
      recIsCorrect = totalGoals < 3;
    } else if (recLower.includes('under 3.5')) {
      recIsCorrect = totalGoals < 4;
    }
    
    const probIsCorrect = probPredicted === actualResult;
    const isOver15 = totalGoals >= 2;
    const isOver25 = totalGoals >= 3;
    const isBtts = hs > 0 && as > 0;
    
    totalAnalyzed++;
    if (recIsCorrect) recCorrect++;
    if (probIsCorrect) probCorrect++;
    if (isOver15) over15Hit++;
    if (isOver25) over25Hit++;
    if (isBtts) bttsHit++;
    
    const csvCell = (val) => {
      const s = String(val ?? '');
      return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s;
    };
    
    lines.push([
      m.date || '', m.league || '', m.homeTeam || '', m.awayTeam || '',
      hs, as, totalGoals, actualResult,
      rec, hp, dp, ap,
      probPredicted, recIsCorrect ? 'Y' : 'N', probIsCorrect ? 'Y' : 'N',
      isOver15 ? 'Y' : 'N', isOver25 ? 'Y' : 'N', isBtts ? 'Y' : 'N'
    ].map(csvCell).join(','));
  }
  
  fs.writeFileSync(OUT_FILE, lines.join('\n'), 'utf8');
  
  const pct = (n) => totalAnalyzed > 0 ? ((n / totalAnalyzed) * 100).toFixed(1) : '0.0';
  
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  OUR AI PREDICTION ACCURACY`);
  console.log(`${'═'.repeat(60)}`);
  console.log(`  Finished matches analyzed: ${totalAnalyzed}`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  RECOMMENDATION ACCURACY:`);
  console.log(`    Correct: ${recCorrect} / ${totalAnalyzed}  (${pct(recCorrect)}%)`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  PROBABILITY-BASED ACCURACY (highest prob = predicted):`);
  console.log(`    Correct: ${probCorrect} / ${totalAnalyzed}  (${pct(probCorrect)}%)`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  GOALS MARKETS (actual outcomes):`);
  console.log(`    Over 1.5:  ${over15Hit} / ${totalAnalyzed}  (${pct(over15Hit)}%)`);
  console.log(`    Over 2.5:  ${over25Hit} / ${totalAnalyzed}  (${pct(over25Hit)}%)`);
  console.log(`    BTTS:      ${bttsHit} / ${totalAnalyzed}  (${pct(bttsHit)}%)`);
  console.log(`${'═'.repeat(60)}`);
  console.log(`\n✅ Detailed CSV: ${OUT_FILE}`);
}

main().catch(e => { console.error(e); process.exit(1); });
