import https from 'https';

console.log("Testing with native https.get...");
const req = https.get('https://ai-football-bot.xantechs00.workers.dev/', { timeout: 10000 }, (res) => {
  console.log("Status code:", res.statusCode);
  console.log("Headers:", res.headers);
  let bytes = 0;
  res.on('data', chunk => { bytes += chunk.length; });
  res.on('end', () => {
    console.log("Received bytes:", bytes);
  });
});

req.on('error', (e) => {
  console.error("HTTP error:", e);
});

req.on('timeout', () => {
  console.error("Request timed out!");
  req.destroy();
});
