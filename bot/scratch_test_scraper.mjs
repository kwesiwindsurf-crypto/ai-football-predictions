// ─── Keywords used to filter out women's / youth / irrelevant matches ─────────
const EXCLUDED_LEAGUE_KEYWORDS = [
  'women', 'woman', 'femenino', 'feminine', 'frauen', 'dames',
  'femmes', 'nwsl', 'wsl', 'nwsl', 'u17', 'u19', 'u20', 'u21', 'u23',
  'youth', 'reserve', 'friendlies', 'international friendly',
  'ncaa', 'college'
];

const ESPN_LEAGUES = [
  { slug: 'eng.1',  label: 'England - Premier League' },
  { slug: 'esp.1',  label: 'Spain - La Liga' },
];

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function isoDate(d) { return d.toISOString().slice(0, 10); }
function espnDate(d) { return isoDate(d).replace(/-/g, ''); }

async function safeFetch(url, retries = 2) {
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36' }
      });
      if (res.ok) return res;
      console.log('HTTP Error:', res.status, res.statusText);
      if (i < retries) await sleep(400);
    } catch (e) {
      console.log('Fetch exception:', e.message);
      if (i < retries) await sleep(400);
    }
  }
  return null;
}

function isExcludedLeague(leagueName) {
  const lower = (leagueName || '').toLowerCase();
  return EXCLUDED_LEAGUE_KEYWORDS.some(kw => lower.includes(kw));
}

async function fetchEspnLeagueFixtures(slug, dateStr) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${slug}/scoreboard?dates=${dateStr}&limit=100`;
  console.log('Fetching:', url);
  const res = await safeFetch(url, 1);
  if (!res) {
    console.log('Failed to fetch:', url);
    return [];
  }
  try {
    const data = await res.json();
    return data.events || [];
  } catch (e) {
    console.log('Parse error:', e);
    return [];
  }
}

async function run() {
  const now = new Date();
  const d = espnDate(now);
  console.log('Date:', d);
  const evs = await fetchEspnLeagueFixtures('eng.1', d);
  console.log('Events:', evs.length);
  if (evs.length > 0) {
    console.log('First event:', evs[0].name);
  }
}
run();
