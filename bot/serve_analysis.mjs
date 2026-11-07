/**
 * serve_analysis.mjs
 * 
 * Reads matches_analysis.csv + prediction_accuracy.csv and serves a visual dashboard on localhost:3456
 */

import fs from 'fs';
import path from 'path';
import http from 'http';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CSV_FILE = path.join(__dirname, 'matches_analysis.csv');
const PRED_FILE = path.join(__dirname, 'prediction_accuracy.csv');

function parseCSV(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const raw = fs.readFileSync(filePath, 'utf8');
  const lines = raw.trim().split('\n');
  const headers = lines[0].split(',');
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const vals = [];
    let current = '';
    let inQuote = false;
    for (const ch of lines[i]) {
      if (ch === '"') { inQuote = !inQuote; continue; }
      if (ch === ',' && !inQuote) { vals.push(current); current = ''; continue; }
      current += ch;
    }
    vals.push(current);
    const obj = {};
    headers.forEach((h, idx) => { obj[h.trim()] = (vals[idx] || '').trim(); });
    rows.push(obj);
  }
  return rows;
}

function buildHTML(matches, predictions) {
  // ─── MATCHES ANALYSIS STATS ──────────────────────────────────────────────────
  const totalMatches = matches.length;
  const homeWins = matches.filter(m => m.result === 'H').length;
  const draws = matches.filter(m => m.result === 'D').length;
  const awayWins = matches.filter(m => m.result === 'A').length;
  const over05 = matches.filter(m => m.over_0_5 === 'Y').length;
  const over15 = matches.filter(m => m.over_1_5 === 'Y').length;
  const over25 = matches.filter(m => m.over_2_5 === 'Y').length;
  const over35 = matches.filter(m => m.over_3_5 === 'Y').length;
  const btts = matches.filter(m => m.btts === 'Y').length;
  const totalGoals = matches.reduce((s, m) => s + (parseInt(m.total_goals) || 0), 0);
  const avgGoals = totalMatches > 0 ? (totalGoals / totalMatches).toFixed(2) : '0';
  const pct = (n, t) => t > 0 ? ((n / t) * 100).toFixed(1) : '0.0';

  // Score frequency
  const scoreFreq = {};
  matches.forEach(m => {
    const key = `${m.home_score}-${m.away_score}`;
    scoreFreq[key] = (scoreFreq[key] || 0) + 1;
  });
  const topScores = Object.entries(scoreFreq).sort((a, b) => b[1] - a[1]).slice(0, 10);

  // Goals distribution
  const goalsDist = {};
  matches.forEach(m => {
    const g = parseInt(m.total_goals) || 0;
    goalsDist[g] = (goalsDist[g] || 0) + 1;
  });

  // League breakdown
  const leagueData = {};
  matches.forEach(m => {
    if (!leagueData[m.league]) leagueData[m.league] = { total: 0, H: 0, D: 0, A: 0, goals: 0, over15: 0, btts: 0 };
    const ld = leagueData[m.league];
    ld.total++;
    ld[m.result]++;
    ld.goals += parseInt(m.total_goals) || 0;
    if (m.over_1_5 === 'Y') ld.over15++;
    if (m.btts === 'Y') ld.btts++;
  });
  const leaguesSorted = Object.entries(leagueData)
    .filter(([, v]) => v.total >= 2)
    .sort((a, b) => b[1].total - a[1].total);

  // Per-date breakdown
  const dateData = {};
  matches.forEach(m => {
    if (!dateData[m.date]) dateData[m.date] = { total: 0, H: 0, D: 0, A: 0, goals: 0 };
    const dd = dateData[m.date];
    dd.total++;
    dd[m.result]++;
    dd.goals += parseInt(m.total_goals) || 0;
  });

  // ─── PREDICTION ACCURACY STATS ──────────────────────────────────────────────
  const totalPred = predictions.length;
  const recCorrect = predictions.filter(p => p.rec_correct === 'Y').length;
  const recWrong = predictions.filter(p => p.rec_correct === 'N').length;
  const probCorrect = predictions.filter(p => p.prob_correct === 'Y').length;

  // Breakdown by prediction type
  const predTypes = {};
  predictions.forEach(p => {
    const rec = p.predicted_rec || '';
    let type = 'Other';
    const rl = rec.toLowerCase();
    if (rl.includes('to win (1)') || rl.includes('to win (2)')) type = 'Direct Win';
    else if (rl.includes('double chance') || rl.includes('or draw')) type = 'Double Chance';
    else if (rl.includes('12') || rl.includes('home/away')) type = '12 (No Draw)';
    else if (rl.includes('over') || rl.includes('under')) type = 'Goals Market';
    
    if (!predTypes[type]) predTypes[type] = { total: 0, correct: 0 };
    predTypes[type].total++;
    if (p.rec_correct === 'Y') predTypes[type].correct++;
  });

  // Per league prediction accuracy
  const leaguePredAcc = {};
  predictions.forEach(p => {
    const lg = p.league || 'Unknown';
    if (!leaguePredAcc[lg]) leaguePredAcc[lg] = { total: 0, recCorrect: 0, probCorrect: 0 };
    leaguePredAcc[lg].total++;
    if (p.rec_correct === 'Y') leaguePredAcc[lg].recCorrect++;
    if (p.prob_correct === 'Y') leaguePredAcc[lg].probCorrect++;
  });
  const leaguePredSorted = Object.entries(leaguePredAcc)
    .filter(([, v]) => v.total >= 3)
    .sort((a, b) => (b[1].recCorrect / b[1].total) - (a[1].recCorrect / a[1].total));

  // Confidence buckets
  const confBuckets = { '60+': { total: 0, correct: 0 }, '55-59': { total: 0, correct: 0 }, '50-54': { total: 0, correct: 0 }, '<50': { total: 0, correct: 0 } };
  predictions.forEach(p => {
    const maxProb = Math.max(parseFloat(p.home_prob) || 0, parseFloat(p.draw_prob) || 0, parseFloat(p.away_prob) || 0);
    let bucket = '<50';
    if (maxProb >= 60) bucket = '60+';
    else if (maxProb >= 55) bucket = '55-59';
    else if (maxProb >= 50) bucket = '50-54';
    confBuckets[bucket].total++;
    if (p.prob_correct === 'Y') confBuckets[bucket].correct++;
  });

  // ─── PREDICTION ROWS ──────────────────────────────────────────────────────────
  const predRows = predictions.map(p => {
    const recClass = p.rec_correct === 'Y' ? 'pred-win' : 'pred-loss';
    const probClass = p.prob_correct === 'Y' ? 'pred-win' : 'pred-loss';
    const resultClass = p.actual_result === 'H' ? 'result-home' : p.actual_result === 'A' ? 'result-away' : 'result-draw';
    const maxProb = Math.max(parseFloat(p.home_prob) || 0, parseFloat(p.draw_prob) || 0, parseFloat(p.away_prob) || 0);
    const yn = v => v === 'Y' ? '<span class="yes">✓</span>' : '<span class="no">✗</span>';
    
    // Shortened date
    const dateStr = (p.date || '').replace('T', ' ').replace('Z', '').slice(0, 16);
    
    return `<tr class="${recClass}-row">
      <td class="date-col">${dateStr}</td>
      <td class="league-col">${p.league || ''}</td>
      <td class="team-col home-team">${p.home_team || ''}</td>
      <td class="score-col">${p.home_score} - ${p.away_score}</td>
      <td class="team-col away-team">${p.away_team || ''}</td>
      <td class="${resultClass}">${p.actual_result}</td>
      <td class="rec-col">${p.predicted_rec || ''}</td>
      <td class="prob-col">${p.home_prob}/${p.draw_prob}/${p.away_prob}</td>
      <td class="${recClass}"><b>${p.rec_correct === 'Y' ? '✅ WIN' : '❌ LOSS'}</b></td>
      <td class="${probClass}">${p.prob_correct === 'Y' ? '✅' : '❌'}</td>
      <td>${yn(p.over_1_5)}</td>
      <td>${yn(p.over_2_5)}</td>
      <td>${yn(p.btts)}</td>
    </tr>`;
  }).join('\n');

  // ─── MATCH TABLE ROWS ─────────────────────────────────────────────────────────
  const matchRows = matches.map(m => {
    const resultClass = m.result === 'H' ? 'result-home' : m.result === 'A' ? 'result-away' : 'result-draw';
    const yn = v => v === 'Y' ? '<span class="yes">✓</span>' : '<span class="no">✗</span>';
    return `<tr>
      <td class="date-col">${m.date}</td>
      <td class="time-col">${m.kickoff_utc}</td>
      <td class="league-col">${m.league}</td>
      <td class="team-col home-team">${m.home_team}</td>
      <td class="score-col">${m.home_score} - ${m.away_score}</td>
      <td class="team-col away-team">${m.away_team}</td>
      <td class="${resultClass}">${m.result}</td>
      <td class="goals-col">${m.total_goals}</td>
      <td>${yn(m.over_0_5)}</td>
      <td>${yn(m.over_1_5)}</td>
      <td>${yn(m.over_2_5)}</td>
      <td>${yn(m.over_3_5)}</td>
      <td>${yn(m.btts)}</td>
    </tr>`;
  }).join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Scorecast — Match Analysis Dashboard</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #0a0e1a;
    --surface: #111827;
    --surface2: #1a2236;
    --surface3: #1e293b;
    --border: #1e293b;
    --text: #e2e8f0;
    --text2: #94a3b8;
    --accent: #6366f1;
    --accent2: #818cf8;
    --green: #22c55e;
    --green-dim: #166534;
    --green-bg: rgba(34,197,94,0.10);
    --orange: #f59e0b;
    --orange-bg: rgba(245,158,11,0.10);
    --red: #ef4444;
    --red-dim: #991b1b;
    --red-bg: rgba(239,68,68,0.10);
    --blue: #3b82f6;
    --cyan: #06b6d4;
    --purple: #a855f7;
    --gold: #fbbf24;
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    font-family: 'Inter', -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
  }
  .bg-glow { position: fixed; top: -200px; right: -200px; width: 600px; height: 600px; background: radial-gradient(circle, rgba(99,102,241,0.08) 0%, transparent 70%); pointer-events: none; z-index: 0; }
  .bg-glow2 { position: fixed; bottom: -200px; left: -200px; width: 500px; height: 500px; background: radial-gradient(circle, rgba(34,197,94,0.06) 0%, transparent 70%); pointer-events: none; z-index: 0; }
  .container { max-width: 1500px; margin: 0 auto; padding: 24px; position: relative; z-index: 1; }

  /* Tab Navigation */
  .tabs { display: flex; gap: 4px; margin-bottom: 28px; background: var(--surface); border-radius: 14px; padding: 4px; border: 1px solid var(--border); width: fit-content; }
  .tab {
    padding: 12px 28px; border-radius: 10px; font-size: 14px; font-weight: 600;
    cursor: pointer; transition: all 0.25s; color: var(--text2); border: none;
    background: transparent; font-family: 'Inter', sans-serif; letter-spacing: -0.2px;
  }
  .tab:hover { color: var(--text); background: var(--surface2); }
  .tab.active { background: var(--accent); color: #fff; box-shadow: 0 4px 15px rgba(99,102,241,0.3); }
  .tab-content { display: none; }
  .tab-content.active { display: block; }

  /* Header */
  .header { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; padding-bottom: 20px; border-bottom: 1px solid var(--border); }
  .header-icon { width: 52px; height: 52px; border-radius: 16px; background: linear-gradient(135deg, var(--accent), var(--purple)); display: flex; align-items: center; justify-content: center; font-size: 26px; box-shadow: 0 4px 24px rgba(99,102,241,0.3); }
  .header h1 { font-size: 30px; font-weight: 800; letter-spacing: -0.5px; }
  .header h1 span { background: linear-gradient(135deg, var(--accent2), var(--cyan)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
  .header-sub { color: var(--text2); font-size: 14px; margin-top: 2px; }

  /* Stat Cards */
  .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 14px; margin-bottom: 28px; }
  .stat-card {
    background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 18px;
    position: relative; overflow: hidden; transition: transform 0.2s, box-shadow 0.2s;
  }
  .stat-card:hover { transform: translateY(-2px); box-shadow: 0 8px 30px rgba(0,0,0,0.3); }
  .stat-card::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px; border-radius: 16px 16px 0 0; }
  .stat-card.green::before { background: var(--green); }
  .stat-card.orange::before { background: var(--orange); }
  .stat-card.red::before { background: var(--red); }
  .stat-card.blue::before { background: var(--blue); }
  .stat-card.purple::before { background: var(--purple); }
  .stat-card.cyan::before { background: var(--cyan); }
  .stat-card.gold::before { background: var(--gold); }
  .stat-label { font-size: 11px; color: var(--text2); text-transform: uppercase; letter-spacing: 1px; font-weight: 600; }
  .stat-value { font-size: 30px; font-weight: 800; margin: 6px 0 4px; letter-spacing: -1px; }
  .stat-sub { font-size: 12px; color: var(--text2); }
  .stat-card.green .stat-value { color: var(--green); }
  .stat-card.orange .stat-value { color: var(--orange); }
  .stat-card.red .stat-value { color: var(--red); }
  .stat-card.blue .stat-value { color: var(--blue); }
  .stat-card.purple .stat-value { color: var(--purple); }
  .stat-card.cyan .stat-value { color: var(--cyan); }
  .stat-card.gold .stat-value { color: var(--gold); }

  /* Section */
  .section { margin-bottom: 28px; }
  .section-title { font-size: 17px; font-weight: 700; margin-bottom: 14px; display: flex; align-items: center; gap: 10px; }
  .section-title .dot { width: 8px; height: 8px; border-radius: 50%; }

  /* Charts Row */
  .charts-row { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 14px; margin-bottom: 28px; }
  @media (max-width: 1000px) { .charts-row { grid-template-columns: 1fr; } }
  .chart-card { background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 22px; }
  .chart-title { font-size: 13px; font-weight: 700; margin-bottom: 14px; color: var(--text2); text-transform: uppercase; letter-spacing: 0.5px; }

  /* Result Bar */
  .result-bar { display: flex; height: 36px; border-radius: 10px; overflow: hidden; margin-bottom: 10px; }
  .result-bar div { display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 12px; transition: width 0.6s ease; }
  .result-bar .home-seg { background: var(--green); }
  .result-bar .draw-seg { background: var(--orange); }
  .result-bar .away-seg { background: var(--red); }
  .result-legend { display: flex; gap: 16px; justify-content: center; font-size: 11px; color: var(--text2); }
  .result-legend span { display: flex; align-items: center; gap: 6px; }
  .result-legend .ldot { width: 10px; height: 10px; border-radius: 3px; }

  /* Horizontal Bars */
  .hbar-row { display: flex; align-items: center; margin-bottom: 8px; }
  .hbar-label { width: 80px; font-size: 12px; color: var(--text2); font-weight: 500; flex-shrink: 0; }
  .hbar-track { flex: 1; height: 26px; background: var(--surface2); border-radius: 8px; overflow: hidden; }
  .hbar-fill { height: 100%; border-radius: 8px; display: flex; align-items: center; justify-content: flex-end; padding-right: 8px; font-size: 11px; font-weight: 700; transition: width 0.8s ease; min-width: 36px; }
  .hbar-pct { margin-left: 8px; font-size: 12px; color: var(--text2); font-weight: 600; width: 50px; text-align: right; }

  /* Score Freq */
  .score-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(72px, 1fr)); gap: 6px; }
  .score-chip { background: var(--surface2); border-radius: 10px; padding: 8px 6px; text-align: center; border: 1px solid var(--border); transition: transform 0.2s; }
  .score-chip:hover { transform: scale(1.05); }
  .score-chip .sc { font-size: 16px; font-weight: 800; }
  .score-chip .sc-count { font-size: 10px; color: var(--text2); margin-top: 2px; }

  /* Big Accuracy Ring */
  .accuracy-ring-wrap { display: flex; align-items: center; justify-content: center; gap: 40px; padding: 20px; }
  .ring-container { text-align: center; }
  .ring-svg { width: 140px; height: 140px; }
  .ring-bg { fill: none; stroke: var(--surface3); stroke-width: 10; }
  .ring-fill { fill: none; stroke-width: 10; stroke-linecap: round; transition: stroke-dashoffset 1s ease; }
  .ring-text { font-size: 28px; font-weight: 800; fill: var(--text); font-family: 'Inter', sans-serif; }
  .ring-sub { font-size: 10px; fill: var(--text2); font-family: 'Inter', sans-serif; }
  .ring-label { font-size: 13px; color: var(--text2); margin-top: 8px; font-weight: 600; }

  /* Tables */
  .league-table, .pred-type-table { width: 100%; border-collapse: collapse; }
  .league-table th, .pred-type-table th {
    text-align: left; font-size: 11px; text-transform: uppercase;
    letter-spacing: 0.5px; color: var(--text2); padding: 10px 12px;
    border-bottom: 1px solid var(--border); font-weight: 600;
  }
  .league-table td, .pred-type-table td { padding: 10px 12px; border-bottom: 1px solid var(--border); font-size: 13px; }
  .league-table tr:hover, .pred-type-table tr:hover { background: rgba(99,102,241,0.04); }
  .league-name { font-weight: 600; max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  /* Match Table */
  .match-table-wrap { background: var(--surface); border: 1px solid var(--border); border-radius: 16px; overflow: hidden; }
  .match-table-scroll { overflow-x: auto; max-height: 650px; overflow-y: auto; }
  .match-table { width: 100%; border-collapse: collapse; font-size: 12px; }
  .match-table thead { position: sticky; top: 0; z-index: 2; }
  .match-table th {
    background: var(--surface2); padding: 10px 8px;
    text-align: center; font-size: 10px; text-transform: uppercase;
    letter-spacing: 0.5px; color: var(--text2); font-weight: 600;
    border-bottom: 2px solid var(--border);
  }
  .match-table td { padding: 8px 6px; border-bottom: 1px solid var(--border); text-align: center; white-space: nowrap; }
  .match-table tr:hover { background: rgba(99,102,241,0.05); }
  .match-table .team-col { text-align: left; font-weight: 500; max-width: 140px; overflow: hidden; text-overflow: ellipsis; }
  .match-table .home-team { text-align: right; padding-right: 10px; }
  .match-table .score-col { font-weight: 800; font-size: 14px; color: var(--accent2); min-width: 50px; }
  .match-table .league-col { text-align: left; color: var(--text2); font-size: 10px; max-width: 160px; overflow: hidden; text-overflow: ellipsis; }
  .match-table .date-col { color: var(--text2); font-size: 10px; }
  .match-table .time-col { color: var(--text2); font-size: 10px; }
  .match-table .goals-col { font-weight: 700; }
  .match-table .rec-col { text-align: left; font-size: 10px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; color: var(--text2); }
  .match-table .prob-col { font-size: 10px; color: var(--text2); font-family: monospace; }

  .result-home { color: var(--green); font-weight: 800; }
  .result-draw { color: var(--orange); font-weight: 800; }
  .result-away { color: var(--red); font-weight: 800; }
  .pred-win { color: var(--green); }
  .pred-loss { color: var(--red); }
  .pred-win-row { }
  .pred-loss-row { background: rgba(239,68,68,0.03); }
  .yes { color: var(--green); font-weight: 700; }
  .no { color: #4b5563; }

  /* Filters */
  .filters { display: flex; gap: 6px; margin-bottom: 14px; flex-wrap: wrap; }
  .filter-btn {
    background: var(--surface2); border: 1px solid var(--border);
    color: var(--text); padding: 7px 14px; border-radius: 10px;
    font-size: 12px; font-weight: 600; cursor: pointer;
    font-family: 'Inter', sans-serif; transition: all 0.2s;
  }
  .filter-btn:hover { border-color: var(--accent); }
  .filter-btn.active { background: var(--accent); border-color: var(--accent); color: #fff; }

  /* Win/Loss streak bar */
  .streak-bar { display: flex; gap: 2px; flex-wrap: wrap; margin-top: 8px; }
  .streak-dot { width: 18px; height: 18px; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-size: 9px; font-weight: 800; color: #fff; }
  .streak-dot.w { background: var(--green); }
  .streak-dot.l { background: var(--red); }

  @keyframes fadeUp { from { opacity:0; transform:translateY(20px); } to { opacity:1; transform:translateY(0); } }
  .animate { animation: fadeUp 0.5s ease forwards; }
  .delay-1 { animation-delay: 0.1s; opacity: 0; }
  .delay-2 { animation-delay: 0.2s; opacity: 0; }
  .delay-3 { animation-delay: 0.3s; opacity: 0; }
</style>
</head>
<body>
<div class="bg-glow"></div>
<div class="bg-glow2"></div>
<div class="container">

  <!-- Header -->
  <div class="header animate">
    <div class="header-icon">⚽</div>
    <div>
      <h1>AI <span>Scorecast</span> Dashboard</h1>
      <div class="header-sub">${predictions.length > 0 ? predictions.length + ' predictions tracked' : ''} · ${totalMatches} matches analyzed</div>
    </div>
  </div>

  <!-- Tabs -->
  <div class="tabs animate">
    <button class="tab active" onclick="switchTab('predictions')">🎯 AI Predictions</button>
    <button class="tab" onclick="switchTab('analysis')">📊 Match Analysis</button>
  </div>

  <!-- ═══════════════════════════ PREDICTIONS TAB ═══════════════════════════ -->
  <div class="tab-content active" id="tab-predictions">

    <!-- Accuracy Hero Cards -->
    <div class="stats-grid animate delay-1">
      <div class="stat-card gold">
        <div class="stat-label">Recommendation Accuracy</div>
        <div class="stat-value">${pct(recCorrect, totalPred)}%</div>
        <div class="stat-sub">${recCorrect} correct / ${totalPred} total</div>
      </div>
      <div class="stat-card green">
        <div class="stat-label">Wins (Rec Correct)</div>
        <div class="stat-value">${recCorrect}</div>
        <div class="stat-sub">predictions hit ✅</div>
      </div>
      <div class="stat-card red">
        <div class="stat-label">Losses (Rec Wrong)</div>
        <div class="stat-value">${recWrong}</div>
        <div class="stat-sub">predictions missed ❌</div>
      </div>
      <div class="stat-card purple">
        <div class="stat-label">Prob-Based Accuracy</div>
        <div class="stat-value">${pct(probCorrect, totalPred)}%</div>
        <div class="stat-sub">${probCorrect} / ${totalPred} (highest prob wins)</div>
      </div>
      <div class="stat-card blue">
        <div class="stat-label">Matches Analyzed</div>
        <div class="stat-value">${totalPred}</div>
        <div class="stat-sub">finished with predictions</div>
      </div>
      <div class="stat-card cyan">
        <div class="stat-label">Over 1.5 Rate</div>
        <div class="stat-value">${pct(predictions.filter(p => p.over_1_5 === 'Y').length, totalPred)}%</div>
        <div class="stat-sub">${predictions.filter(p => p.over_1_5 === 'Y').length} / ${totalPred}</div>
      </div>
    </div>

    <!-- Accuracy Charts -->
    <div class="charts-row animate delay-2">
      <!-- Accuracy Rings -->
      <div class="chart-card">
        <div class="chart-title">Accuracy Overview</div>
        <div class="accuracy-ring-wrap">
          ${[
            { label: 'Rec Accuracy', val: pct(recCorrect, totalPred), color: 'var(--gold)' },
            { label: 'Prob Accuracy', val: pct(probCorrect, totalPred), color: 'var(--purple)' },
          ].map(r => {
            const circumference = 2 * Math.PI * 52;
            const offset = circumference - (circumference * parseFloat(r.val) / 100);
            return `<div class="ring-container">
              <svg class="ring-svg" viewBox="0 0 120 120">
                <circle class="ring-bg" cx="60" cy="60" r="52"/>
                <circle class="ring-fill" cx="60" cy="60" r="52" 
                  stroke="${r.color}"
                  stroke-dasharray="${circumference}"
                  stroke-dashoffset="${offset}"
                  transform="rotate(-90 60 60)"/>
                <text class="ring-text" x="60" y="58" text-anchor="middle">${r.val}%</text>
                <text class="ring-sub" x="60" y="74" text-anchor="middle">${r.label === 'Rec Accuracy' ? recCorrect + '/' + totalPred : probCorrect + '/' + totalPred}</text>
              </svg>
              <div class="ring-label">${r.label}</div>
            </div>`;
          }).join('')}
        </div>
        <div style="margin-top: 12px;">
          <div class="chart-title" style="font-size:11px;">Win/Loss Streak</div>
          <div class="streak-bar">
            ${predictions.map(p => `<div class="streak-dot ${p.rec_correct === 'Y' ? 'w' : 'l'}" title="${(p.home_team||'')} vs ${(p.away_team||'')}">${p.rec_correct === 'Y' ? 'W' : 'L'}</div>`).join('')}
          </div>
        </div>
      </div>

      <!-- By Prediction Type -->
      <div class="chart-card">
        <div class="chart-title">Accuracy by Prediction Type</div>
        ${Object.entries(predTypes).map(([type, d]) => `
          <div class="hbar-row">
            <div class="hbar-label" style="width:100px;">${type}</div>
            <div class="hbar-track"><div class="hbar-fill" style="width:${pct(d.correct, d.total)}%;background:${parseFloat(pct(d.correct, d.total)) >= 65 ? 'var(--green)' : parseFloat(pct(d.correct, d.total)) >= 50 ? 'var(--orange)' : 'var(--red)'};">${d.correct}/${d.total}</div></div>
            <div class="hbar-pct">${pct(d.correct, d.total)}%</div>
          </div>
        `).join('')}
        <div style="margin-top: 20px;">
          <div class="chart-title" style="font-size:11px;">By Confidence Level (Prob Accuracy)</div>
          ${Object.entries(confBuckets).map(([bucket, d]) => `
            <div class="hbar-row">
              <div class="hbar-label" style="width:70px;">${bucket}%</div>
              <div class="hbar-track"><div class="hbar-fill" style="width:${d.total > 0 ? pct(d.correct, d.total) : 0}%;background:var(--accent);">${d.correct}/${d.total}</div></div>
              <div class="hbar-pct">${d.total > 0 ? pct(d.correct, d.total) : 0}%</div>
            </div>
          `).join('')}
        </div>
      </div>

      <!-- By League -->
      <div class="chart-card">
        <div class="chart-title">Accuracy by League (3+ matches)</div>
        <div style="max-height:400px;overflow-y:auto;">
          ${leaguePredSorted.map(([name, d]) => {
            const accPct = pct(d.recCorrect, d.total);
            const accColor = parseFloat(accPct) >= 75 ? 'var(--green)' : parseFloat(accPct) >= 60 ? 'var(--accent)' : parseFloat(accPct) >= 50 ? 'var(--orange)' : 'var(--red)';
            return `<div class="hbar-row" style="margin-bottom:6px;">
              <div class="hbar-label" style="width:180px;font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="${name}">${name}</div>
              <div class="hbar-track" style="height:22px;"><div class="hbar-fill" style="width:${accPct}%;background:${accColor};font-size:10px;">${d.recCorrect}/${d.total}</div></div>
              <div class="hbar-pct" style="font-size:11px;">${accPct}%</div>
            </div>`;
          }).join('')}
        </div>
      </div>
    </div>

    <!-- Predictions Table -->
    <div class="section animate delay-3">
      <div class="section-title"><span class="dot" style="background:var(--gold);"></span> All Predictions — Detail View</div>
      <div class="filters">
        <button class="filter-btn active" onclick="filterPred('all')">All (${totalPred})</button>
        <button class="filter-btn" onclick="filterPred('win')">✅ Wins (${recCorrect})</button>
        <button class="filter-btn" onclick="filterPred('loss')">❌ Losses (${recWrong})</button>
        <button class="filter-btn" onclick="filterPred('probwin')">Prob ✅ (${probCorrect})</button>
      </div>
      <div class="match-table-wrap">
        <div class="match-table-scroll">
          <table class="match-table" id="predTable">
            <thead><tr>
              <th>Date</th><th>League</th>
              <th>Home</th><th>Score</th><th>Away</th><th>Result</th>
              <th>AI Recommendation</th><th>H/D/A %</th>
              <th>Rec Result</th><th>Prob ✓</th>
              <th>O1.5</th><th>O2.5</th><th>BTTS</th>
            </tr></thead>
            <tbody id="predBody">
              ${predRows}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>

  <!-- ═══════════════════════════ ANALYSIS TAB ═══════════════════════════ -->
  <div class="tab-content" id="tab-analysis">

    <div class="stats-grid animate delay-1">
      <div class="stat-card blue">
        <div class="stat-label">Total Matches</div>
        <div class="stat-value">${totalMatches}</div>
        <div class="stat-sub">${totalGoals} total goals</div>
      </div>
      <div class="stat-card green">
        <div class="stat-label">Home Wins</div>
        <div class="stat-value">${homeWins}</div>
        <div class="stat-sub">${pct(homeWins, totalMatches)}% of matches</div>
      </div>
      <div class="stat-card orange">
        <div class="stat-label">Draws</div>
        <div class="stat-value">${draws}</div>
        <div class="stat-sub">${pct(draws, totalMatches)}% of matches</div>
      </div>
      <div class="stat-card red">
        <div class="stat-label">Away Wins</div>
        <div class="stat-value">${awayWins}</div>
        <div class="stat-sub">${pct(awayWins, totalMatches)}% of matches</div>
      </div>
      <div class="stat-card purple">
        <div class="stat-label">Avg Goals</div>
        <div class="stat-value">${avgGoals}</div>
        <div class="stat-sub">per match</div>
      </div>
      <div class="stat-card cyan">
        <div class="stat-label">BTTS</div>
        <div class="stat-value">${pct(btts, totalMatches)}%</div>
        <div class="stat-sub">${btts} / ${totalMatches} matches</div>
      </div>
    </div>

    <div class="charts-row animate delay-2">
      <div class="chart-card">
        <div class="chart-title">Results Breakdown</div>
        <div class="result-bar">
          <div class="home-seg" style="width:${pct(homeWins, totalMatches)}%">H ${homeWins}</div>
          <div class="draw-seg" style="width:${pct(draws, totalMatches)}%">D ${draws}</div>
          <div class="away-seg" style="width:${pct(awayWins, totalMatches)}%">A ${awayWins}</div>
        </div>
        <div class="result-legend">
          <span><span class="ldot" style="background:var(--green)"></span> Home ${pct(homeWins, totalMatches)}%</span>
          <span><span class="ldot" style="background:var(--orange)"></span> Draw ${pct(draws, totalMatches)}%</span>
          <span><span class="ldot" style="background:var(--red)"></span> Away ${pct(awayWins, totalMatches)}%</span>
        </div>
        <div style="margin-top:16px;">
          ${Object.entries(dateData).map(([date, d]) => `
            <div style="margin-bottom:6px;">
              <div style="font-size:11px;color:var(--text2);margin-bottom:3px;">${date} — ${d.total} matches</div>
              <div class="result-bar" style="height:22px;">
                <div class="home-seg" style="width:${(d.H/d.total*100).toFixed(1)}%;font-size:10px;">${d.H}</div>
                <div class="draw-seg" style="width:${(d.D/d.total*100).toFixed(1)}%;font-size:10px;">${d.D}</div>
                <div class="away-seg" style="width:${(d.A/d.total*100).toFixed(1)}%;font-size:10px;">${d.A}</div>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
      <div class="chart-card">
        <div class="chart-title">Goals Markets Hit Rate</div>
        ${[
          { label: 'Over 0.5', val: over05, color: 'var(--green)', grad: '#16a34a' },
          { label: 'Over 1.5', val: over15, color: 'var(--accent)', grad: 'var(--accent2)' },
          { label: 'Over 2.5', val: over25, color: 'var(--orange)', grad: '#d97706' },
          { label: 'Over 3.5', val: over35, color: 'var(--red)', grad: '#dc2626' },
          { label: 'BTTS', val: btts, color: 'var(--purple)', grad: 'var(--cyan)' },
        ].map(r => `
          <div class="hbar-row">
            <div class="hbar-label">${r.label}</div>
            <div class="hbar-track"><div class="hbar-fill" style="width:${pct(r.val, totalMatches)}%;background:linear-gradient(90deg,${r.color},${r.grad});">${r.val}</div></div>
            <div class="hbar-pct">${pct(r.val, totalMatches)}%</div>
          </div>
        `).join('')}
      </div>
      <div class="chart-card">
        <div class="chart-title">Most Common Scorelines</div>
        <div class="score-grid">
          ${topScores.map(([score, count]) => `
            <div class="score-chip">
              <div class="sc">${score}</div>
              <div class="sc-count">${count}× (${((count/totalMatches)*100).toFixed(0)}%)</div>
            </div>
          `).join('')}
        </div>
        <div style="margin-top:16px;">
          <div class="chart-title" style="font-size:11px;">Goals Distribution</div>
          ${Object.entries(goalsDist).sort((a,b) => parseInt(a[0]) - parseInt(b[0])).map(([g, count]) => `
            <div class="hbar-row" style="margin-bottom:5px;">
              <div class="hbar-label" style="width:50px;">${g} goals</div>
              <div class="hbar-track" style="height:20px;"><div class="hbar-fill" style="width:${(count/totalMatches*100).toFixed(1)}%;background:var(--accent);font-size:10px;">${count}</div></div>
              <div class="hbar-pct" style="font-size:10px;">${((count/totalMatches)*100).toFixed(0)}%</div>
            </div>
          `).join('')}
        </div>
      </div>
    </div>

    <div class="section animate delay-3">
      <div class="section-title"><span class="dot" style="background:var(--accent);"></span> League Breakdown (2+ matches)</div>
      <div class="chart-card" style="overflow-x:auto;">
        <table class="league-table">
          <thead><tr><th>League</th><th>Matches</th><th>H</th><th>D</th><th>A</th><th>Avg Goals</th><th>Over 1.5</th><th>BTTS</th></tr></thead>
          <tbody>
            ${leaguesSorted.map(([name, d]) => `<tr>
              <td class="league-name">${name}</td><td>${d.total}</td>
              <td style="color:var(--green)">${d.H}</td><td style="color:var(--orange)">${d.D}</td><td style="color:var(--red)">${d.A}</td>
              <td>${(d.goals/d.total).toFixed(1)}</td><td>${((d.over15/d.total)*100).toFixed(0)}%</td><td>${((d.btts/d.total)*100).toFixed(0)}%</td>
            </tr>`).join('')}
          </tbody>
        </table>
      </div>
    </div>

    <div class="section">
      <div class="section-title"><span class="dot" style="background:var(--green);"></span> All Matches</div>
      <div class="filters">
        <button class="filter-btn active" onclick="filterMatches('all')">All (${totalMatches})</button>
        <button class="filter-btn" onclick="filterMatches('H')">Home Wins (${homeWins})</button>
        <button class="filter-btn" onclick="filterMatches('D')">Draws (${draws})</button>
        <button class="filter-btn" onclick="filterMatches('A')">Away Wins (${awayWins})</button>
        <button class="filter-btn" onclick="filterMatches('over15')">Over 1.5 (${over15})</button>
        <button class="filter-btn" onclick="filterMatches('btts')">BTTS (${btts})</button>
      </div>
      <div class="match-table-wrap">
        <div class="match-table-scroll">
          <table class="match-table" id="matchTable">
            <thead><tr><th>Date</th><th>KO</th><th>League</th><th>Home</th><th>Score</th><th>Away</th><th>Result</th><th>Goals</th><th>O0.5</th><th>O1.5</th><th>O2.5</th><th>O3.5</th><th>BTTS</th></tr></thead>
            <tbody id="matchBody">${matchRows}</tbody>
          </table>
        </div>
      </div>
    </div>
  </div>

</div>

<script>
function switchTab(tab) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  event.target.classList.add('active');
  document.getElementById('tab-' + tab).classList.add('active');
}

function filterPred(type) {
  document.querySelectorAll('#tab-predictions .filter-btn').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  document.querySelectorAll('#predBody tr').forEach(row => {
    const cells = row.querySelectorAll('td');
    const recResult = cells[8]?.textContent?.trim() || '';
    const probResult = cells[9]?.textContent?.trim() || '';
    let show = true;
    if (type === 'win') show = recResult.includes('WIN');
    else if (type === 'loss') show = recResult.includes('LOSS');
    else if (type === 'probwin') show = probResult.includes('✅');
    row.style.display = show ? '' : 'none';
  });
}

function filterMatches(type) {
  document.querySelectorAll('#tab-analysis .filter-btn').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  document.querySelectorAll('#matchBody tr').forEach(row => {
    const cells = row.querySelectorAll('td');
    const result = cells[6]?.textContent?.trim();
    const o15 = cells[9]?.textContent?.trim();
    const btts = cells[12]?.textContent?.trim();
    let show = true;
    if (type === 'H') show = result === 'H';
    else if (type === 'D') show = result === 'D';
    else if (type === 'A') show = result === 'A';
    else if (type === 'over15') show = o15 === '✓';
    else if (type === 'btts') show = btts === '✓';
    row.style.display = show ? '' : 'none';
  });
}
</script>
</body>
</html>`;
}

const PORT = 3456;
const server = http.createServer((req, res) => {
  const matches = parseCSV(CSV_FILE);
  const predictions = parseCSV(PRED_FILE);
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(buildHTML(matches, predictions));
});

server.listen(PORT, () => {
  console.log(`\n⚽ AI Scorecast Dashboard running at: http://localhost:${PORT}\n`);
});
