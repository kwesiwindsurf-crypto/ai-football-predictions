async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=20260915&limit=100';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (compatible; AIFootballBot/1.0)' } });
  console.log('Status:', res.status);
}
run();
