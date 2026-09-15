async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=20260915&limit=100';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  const data = await res.json();
  const ev = data.events[0];
  const comp = ev.competitions[0];
  console.log('competitors:');
  comp.competitors.forEach(c => {
    console.log(c.homeAway, c.team.displayName);
  });
}
run();
