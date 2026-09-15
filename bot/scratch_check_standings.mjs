async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard?dates=20260918&limit=1';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' } });
  const data = await res.json();
  const ev = data.events[0];
  const comp = ev.competitions[0];
  const homeComp = comp.competitors.find(c => c.homeAway === 'home');
  
  console.log('Home Competitor Object Keys:', Object.keys(homeComp));
  console.log('Home Team Object Keys:', Object.keys(homeComp.team));
  
  if (homeComp.records) {
    console.log('Records:', JSON.stringify(homeComp.records, null, 2));
  }
  
  if (homeComp.form) {
    console.log('Form:', homeComp.form);
  }
}
run();
