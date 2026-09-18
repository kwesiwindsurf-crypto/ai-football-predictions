// Test script for Telegram Message Formatting
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8999449179:AAGX1qsjFa9SyHNSWIpffapaRDB5mvIfSEA';
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || '-1001738283594';

function evaluatePrediction(rec, hScore, aScore, hTeam, aTeam) {
  const h = parseInt(hScore);
  const a = parseInt(aScore);
  if (isNaN(h) || isNaN(a)) return 'PENDING';
  
  if (rec.includes('to Win (1)')) return h > a ? 'WON' : 'LOST';
  if (rec.includes('to Win (2)')) return a > h ? 'WON' : 'LOST';
  if (rec.includes('or Draw (Double Chance)')) {
    if (rec.includes(hTeam)) return h >= a ? 'WON' : 'LOST';
    if (rec.includes(aTeam)) return a >= h ? 'WON' : 'LOST';
  }
  if (rec.includes('Over 0.5 Goals')) {
    const total = h + a;
    if (total > 0) return 'WON';
    return 'LOST';
  }
  return 'UNKNOWN';
}

async function testTelegramResult() {
  const match = {
    homeTeam: 'Arsenal',
    awayTeam: 'Chelsea',
    homeScore: 1,
    awayScore: 1
  };
  const recommendation = 'Over 0.5 Goals';
  
  const result = evaluatePrediction(recommendation, match.homeScore, match.awayScore, match.homeTeam, match.awayTeam);
  
  const msg = `🚨 *FULL TIME RESULT* 🚨\n\n` +
              `⚽ *${match.homeTeam} ${match.homeScore} - ${match.awayScore} ${match.awayTeam}*\n\n` +
              `💡 *Our Pick:* ${recommendation}\n` +
              `${result === 'WON' ? '✅ *RESULT: WON*' : '❌ *RESULT: LOST*'}\n\n` +
              `📲 _Check the app for tomorrow's predictions!_`;

  console.log(msg);

  // Send test message
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: msg, parse_mode: 'Markdown' })
    });
    const resultObj = await res.json();
    console.log(resultObj);
  } catch (e) {
    console.error('Error:', e.message);
  }
}

testTelegramResult();
