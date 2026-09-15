async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/standings';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  const data = await res.json();
  
  console.log('Top level keys:', Object.keys(data));
  if (data.standings) {
    console.log('Standings type:', typeof data.standings);
    console.log('Standings keys:', Object.keys(data.standings));
  }
}
run();
