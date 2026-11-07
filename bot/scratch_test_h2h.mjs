
async function fetchEspnLeagueFixtures(slug, dateStr) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${slug}/scoreboard?dates=${dateStr}&limit=100`;
  const res = await fetch(url);
  if (!res.ok) return [];
  const data = await res.json();
  if (!data.events) return [];
  return data.events;
}

async function fetchEspnSummary(leagueSlug, eventId) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${leagueSlug}/summary?event=${eventId}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  return res.json();
}

async function testH2H() {
  const d = new Date();
  d.setDate(d.getDate() - 1); // yesterday
  const dateStr = d.toISOString().slice(0, 10).replace(/-/g, '');
  console.log(`Fetching games for ${dateStr}...`);
  
  // Test a few top leagues
  const leagues = ['eng.1', 'esp.1', 'ita.1', 'ger.1'];
  
  for (const slug of leagues) {
    const events = await fetchEspnLeagueFixtures(slug, dateStr);
    if (events.length > 0) {
      console.log(`\nFound ${events.length} matches in ${slug}`);
      for (const ev of events) {
        const home = ev.competitions[0].competitors.find(c => c.homeAway === 'home').team.name;
        const away = ev.competitions[0].competitors.find(c => c.homeAway === 'away').team.name;
        console.log(`\nMatch: ${home} vs ${away}`);
        
        const summary = await fetchEspnSummary(slug, ev.id);
        if (summary && summary.seasonseries && summary.seasonseries.length > 0) {
          console.log(`H2H Summary: ${summary.seasonseries[0].summary}`);
        } else {
          console.log(`H2H Summary: No historical data available on ESPN.`);
        }
      }
    }
  }
}

testH2H();
