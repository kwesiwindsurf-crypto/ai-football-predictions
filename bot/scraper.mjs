// GitHub Actions Full Scraper — ESPN Only
// Fetches ALL matches, scores, and odds exclusively from ESPN.
// Pushes the result to Cloudflare KV for the Flutter app to consume.

const CF_ACCOUNT_ID = process.env.CF_ACCOUNT_ID;
const CF_API_TOKEN  = process.env.CF_API_TOKEN;
const CF_KV_NS_ID   = process.env.CF_KV_NAMESPACE_ID;
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '8999449179:AAGX1qsjFa9SyHNSWIpffapaRDB5mvIfSEA';
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID || '-1001738283594';
const KV_KEY        = 'latest_soccer_data';

// ─── Keywords used to filter out women's / youth / irrelevant matches ─────────
const EXCLUDED_LEAGUE_KEYWORDS = [
  'women', 'woman', 'femenino', 'feminine', 'frauen', 'dames',
  'femmes', 'nwsl', 'wsl', 'nwsl', 'u17', 'u19', 'u20', 'u21', 'u23',
  'youth', 'reserve',
  'ncaa', 'college'
];

// ─── ESPN league slugs to fetch fixtures for (covers major leagues + cups) ────
// Format: { slug, label }  — slug is used in ESPN API URL
const ESPN_LEAGUES = [
  { slug: 'eng.1',  label: 'England - Premier League' },
  { slug: 'eng.2',  label: 'England - Championship' },
  { slug: 'eng.3',  label: 'England - League One' },
  { slug: 'eng.4',  label: 'England - League Two' },
  { slug: 'eng.fa', label: 'England - FA Cup' },
  { slug: 'eng.league_cup', label: 'England - EFL Cup' },
  { slug: 'esp.1',  label: 'Spain - La Liga' },
  { slug: 'esp.2',  label: 'Spain - Segunda División' },
  { slug: 'esp.copa_del_rey', label: 'Spain - Copa del Rey' },
  { slug: 'ita.1',  label: 'Italy - Serie A' },
  { slug: 'ita.2',  label: 'Italy - Serie B' },
  { slug: 'ita.coppa_italia', label: 'Italy - Coppa Italia' },
  { slug: 'ger.1',  label: 'Germany - Bundesliga' },
  { slug: 'ger.2',  label: 'Germany - 2. Bundesliga' },
  { slug: 'ger.dfb_pokal', label: 'Germany - DFB Pokal' },
  { slug: 'fra.1',  label: 'France - Ligue 1' },
  { slug: 'fra.2',  label: 'France - Ligue 2' },
  { slug: 'fra.coupe_de_france', label: 'France - Coupe de France' },
  { slug: 'ned.1',  label: 'Netherlands - Eredivisie' },
  { slug: 'por.1',  label: 'Portugal - Primeira Liga' },
  { slug: 'tur.1',  label: 'Turkey - Süper Lig' },
  { slug: 'bel.1',  label: 'Belgium - Pro League' },
  { slug: 'sco.1',  label: 'Scotland - Premiership' },
  { slug: 'gre.1',  label: 'Greece - Super League' },
  { slug: 'rus.1',  label: 'Russia - Premier League' },
  { slug: 'ukr.1',  label: 'Ukraine - Premier League' },
  { slug: 'aut.1',  label: 'Austria - Bundesliga' },
  { slug: 'sui.1',  label: 'Switzerland - Super League' },
  { slug: 'den.1',  label: 'Denmark - Superliga' },
  { slug: 'nor.1',  label: 'Norway - Eliteserien' },
  { slug: 'swe.1',  label: 'Sweden - Allsvenskan' },
  { slug: 'pol.1',  label: 'Poland - Ekstraklasa' },
  { slug: 'cze.1',  label: 'Czech Republic - First League' },
  { slug: 'mex.1',  label: 'Mexico - Liga MX' },
  { slug: 'usa.1',  label: 'USA - MLS' },
  { slug: 'bra.1',  label: 'Brazil - Série A' },
  { slug: 'arg.1',  label: 'Argentina - Liga Profesional' },
  { slug: 'chi.1',  label: 'Chile - Primera División' },
  { slug: 'col.1',  label: 'Colombia - Primera A' },
  { slug: 'sau.1',  label: 'Saudi Arabia - Pro League' },
  { slug: 'zaf.1',  label: 'South Africa - Premier League' },
  { slug: 'uefa.champions_league', label: 'UEFA - Champions League' },
  { slug: 'uefa.europa',           label: 'UEFA - Europa League' },
  { slug: 'uefa.europa.conf',      label: 'UEFA - Conference League' },
  { slug: 'conmebol.libertadores', label: 'Copa Libertadores' },
  { slug: 'conmebol.sudamericana', label: 'Copa Sudamericana' },
  { slug: 'fifa.world',            label: 'FIFA - World Cup' },
  { slug: 'uefa.euro',             label: 'UEFA - Euro' },
  { slug: 'uefa.nations',          label: 'UEFA - Nations League' },
  { slug: 'caf.nations',           label: 'CAF - Africa Cup of Nations' },
  { slug: 'conmebol.america',      label: 'CONMEBOL - Copa America' },
  { slug: 'concacaf.gold',         label: 'CONCACAF - Gold Cup' },
  { slug: 'afc.asian',             label: 'AFC - Asian Cup' },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function isoDate(d) { return d.toISOString().slice(0, 10); }
function espnDate(d) { return isoDate(d).replace(/-/g, ''); }

async function safeFetch(url, retries = 2) {
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
      });
      if (res.ok) return res;
      if (i < retries) await sleep(400);
    } catch (e) {
      if (i < retries) await sleep(400);
    }
  }
  return null;
}

// ─── Filter out women's/youth/irrelevant leagues ──────────────────────────────
function isExcludedLeague(leagueName) {
  const lower = (leagueName || '').toLowerCase();
  return EXCLUDED_LEAGUE_KEYWORDS.some(kw => lower.includes(kw));
}

// ─── Convert American moneyline odds → decimal odds ───────────────────────────
function amToDec(am) {
  if (!am) return null;
  if (am > 0) return parseFloat(((am / 100) + 1).toFixed(2));
  if (am < 0) return parseFloat(((100 / Math.abs(am)) + 1).toFixed(2));
  return null;
}

const BIG_TEAMS = [
  'manchester city',
  'arsenal',
  'liverpool',
  'chelsea',
  'manchester united',
  'tottenham hotspur',
  'newcastle united',
  'aston villa',
  'brighton & hove albion',
  'west ham united',
  'leeds united',
  'leicester city',
  'southampton',
  'burnley',
  'sheffield united',
  'west bromwich albion',
  'norwich city',
  'middlesbrough',
  'sunderland',
  'coventry city',
  'watford',
  'hull city',
  'birmingham city',
  'wrexham',
  'charlton athletic',
  'huddersfield town',
  'bolton wanderers',
  'reading',
  'peterborough united',
  'barnsley',
  'blackpool',
  'wycombe wanderers',
  'rotherham united',
  'bradford city',
  'chesterfield',
  'mk dons',
  'notts county',
  'doncaster rovers',
  'gillingham',
  'port vale',
  'carlisle united',
  'walsall',
  'afc wimbledon',
  'tranmere rovers',
  'real madrid',
  'fc barcelona',
  'atlético madrid',
  'athletic club',
  'real sociedad',
  'villarreal',
  'real betis',
  'sevilla',
  'girona',
  'real zaragoza',
  'sporting gijón',
  'levante',
  'real oviedo',
  'deportivo la coruña',
  'elche',
  'granada',
  'cádiz',
  'racing santander',
  'cd tenerife',
  'sd eibar',
  'albacete balompié',
  'mallorca',
  'osasuna',
  'inter milan',
  'juventus',
  'ac milan',
  'napoli',
  'as roma',
  'atalanta',
  'ss lazio',
  'fiorentina',
  'bologna',
  'sampdoria',
  'palermo',
  'sassuolo',
  'frosinone',
  'salernitana',
  'cremonese',
  'spezia',
  'bari',
  'brescia',
  'modena',
  'cesena',
  'pisa',
  'bayern munich',
  'bayer leverkusen',
  'borussia dortmund',
  'rb leipzig',
  'vfb stuttgart',
  'eintracht frankfurt',
  'vfl wolfsburg',
  'sc freiburg',
  'borussia mönchengladbach',
  'hamburger sv',
  'fc schalke 04',
  '1. fc köln',
  'hertha bsc',
  'fortuna düsseldorf',
  'hannover 96',
  '1. fc nürnberg',
  '1. fc kaiserslautern',
  'karlsruher sc',
  'sv darmstadt 98',
  'sc paderborn',
  'paris saint-germain',
  'as monaco',
  'olympique de marseille',
  'olympique lyonnais',
  'losc lille',
  'ogc nice',
  'rc lens',
  'stade rennais',
  'stade brestois',
  'fc metz',
  'fc lorient',
  'sm caen',
  'paris fc',
  'ea guingamp',
  'troyes',
  'ac ajaccio',
  'clermont foot',
  'amiens sc',
  'grenoble foot',
  'fc nantes',
  'toulouse fc',
  'ajax',
  'psv eindhoven',
  'feyenoord',
  'az alkmaar',
  'fc twente',
  'fc utrecht',
  'sl benfica',
  'fc porto',
  'sporting cp',
  'sc braga',
  'vitória de guimarães',
  'fc famalicão',
  'galatasaray',
  'fenerbahçe',
  'beşiktaş',
  'trabzonspor',
  'i̇stanbul başakşehir',
  'samsunspor',
  'adana demirspor',
  'antalyaspor',
  'club brugge',
  'rsc anderlecht',
  'royale union saint-gilloise',
  'krc genk',
  'royal antwerp',
  'kaa gent',
  'standard liège',
  'cercle brugge',
  'celtic',
  'rangers',
  'aberdeen',
  'heart of midlothian',
  'hibernian',
  'kilmarnock',
  'olympiacos',
  'panathinaikos',
  'aek athens',
  'paok thessaloniki',
  'aris thessaloniki',
  'atromitos',
  'ofi crete',
  'zenit saint petersburg',
  'spartak moscow',
  'cska moscow',
  'fc krasnodar',
  'dynamo moscow',
  'lokomotiv moscow',
  'fc rostov',
  'rubin kazan',
  'shakhtar donetsk',
  'dynamo kyiv',
  'kryvbas kryvyi rih',
  'polissya zhytomyr',
  'zorya luhansk',
  'karpaty lviv',
  'red bull salzburg',
  'sk sturm graz',
  'lask',
  'sk rapid wien',
  'fk austria wien',
  'wolfsberger ac',
  'bsc young boys',
  'fc basel',
  'fc zürich',
  'servette fc',
  'fc lugano',
  'fc st. gallen',
  'fc luzern',
  'fc copenhagen',
  'fc midtjylland',
  'brøndby if',
  'fc nordsjælland',
  'agf aarhus',
  'silkeborg if',
  'fk bodø/glimt',
  'molde fk',
  'rosenborg bk',
  'sk brann',
  'viking fk',
  'lillestrøm sk',
  'malmö ff',
  'aik',
  'djurgårdens if',
  'ifk göteborg',
  'bk häcken',
  'if elfsborg',
  'hammarby if',
  'ifk norrköping',
  'legia warsaw',
  'lech poznań',
  'raków częstochowa',
  'jagiellonia białystok',
  'pogoń szczecin',
  'górnik zabrze',
  'śląsk wrocław',
  'cracovia',
  'slavia prague',
  'sparta prague',
  'fc viktoria plzeň',
  'baník ostrava',
  'fk mladá boleslav',
  'fc slovan liberec',
  'sigma olomouc',
  'inter miami cf',
  'columbus crew',
  'los angeles fc',
  'lafc',
  'la galaxy',
  'seattle sounders fc',
  'fc cincinnati',
  'philadelphia union',
  'atlanta united',
  'new york red bulls',
  'new york city fc',
  'houston dynamo',
  'club américa',
  'cruz azul',
  'chivas guadalajara',
  'tigres uanl',
  'cf monterrey',
  'deportivo toluca',
  'cf pachuca',
  'pumas unam',
  'club león',
  'santos laguna',
  'flamengo',
  'palmeiras',
  'atlético mineiro',
  'botafogo',
  'são paulo fc',
  'fluminense',
  'internacional',
  'grêmio',
  'corinthians',
  'cruzeiro',
  'athletico paranaense',
  'fortaleza',
  'bahia',
  'river plate',
  'boca juniors',
  'racing club',
  'independiente',
  'san lorenzo',
  'estudiantes de la plata',
  'vélez sarsfield',
  'rosario central',
  'talleres de córdoba',
  'colo-colo',
  'universidad de chile',
  'universidad católica',
  'unión española',
  'palestino',
  'everton de viña del mar',
  'cobresal',
  'cobreloa',
  'atlético nacional',
  'millonarios fc',
  'américa de cali',
  'junior fc',
  'independiente santa fe',
  'independiente medellín',
  'deportivo cali',
  'deportes tolima',
  'al hilal',
  'al nassr',
  'al ittihad',
  'al ahli',
  'al shabab',
  'al ettifaq',
  'al taawoun',
  'al fateh',
  'mamelodi sundowns',
  'orlando pirates',
  'kaizer chiefs',
  'stellenbosch fc',
  'supersport united',
  'sekhukhune united',
  'cape town city fc',
  'peñarol',
  'nacional',
  'independiente del valle',
  'olimpia',
  'cerro porteño',
  'lanús',
  'defensa y justicia',
  'red bull bragantino',
  'belgrano',
  'ldu quito'
];

function isBigGame(homeTeam, awayTeam) {
  const h = (homeTeam || '').toLowerCase();
  const a = (awayTeam || '').toLowerCase();
  return BIG_TEAMS.some(t => h.includes(t)) && BIG_TEAMS.some(t => a.includes(t));
}

function parseFormStr(formStr) {
  if (!formStr || typeof formStr !== 'string') return 50; 
  const clean = formStr.toUpperCase().replace(/[^WDL]/g, '');
  if (clean.length === 0) return 50;
  
  let pts = 0;
  for (const char of clean) {
    if (char === 'W') pts += 3;
    else if (char === 'D') pts += 1;
    else if (char === 'L') pts -= 1; // Penalize losses
  }
  
  // Calculate percentage and ensure it doesn't drop below 0%
  const percentage = Math.round((pts / (clean.length * 3)) * 100);
  return Math.max(0, percentage);
}

function parseH2HStr(summaryData, homeTeam, awayTeam) {
  if (!summaryData || !summaryData.seasonseries || summaryData.seasonseries.length === 0) return null;
  
  // Extract string from seasonseries
  const series = summaryData.seasonseries[0];
  const summaryStr = series.summary || '';
  if (!summaryStr) return null;

  let hWins = 0, aWins = 0, draws = 0;
  const cleanH2H = summaryStr.replace(/\s*\([\d\-,\s]+\)/g, '');

  const wonMatches = [...cleanH2H.matchAll(/([A-Za-z0-9\s\.\-]+?)\s+won\s+(\d+)/gi)];
  for (const match of wonMatches) {
    const tName = (match[1] || '').trim().toLowerCase();
    const count = parseInt(match[2] || '0', 10);
    const homeClean = (homeTeam || '').toLowerCase();
    const awayClean = (awayTeam || '').toLowerCase();
    
    if (tName.includes(homeClean) || homeClean.includes(tName)) {
      hWins += count;
    } else if (tName.includes(awayClean) || awayClean.includes(tName)) {
      aWins += count;
    }
  }

  const drawMatch = cleanH2H.match(/(\d+)\s+Draw/i);
  if (drawMatch) {
    draws = parseInt(drawMatch[1] || '0', 10);
  }
  
  const total = hWins + aWins + draws;
  if (total === 0) return null;
  
  return {
    h: (hWins / total) * 100,
    d: (draws / total) * 100,
    a: (aWins / total) * 100,
    summaryStr: cleanH2H
  };
}

// ─── Prediction engine ────────────────────────────────────────────────────────
function makePrediction(home, away, hOdds, dOdds, aOdds, league, homeFormStr, awayFormStr, summaryData) {
  const hasOdds = hOdds > 0 && aOdds > 0;
  
  // 1. Odds (40% or 50%)
  let oddsHp = 45, oddsDp = 25, oddsAp = 30;
  if (hasOdds) {
    const rawH = 1 / hOdds;
    const rawD = dOdds ? 1 / dOdds : (1 - rawH - (1 / aOdds) > 0 ? 1 - rawH - (1 / aOdds) : 0.25);
    const rawA = 1 / aOdds;
    const total = rawH + rawD + rawA;
    oddsHp = (rawH / total) * 100;
    oddsDp = (rawD / total) * 100;
    oddsAp = (rawA / total) * 100;
  }
  
  // 2. Form (30% or 40%)
  const hForm = parseFormStr(homeFormStr);
  const aForm = parseFormStr(awayFormStr);
  let formHp = 38, formDp = 24, formAp = 38;
  if (hForm !== 50 || aForm !== 50) {
    const totalF = hForm + aForm;
    if (totalF > 0) {
      formHp = (hForm / totalF) * 100;
      formAp = (aForm / totalF) * 100;
      const gap = Math.abs(formHp - formAp);
      formDp = Math.max(5, 30 - gap); 
      const fTotal = formHp + formAp + formDp;
      formHp = (formHp / fTotal) * 100;
      formAp = (formAp / fTotal) * 100;
      formDp = (formDp / fTotal) * 100;
    }
  }

  // 3. H2H (20% or 0%)
  const h2h = parseH2HStr(summaryData, home, away);
  const hasH2H = h2h !== null;
  
  // 4. Weights
  const isUCL = (league || '').toLowerCase().includes('champions league') || (league || '').toLowerCase().includes('europa');
  
  const wOdds = hasH2H ? 0.45 : 0.55;
  const wForm = hasH2H ? 0.30 : 0.40;
  const wH2H  = hasH2H ? 0.20 : 0.00;
  const wHome = 0.05;
  
  // Home Adv (5%)
  const homeAdvHp = 60, homeAdvDp = 20, homeAdvAp = 20;
  
  // Final Probabilities
  let fHp = (oddsHp * wOdds) + (formHp * wForm) + (hasH2H ? h2h.h * wH2H : 0) + (homeAdvHp * wHome);
  let fDp = (oddsDp * wOdds) + (formDp * wForm) + (hasH2H ? h2h.d * wH2H : 0) + (homeAdvDp * wHome);
  let fAp = (oddsAp * wOdds) + (formAp * wForm) + (hasH2H ? h2h.a * wH2H : 0) + (homeAdvAp * wHome);
  
  const fTotal = fHp + fDp + fAp;
  fHp = Math.round((fHp / fTotal) * 100);
  fDp = Math.round((fDp / fTotal) * 100);
  fAp = Math.round((fAp / fTotal) * 100);

  // Decision logic
  const isBig = isBigGame(home, away);
  const maxProb = Math.max(fHp, fDp, fAp);
  const isHomeFav = fHp > fAp || (Math.abs(fHp - fAp) <= 3.0 && hForm >= aForm);
  const fav = isHomeFav ? home : away;
  const favOdds = isHomeFav ? hOdds : aOdds;

  const formGap = Math.abs(hForm - aForm);
  const isFormFav = formGap >= 25 || hForm >= 60 || aForm >= 60;
  const formFav = hForm >= aForm ? home : away;
  const isHomeFormFav = hForm >= aForm;
  
  let recommendation = '';
  let primarySafe = '';
  let strategyAnalysis = '';
  
  if (maxProb >= 60) {
    if (fHp >= 60) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
    } else {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
    }
    strategyAnalysis = `Clear Favorite (Prob >= 60%): Direct Win.`;
  } else if (isBig) {
    recommendation = `Over 1.5 Goals`;
    primarySafe = `Safe: Over 1.5 Goals`;
    strategyAnalysis = `Big Game + Tight Match: Expecting goals (Over 1.5).`;
  } else if (maxProb >= 55) {
    if (isHomeFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
    } else {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
    }
    strategyAnalysis = `Moderate Favorite (Prob 55-59%): Direct Win.`;
  } else {
    recommendation = `Over 1.5 Goals`;
    primarySafe = `Safe: Over 1.5 Goals`;
    strategyAnalysis = `Not Big Teams & Tight: Goals Market (Over 1.5).`;
  }
  
  const dnbOdds = favOdds ? Math.max(1.30, parseFloat((favOdds * 0.82).toFixed(2))) : 1.70;
  const stakingOptions = [
    primarySafe,
    `Value: ${fav} Draw No Bet (${dnbOdds})`,
    (isBig && maxProb < 55) ? `Goals: Over 1.5 Total Goals (1.30)` : `Risky: ${fav} to WIN by 2+ Goals (2.85)`,
    `BTTS: Both Teams To Score - Yes (1.78)`,
    maxProb < 45 ? `Alternative: Under 2.5 Goals (1.80)` : `Alternative: Over 2.5 Total Goals (1.70)`
  ];
  
  const aiRating = Math.round(fAp - fHp);

  return {
    homeWinProbability: fHp,
    drawProbability: fDp,
    awayWinProbability: fAp,
    oddsRating: aiRating,
    h2hSummary: hasH2H ? h2h.summaryStr : null,
    recommendation,
    analysis: `${strategyAnalysis}\nHomeForm: ${hForm}%, AwayForm: ${aForm}%, BigGame: ${isBig}`,
    stakingOptions
  };
}

// ─── Fetch ESPN fixtures for a single league slug and date string ──────────────
async function fetchEspnLeagueFixtures(slug, dateStr) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${slug}/scoreboard?dates=${dateStr}&limit=100`;
  const res = await safeFetch(url, 1);
  if (!res) return [];
  try {
    const data = await res.json();
    if (!data.events) return [];
    
    // Process sequentially with a 1-second delay to avoid rate limiting
    for (const ev of data.events) {
      await new Promise(r => setTimeout(r, 1000));
      const summary = await fetchEspnSummary(slug, ev.id);
      if (summary) {
        ev.summaryData = summary;
      }
    }
    return data.events;
  } catch {
    return [];
  }
}

// ─── Fetch ESPN summary for detailed lineups ───────────────────────────────────
async function fetchEspnSummary(leagueSlug, eventId) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${leagueSlug}/summary?event=${eventId}`;
  const res = await safeFetch(url, 1);
  if (!res) return null;
  try {
    const data = await res.json();
    return data;
  } catch {
    return null;
  }
}

// ─── Parse a single ESPN event into our match schema ─────────────────────────
function parseEspnEvent(ev, leagueLabel, leagueSlug) {
  const comp = ev.competitions?.[0];
  if (!comp) return null;

  const homeComp = comp.competitors?.find(c => c.homeAway === 'home');
  const awayComp = comp.competitors?.find(c => c.homeAway === 'away');
  if (!homeComp || !awayComp) return null;

  // Scores
  const homeScore = (homeComp.score !== undefined && homeComp.score !== null && homeComp.score !== '')
    ? parseInt(homeComp.score, 10) : null;
  const awayScore = (awayComp.score !== undefined && awayComp.score !== null && awayComp.score !== '')
    ? parseInt(awayComp.score, 10) : null;

  // Status
  const statusType = ev.status?.type || {};
  const state = statusType.state || 'pre';
  const completed = statusType.completed || state === 'post';
  const live = state === 'in';
  const statusShort = completed ? (statusType.shortDetail || 'FT') : (live ? (statusType.shortDetail || 'LIVE') : 'NS');
  const status = completed ? 'finished' : (live ? 'live' : 'notStarted');

  // Odds
  const oddsObj = comp.odds?.[0];
  let hOdds = null, dOdds = null, aOdds = null;
  if (oddsObj) {
    hOdds = amToDec(oddsObj.homeTeamOdds?.moneyLine ?? oddsObj.moneyline?.home?.close?.odds);
    dOdds = amToDec(oddsObj.drawOdds?.moneyLine ?? oddsObj.moneyline?.draw?.close?.odds);
    aOdds = amToDec(oddsObj.awayTeamOdds?.moneyLine ?? oddsObj.moneyline?.away?.close?.odds);
  }

  const homeTeam = homeComp.team?.displayName || homeComp.team?.name || '';
  const awayTeam = awayComp.team?.displayName || awayComp.team?.name || '';
  if (!homeTeam || !awayTeam) return null;

  const id = `${homeTeam}-${awayTeam}`.replace(/\s+/g, '-');

  // Form & Records (Points Calculation)
  const homeForm = homeComp.form || '';
  const awayForm = awayComp.form || '';
  
  const parsePoints = (records) => {
    if (!records || !records[0] || !records[0].summary) return 0;
    const parts = records[0].summary.split('-'); // e.g. "1-3-0" for W-D-L
    if (parts.length === 3) {
      const w = parseInt(parts[0], 10) || 0;
      const d = parseInt(parts[1], 10) || 0;
      return (w * 3) + (d * 1);
    }
    return 0;
  };

  const homePoints = parsePoints(homeComp.records);
  const awayPoints = parsePoints(awayComp.records);

  // AI Prediction & Rating logic
  const ai = makePrediction(homeTeam, awayTeam, hOdds, dOdds, aOdds, leagueLabel, homeForm, awayForm, ev.summaryData);

  // Parse Lineups
  let homeLineup = [];
  let awayLineup = [];
  if (ev.summaryData && ev.summaryData.rosters) {
    const homeRoster = ev.summaryData.rosters.find(r => r.homeAway === 'home');
    const awayRoster = ev.summaryData.rosters.find(r => r.homeAway === 'away');
    
    if (homeRoster && homeRoster.roster) {
      homeLineup = homeRoster.roster.map(p => `${p.athlete?.displayName || 'Unknown'} (${p.position?.name || 'Unknown'})`);
    }
    if (awayRoster && awayRoster.roster) {
      awayLineup = awayRoster.roster.map(p => `${p.athlete?.displayName || 'Unknown'} (${p.position?.name || 'Unknown'})`);
    }
  }

  return {
    id,
    espnEventId: ev.id,
    homeTeam,
    awayTeam,
    homeLogo: homeComp.team?.logo || '',
    awayLogo: awayComp.team?.logo || '',
    league: leagueLabel,
    date: ev.date || new Date().toISOString(),
    status,
    statusShort,
    homeScore: homeScore ?? 0,
    awayScore: awayScore ?? 0,
    homeOdds: hOdds,
    drawOdds: dOdds,
    awayOdds: aOdds,
    oddsRating: ai.oddsRating,
    espnLeagueSlug: leagueSlug, // Internal use
    homeRank: null,
    awayRank: null,
    homeForm,
    awayForm,
    homePoints,
    awayPoints,
    homeLineup: homeLineup.length ? homeLineup : null,
    awayLineup: awayLineup.length ? awayLineup : null,
    h2hSummary: ai.h2hSummary,
    matchUrl: null,
    prediction: {
      homeWinProbability: ai.homeWinProbability,
      drawProbability: ai.drawProbability,
      awayWinProbability: ai.awayWinProbability,
      recommendation: ai.recommendation,
      analysis: ai.analysis,
      stakingOptions: ai.stakingOptions
    }
  };
}

// ─── Fetch all fixtures from ESPN for yesterday + today + tomorrow ─────────────
async function fetchAllEspnFixtures() {
  const now = new Date();
  const dates = [
    espnDate(new Date(now.getTime() - 86400000)), // yesterday
    espnDate(now),                                // today
    espnDate(new Date(now.getTime() + 86400000)), // tomorrow
    espnDate(new Date(now.getTime() + 2 * 86400000)), // day after
    espnDate(new Date(now.getTime() + 3 * 86400000)), // 3 days ahead
    espnDate(new Date(now.getTime() + 4 * 86400000)), // 4 days ahead
    espnDate(new Date(now.getTime() + 5 * 86400000)), // 5 days ahead
    espnDate(new Date(now.getTime() + 6 * 86400000)), // 6 days ahead
  ];

  const matchesMap = new Map();
  let totalFetched = 0;

  for (const league of ESPN_LEAGUES) {
    if (isExcludedLeague(league.label)) continue;

    // Fetch fixtures for all dates in parallel per league
    const allEvents = (await Promise.all(
      dates.map(d => fetchEspnLeagueFixtures(league.slug, d))
    )).flat();

    for (const ev of allEvents) {
      if (isExcludedLeague(ev.name || '')) continue;

      const match = parseEspnEvent(ev, league.label, league.slug);
      if (!match) continue;

      // Avoid duplicates - prefer richer record (with odds) if conflict
      if (matchesMap.has(match.id)) {
        const existing = matchesMap.get(match.id);
        if (!existing.homeOdds && match.homeOdds) {
          matchesMap.set(match.id, match);
        }
        continue;
      }

      matchesMap.set(match.id, match);
      totalFetched++;
    }

    await sleep(50); // gentle throttle between leagues
  }

  console.log(`  ESPN: fetched ${totalFetched} unique matches across ${ESPN_LEAGUES.length} leagues`);
  return Array.from(matchesMap.values());
}

// ─── Cloudflare KV Helpers ────────────────────────────────────────────────────
async function getCloudflareKV() {
  if (!CF_ACCOUNT_ID || !CF_API_TOKEN || !CF_KV_NS_ID) return null;
  const url = `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${CF_KV_NS_ID}/values/${KV_KEY}`;
  try {
    const res = await fetch(url, { headers: { 'Authorization': `Bearer ${CF_API_TOKEN}` } });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

async function pushToCloudflareKV(data) {
  if (!CF_ACCOUNT_ID || !CF_API_TOKEN || !CF_KV_NS_ID) {
    console.log('Skipping CF KV push (missing credentials).');
    return;
  }
  const url = `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${CF_KV_NS_ID}/values/${KV_KEY}`;
  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'Authorization': `Bearer ${CF_API_TOKEN}`, 'Content-Type': 'application/json' },
    body: data
  });
  const json = await res.json();
  if (!json.success) throw new Error(`KV write failed: ${JSON.stringify(json.errors)}`);
  console.log('  Pushed to Cloudflare KV successfully');
}

// ─── Telegram Broadcasting ────────────────────────────────────────────────────
async function postPickOfTheDayToTelegram(matches) {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    console.log('Skipping Telegram: Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID');
    return;
  }
  
  const todayStr = new Date().toISOString().slice(0, 10);
  const todaysMatches = matches.filter(m => m.date.startsWith(todayStr) && m.prediction);
  
  if (todaysMatches.length === 0) {
    console.log('No matches today to post to Telegram.');
    return;
  }

  // Find the most confident pick based on highest absolute oddsRating
  todaysMatches.sort((a, b) => Math.abs(b.oddsRating || 0) - Math.abs(a.oddsRating || 0));
  const bestMatch = todaysMatches[0];

  const safeOption = bestMatch.prediction.stakingOptions?.find(o => o.risk === 'Safe')?.pick || bestMatch.prediction.recommendation;
  const time = new Date(bestMatch.date).toLocaleTimeString('en-US', { hour: '2-digit', minute:'2-digit', timeZone: 'UTC' }) + ' UTC';

  const msg = `🏆 *PICK OF THE DAY* 🏆\n\n` +
              `⚽ *${bestMatch.homeTeam} vs ${bestMatch.awayTeam}*\n` +
              `🌍 ${bestMatch.league}\n` +
              `⏰ ${time}\n\n` +
              `💡 *AI Prediction:* ${bestMatch.prediction.recommendation}\n` +
              `🛡️ *Safe Option:* ${safeOption}\n\n` +
              `📲 _Get all our daily picks inside the app!_`;

  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: msg, parse_mode: 'Markdown' })
    });
    const result = await res.json();
    if (!result.ok) {
      console.error('Telegram API error:', result.description);
    } else {
      console.log('✅ Successfully posted Pick of the Day to Telegram!');
      return bestMatch;
    }
  } catch (e) {
    console.error('Error posting to Telegram:', e.message);
  }
  return null;
}

function evaluatePrediction(rec, hScore, aScore, hTeam, aTeam) {
  const h = parseInt(hScore);
  const a = parseInt(aScore);
  if (isNaN(h) || isNaN(a)) return 'PENDING';
  
  if (rec.includes('to Win (1)')) return h > a ? 'WON' : 'LOST';
  if (rec.includes('to Win (2)')) return a > h ? 'WON' : 'LOST';
  if (rec.includes('or Draw (Double Chance)')) {
    if (rec.includes(hTeam)) return h >= a ? 'WON' : 'LOST';
    if (rec.includes(aTeam)) return a >= h ? 'WON' : 'LOST';
  }
  if (rec.includes('Over 0.5 Goals')) {
    const total = h + a;
    if (total > 0) return 'WON';
    return 'LOST';
  }
  return 'UNKNOWN';
}

async function checkAndPostMatchResult(activePick, matches) {
  if (!activePick || !TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) return false;
  
  // Find the match in freshly scraped data
  const match = matches.find(m => m.id === activePick.id);
  if (!match || match.status !== 'FT') return false; // Not finished yet

  const hScore = match.homeScore;
  const aScore = match.awayScore;
  const result = evaluatePrediction(activePick.prediction.recommendation, hScore, aScore, match.homeTeam, match.awayTeam);
  
  const msg = `🚨 *FULL TIME RESULT* 🚨\n\n` +
              `⚽ *${match.homeTeam} ${hScore} - ${aScore} ${match.awayTeam}*\n\n` +
              `💡 *Our Pick:* ${activePick.prediction.recommendation}\n` +
              `${result === 'WON' ? '✅ *RESULT: WON*' : '❌ *RESULT: LOST*'}\n\n` +
              `📲 _Check the app for tomorrow's predictions!_`;

  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: msg, parse_mode: 'Markdown' })
    });
    if (res.ok) {
      console.log(`✅ Successfully posted Result for ${match.homeTeam} vs ${match.awayTeam} to Telegram!`);
      return true; // Indicates we should clear activePick
    }
  } catch (e) {
    console.error('Error posting result to Telegram:', e.message);
  }
  return false;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('Starting ESPN-only scraper...');

  // 0. Load existing KV data so we can preserve predictions
  console.log('Loading existing matches from KV to preserve predictions...');
  const currentKvData = await getCloudflareKV();
  const existingMatchesMap = new Map();
  if (currentKvData && currentKvData.matchesData && currentKvData.matchesData.matches) {
    for (const m of currentKvData.matchesData.matches) {
      existingMatchesMap.set(m.id, m);
    }
  }

  console.log(`Fetching fixtures for yesterday → +6 days from ESPN...`);

  const matches = await fetchAllEspnFixtures();
  const leagues = new Set(matches.map(m => m.league));

  console.log(`\nTotal: ${matches.length} matches across ${leagues.size} leagues`);
  const dates = [...new Set(matches.map(m => m.date.substring(0, 10)))].sort();
  console.log('Dates included:', dates.join(', '));

  // 2. Fetch Lineups for Yesterday's, Today's and Live Matches
  console.log('\nFetching lineups for matches happening yesterday, today or live...');
  const today = new Date();
  const todayStr = today.toISOString().slice(0, 10);
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().slice(0, 10);
  const matchesToEnrich = matches.filter(m => m.date.startsWith(todayStr) || m.date.startsWith(yesterdayStr) || m.status === 'live');
  
  // Process in small batches to avoid spamming the API
  const batchSize = 10;
  for (let i = 0; i < matchesToEnrich.length; i += batchSize) {
    const batch = matchesToEnrich.slice(i, i + batchSize);
    await Promise.all(batch.map(async (m) => {
      const summary = await fetchEspnSummary(m.espnLeagueSlug, m.espnEventId);
      if (!summary) return;

      // -- Parse Lineups (only if rosters are available) ----------------------
      if (summary.rosters && summary.rosters.length >= 2) {
        const parseLineup = (rosterObj) => {
          if (!rosterObj || !rosterObj.roster) return null;
          const startingXI = [];
          const bench = [];
          rosterObj.roster.forEach(p => {
            const player = {
              number: p.athlete?.jersey || '?',
              name: p.athlete?.displayName || 'Unknown',
              position: p.position?.abbreviation || 'N/A',
              rating: 0,
              stats: ''
            };
            if (p.starter) startingXI.push(player);
            else bench.push(player);
          });
          return { avgRating: 0, startingXI, bench };
        };
        const r1 = summary.rosters[0];
        const r2 = summary.rosters[1];
        const r1IsHome = r1.homeAway === 'home';
        m.homeLineup = parseLineup(r1IsHome ? r1 : r2);
        m.awayLineup = parseLineup(r1IsHome ? r2 : r1);
      }

      // -- Parse Real H2H from ESPN seasonseries --------------------------------
      // ESPN structure: seasonseries[0].events[] each with competitions[0].competitors[]
      const seriesList = summary.seasonseries;
      if (Array.isArray(seriesList) && seriesList.length > 0) {
        const h2hEvents = seriesList[0].events || [];
        let hWins = 0, aWins = 0, draws = 0;
        const recentResults = [];

        for (const event of h2hEvents) {
          const comps = event.competitions?.[0];
          if (!comps) continue;
          const homeComp = comps.competitors?.find(c => c.homeAway === 'home');
          const awayComp = comps.competitors?.find(c => c.homeAway === 'away');
          if (!homeComp || !awayComp) continue;

          const hScore = parseInt(homeComp.score, 10);
          const aScore = parseInt(awayComp.score, 10);
          const hName = homeComp.team?.displayName || homeComp.team?.name || '';
          const dateStr = event.date ? event.date.slice(0, 10) : '';

          // Map to our match home/away perspective
          const isOurHome = hName.toLowerCase().includes(m.homeTeam.toLowerCase()) ||
                            m.homeTeam.toLowerCase().includes(hName.toLowerCase());

          const ourHomeScore = isOurHome ? hScore : aScore;
          const ourAwayScore = isOurHome ? aScore : hScore;

          if (ourHomeScore > ourAwayScore) hWins++;
          else if (ourAwayScore > ourHomeScore) aWins++;
          else draws++;

          recentResults.push(`${m.homeTeam} ${ourHomeScore}-${ourAwayScore} ${m.awayTeam} (${dateStr})`);
        }

        if (hWins + aWins + draws > 0) {
          const total = hWins + aWins + draws;
          const parts = [];
          if (hWins > 0) parts.push(`${m.homeTeam} won ${hWins}`);
          if (aWins > 0) parts.push(`${m.awayTeam} won ${aWins}`);
          if (draws > 0) parts.push(`${draws} Draw${draws > 1 ? 's' : ''}`);
          m.h2hSummary = parts.join(', ') + ` of last ${total} meetings. ` +
                         recentResults.slice(0, 5).join(' | ');
        }
      }

      // Re-calculate prediction now that we have H2H data
      m.prediction = makePrediction(m.homeTeam, m.awayTeam, m.homeOdds, m.drawOdds, m.awayOdds, m.league, m.homeForm, m.awayForm, m.h2hSummary);
    }));
  }
  
  // Clean up internal slug before upload
  matches.forEach(m => delete m.espnLeagueSlug);

  // -- Preserve Previous Predictions --
  // Freeze predictions for ALL existing matches so the first prediction is locked in forever
  for (const m of matches) {
    const existing = existingMatchesMap.get(m.id);
    if (existing && existing.prediction) {
      m.prediction = existing.prediction;
      if (existing.homeOdds !== undefined) m.homeOdds = existing.homeOdds;
      if (existing.drawOdds !== undefined) m.drawOdds = existing.drawOdds;
      if (existing.awayOdds !== undefined) m.awayOdds = existing.awayOdds;
      if (existing.oddsRating !== undefined) m.oddsRating = existing.oddsRating;
      if (existing.h2hSummary !== undefined && existing.h2hSummary !== null) m.h2hSummary = existing.h2hSummary;
    }
  }

  // 3. Telegram Broadcast (Once per day) & Result Monitoring
  let lastTelegramPostDate = null;
  let activeTelegramPick = null;
  if (currentKvData) {
    if (currentKvData.lastTelegramPostDate) lastTelegramPostDate = currentKvData.lastTelegramPostDate;
    if (currentKvData.activeTelegramPick) activeTelegramPick = currentKvData.activeTelegramPick;
  }

  // Check if we have an active pick that just finished
  if (activeTelegramPick) {
    const handled = await checkAndPostMatchResult(activeTelegramPick, matches);
    if (handled) {
      activeTelegramPick = null; // Clear it so we don't post result again
    }
  }

  if (lastTelegramPostDate !== todayStr) {
    console.log(`\nNew day detected! Attempting to post Pick of the Day to Telegram...`);
    const postedMatch = await postPickOfTheDayToTelegram(matches);
    if (postedMatch) {
      activeTelegramPick = postedMatch; // Save it to monitor for result
      lastTelegramPostDate = todayStr; // Update flag ONLY on successful post
    }
  } else {
    console.log(`\nTelegram: Already posted today (${todayStr}).`);
  }

  const finalData = JSON.stringify({
    matchesData: {
      lastUpdated: new Date().toISOString(),
      scrapedBy: 'espn-only',
      matches
    },
    standingsData: null,
    lastTelegramPostDate,
    activeTelegramPick
  });

  console.log('\nPushing to Cloudflare KV...');
  await pushToCloudflareKV(finalData);
  console.log(`Done! ${matches.length} matches live in KV.`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
