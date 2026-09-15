async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=20260915&limit=100';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  const data = await res.json();
  console.log('esp.1 20260915 events:', data.events?.length);
  if (data.events?.length > 0) {
    console.log(data.events.map(e => e.name));
  }
}
run();
