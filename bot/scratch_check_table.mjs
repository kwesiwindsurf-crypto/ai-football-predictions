async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/standings';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  const data = await res.json();
  
  if (data.children && data.children.length > 0) {
    const table = data.children[0].standings?.entries;
    if (table) {
      console.log(`Found table with ${table.length} teams.`);
      console.log('Top 3 teams:');
      for (let i = 0; i < 3; i++) {
        const t = table[i];
        console.log(`${i+1}. ${t.team.displayName} - Points: ${t.stats.find(s=>s.name==='points')?.value} | Rank: ${t.stats.find(s=>s.name==='rank')?.value}`);
      }
    } else {
      console.log('No standings entries found.');
    }
  } else {
    console.log('No children array in response.');
  }
}
run();
