async function inspectGalatasaray() {
  const dates = ['20261030', '20261031', '20261101'];
  for (const d of dates) {
    const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard?dates=${d}&limit=300`;
    try {
      const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      const data = await res.json();
      const match = (data.events || []).find(e => 
        (e.name || '').toLowerCase().includes('galatasaray') ||
        (e.shortName || '').toLowerCase().includes('galatasaray')
      );
      if (match) {
        console.log(`Found Galatasaray match in date ${d}:`);
        console.log('Event Name:', match.name);
        console.log('Event Date:', match.date);
        console.log('Status State:', match.competitions?.[0]?.status?.type?.state);
        console.log('Status Detail:', match.competitions?.[0]?.status?.type?.detail);
        console.log('Competitors:', match.competitions?.[0]?.competitors?.map(c => `${c.team?.displayName}: ${c.score}`));
        return;
      }
    } catch (e) {
      console.error(e.message);
    }
  }
  console.log('Galatasaray match not found in those dates.');
}

inspectGalatasaray();
