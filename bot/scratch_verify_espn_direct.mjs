async function verifyEspn() {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  console.log(`Checking ESPN API directly for date: ${dateStr}...`);

  const urls = [
    `https://site.api.espn.com/apis/site/v2/sports/soccer/tur.1/scoreboard?dates=${dateStr}`,
    `https://site.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard?dates=${dateStr}&limit=100`
  ];

  for (const url of urls) {
    console.log(`\nFetching: ${url}`);
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': 'application/json'
        }
      });
      const data = await res.json();
      const events = data.events || [];
      console.log(`Found ${events.length} events from ESPN.`);

      events.forEach(evt => {
        const comp = evt.competitions?.[0];
        if (!comp) return;
        const home = comp.competitors?.find(c => c.homeAway === 'home');
        const away = comp.competitors?.find(c => c.homeAway === 'away');
        const homeName = home?.team?.displayName || 'Home';
        const awayName = away?.team?.displayName || 'Away';
        const homeScore = home?.score ?? '0';
        const awayScore = away?.score ?? '0';
        const state = comp.status?.type?.state;
        const detail = comp.status?.type?.detail || comp.status?.type?.shortDetail || comp.status?.displayClock || '';

        console.log(`  -> [ESPN Raw] ${homeName} ${homeScore} - ${awayScore} ${awayName} | State: ${state} (${detail})`);
      });
    } catch (e) {
      console.error('Error fetching ESPN:', e.message);
    }
  }
}

verifyEspn();
