// Test script for Telegram Message Formatting
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || 'YOUR_BOT_TOKEN_HERE';
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || 'YOUR_CHAT_ID_HERE';

async function testTelegram() {
  const bestMatch = {
    homeTeam: 'Arsenal',
    awayTeam: 'Chelsea',
    league: 'English Premier League',
    date: new Date().toISOString(),
    prediction: {
      recommendation: 'Over 0.5 Goals',
      stakingOptions: [{ risk: 'Safe', pick: 'Over 0.5 Goals' }]
    }
  };

  const safeOption = bestMatch.prediction.stakingOptions?.find(o => o.risk === 'Safe')?.pick || bestMatch.prediction.recommendation;
  const time = new Date(bestMatch.date).toLocaleTimeString('en-US', { hour: '2-digit', minute:'2-digit', timeZone: 'UTC' }) + ' UTC';

  const msg = `🏆 *PICK OF THE DAY* 🏆\n\n` +
              `⚽ *${bestMatch.homeTeam} vs ${bestMatch.awayTeam}*\n` +
              `🌍 ${bestMatch.league}\n` +
              `⏰ ${time}\n\n` +
              `💡 *AI Prediction:* ${bestMatch.prediction.recommendation}\n` +
              `🛡️ *Safe Option:* ${safeOption}\n\n` +
              `📲 _Get all our daily picks inside the app!_`;

  console.log("Here is what the message will look like:\\n");
  console.log(msg);

  // Uncomment below to actually test sending a message if you add your token/chat ID above
  /*
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: msg, parse_mode: 'Markdown' })
    });
    const result = await res.json();
    console.log(result);
  } catch (e) {
    console.error('Error:', e.message);
  }
  */
}

testTelegram();
