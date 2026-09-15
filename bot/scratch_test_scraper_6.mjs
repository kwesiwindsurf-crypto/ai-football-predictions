function amToDec(am) {
  if (!am) return null;
  if (am > 0) return parseFloat(((am / 100) + 1).toFixed(2));
  if (am < 0) return parseFloat(((100 / Math.abs(am)) + 1).toFixed(2));
  return null;
}

function parseEspnEvent(ev) {
  const comp = ev.competitions?.[0];
  if (!comp) return 'no comp';

  const homeComp = comp.competitors?.find(c => c.homeAway === 'home');
  const awayComp = comp.competitors?.find(c => c.homeAway === 'away');
  if (!homeComp || !awayComp) return 'no home/away';

  const homeTeam = homeComp.team?.displayName || homeComp.team?.name || '';
  const awayTeam = awayComp.team?.displayName || awayComp.team?.name || '';
  if (!homeTeam || !awayTeam) return 'no team names';

  return 'success';
}

async function run() {
  const url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=20260915&limit=100';
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  const data = await res.json();
  data.events.forEach(ev => {
    console.log(ev.name, '=>', parseEspnEvent(ev));
  });
}
run();
