async function verifyYesterdayEspn() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard?dates=20261030&limit=100';
  console.log(`Fetching ESPN for 2026-10-30: ${url}`);
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Accept': 'application/json'
      }
    });
    const data = await res.json();
    const events = data.events || [];
    console.log(`Found ${events.length} events from ESPN for 2026-10-30.`);

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

      if (state === 'in' || state === 'post') {
        console.log(`  -> [ESPN FT/Live] ${homeName} ${homeScore} - ${awayScore} ${awayName} | State: ${state} (${detail})`);
      }
    });
  } catch (e) {
    console.error('Error fetching ESPN:', e.message);
  }
}

verifyYesterdayEspn();
