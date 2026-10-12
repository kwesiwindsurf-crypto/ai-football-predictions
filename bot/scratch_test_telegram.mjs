// Test script for Telegram Message Formatting & Dashboard
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8999449179:AAGX1qsjFa9SyHNSWIpffapaRDB5mvIfSEA';
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || '-1001738283594';

async function sendTelegramMessage(text) {
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text, parse_mode: 'Markdown' })
    });
    const result = await res.json();
    if (!result.ok) {
      console.warn('Telegram Markdown error, retrying plain text:', result.description);
      const retryRes = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: text.replace(/[*_`]/g, '') })
      });
      return await retryRes.json();
    }
    return result;
  } catch (e) {
    console.error('Error:', e.message);
  }
}

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

async function testDailyDashboard() {
  const sampleResults = [
    { homeTeam: 'Arsenal', awayTeam: 'Chelsea', homeScore: 2, awayScore: 1, recommendation: 'Arsenal to Win (1)', result: 'WON', isDraw: false, isPickOfTheDay: true },
    { homeTeam: 'Real Madrid', awayTeam: 'Real Betis', homeScore: 3, awayScore: 0, recommendation: 'Real Madrid to Win (1)', result: 'WON', isDraw: false },
    { homeTeam: 'Liverpool', awayTeam: 'Everton', homeScore: 1, awayScore: 1, recommendation: 'Over 1.5 Goals', result: 'WON', isDraw: true },
    { homeTeam: 'Juventus', awayTeam: 'Inter Milan', homeScore: 0, awayScore: 1, recommendation: 'Juventus to Win (1)', result: 'LOST', isDraw: false }
  ];

  const total = sampleResults.length;
  const wins = sampleResults.filter(r => r.result === 'WON').length;
  const draws = sampleResults.filter(r => r.isDraw).length;
  const losses = sampleResults.filter(r => r.result === 'LOST').length;
  const decided = wins + losses;
  const winRate = decided > 0 ? Math.round((wins / decided) * 100) : 0;

  const dateFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric'
  });

  let msg = `📊 *DAILY PERFORMANCE DASHBOARD* 📊\n` +
            `📅 *${dateFormatted}*\n\n` +
            `🎯 *Today's Scorecard:*\n` +
            `✅ *Wins:* ${wins}\n` +
            `🤝 *Draws:* ${draws} match${draws === 1 ? '' : 'es'}\n` +
            `❌ *Losses:* ${losses}\n` +
            `📈 *Accuracy:* ${winRate}% (${wins}/${decided})\n\n` +
            `────────────────────\n` +
            `📋 *Matches Breakdown:*\n`;

  for (const r of sampleResults) {
    const icon = r.result === 'WON' ? '✅' : r.result === 'LOST' ? '❌' : '🏁';
    const pod = r.isPickOfTheDay ? ' ⭐' : '';
    const drawTag = r.isDraw ? ' (Draw)' : '';
    msg += `• *${r.homeTeam} ${r.homeScore} - ${r.awayScore} ${r.awayTeam}*${pod}\n` +
           `  Pick: ${r.recommendation} ➔ ${icon} *${r.result}*${drawTag}\n`;
  }

  msg += `────────────────────\n` +
         `📲 _Check tomorrow's fixtures & early predictions in the app!_`;

  console.log(msg);
}

testDailyDashboard();
