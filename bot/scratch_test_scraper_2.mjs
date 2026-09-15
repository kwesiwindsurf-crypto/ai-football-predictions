async function fetchEspn(url) {
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const data = await res.json();
    console.log(url, '=> events:', data.events?.length || 0);
    if (data.events?.length > 0) {
      console.log('  First event:', data.events[0].name, '@', data.events[0].date);
    }
  } catch (e) {
    console.log('Error:', e.message);
  }
}

async function run() {
  await fetchEspn('https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard');
  await fetchEspn('https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard');
  await fetchEspn('https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.champions_league/scoreboard');
  await fetchEspn('https://site.api.espn.com/apis/site/v2/sports/soccer/ita.1/scoreboard');
}
run();
