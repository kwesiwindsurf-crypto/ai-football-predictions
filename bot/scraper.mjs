import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

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
  { slug: 'uefa.champions',        label: 'UEFA - Champions League' },
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
  'argentina',
  'france',
  'spain',
  'england',
  'brazil',
  'belgium',
  'netherlands',
  'portugal',
  'colombia',
  'italy',
  'uruguay',
  'croatia',
  'germany',
  'morocco',
  'switzerland',
  'usa',
  'mexico',
  'japan',
  'senegal',
  'iran',
  'denmark',
  'austria',
  'south korea',
  'australia',
  'ukraine',
  'turkey',
  'poland',
  'sweden',
  'wales',
  'hungary',
  'serbia',
  'peru',
  'qatar',
  'ecuador',
  'egypt',
  'ivory coast',
  'nigeria',
  'scotland',
  'chile',
  'tunisia',
  'panama',
  'algeria',
  'mali',
  'norway',
  'romania',
  'venezuela',
  'slovakia',
  'canada',
  'cameroon',
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
  
// ─── League-Tailored Strategy Engine ──────────────────────────────────────────
// ─── League & Tournament Strategy Engine ──────────────────────────────────────
// Tailors predictions across 62+ world competitions including UCL, Europa, World Cups & Domestic Leagues
function determineLeagueStrategy(league, home, away, fHp, fDp, fAp, isBig, hOdds, aOdds) {
  const lStr = (league || '').toLowerCase();
  const prob1X = fHp + fDp;
  const probX2 = fAp + fDp;
  const maxProb = Math.max(fHp, fDp, fAp);

  // Clear odds evaluation (never let market underdog get picked against heavy favorite)
  const hasOdds = hOdds > 0 && aOdds > 0;
  const isHomeOddsFav = hasOdds ? hOdds < aOdds : fHp > fAp;
  const isAwayOddsFav = hasOdds ? aOdds < hOdds : fAp > fHp;
  const oddsGap = hasOdds ? Math.abs(hOdds - aOdds) : 0;
  const isOddsClose = hasOdds ? oddsGap <= 0.40 : Math.abs(fHp - fAp) <= 8;

  // Symmetrical Favorite & Edge Determination
  // If Away probability is noticeably higher OR Away odds are much shorter, Away is the true favorite.
  const isAwayFav = (hasOdds && aOdds < hOdds && aOdds <= 2.20) || (fAp >= fHp + 5);
  const isHomeFav = (hasOdds && hOdds < aOdds && hOdds <= 2.20) || (fHp >= fAp + 5);

  // 1. UEFA Champions League
  const isUCL = lStr.includes('champions league') || lStr.includes('uefa.champions');

  // 2. UEFA Europa League & Conference League
  const isEuroCups = lStr.includes('europa') || lStr.includes('conference');

  // 3. South American Continental (Libertadores / Sudamericana)
  const isSouthAmericanCups = lStr.includes('libertadores') || lStr.includes('sudamericana');

  // 4. International Tournaments (World Cup, Euros, AFCON, Copa America, Nations League)
  const isInternational = lStr.includes('fifa') || lStr.includes('world cup') ||
    lStr.includes('nations league') || lStr.includes('euro') ||
    lStr.includes('copa america') || lStr.includes('gold cup') ||
    lStr.includes('africa cup') || lStr.includes('caf.nations') ||
    lStr.includes('asian cup');

  // 5. Domestic Knockout Cups (FA Cup, Copa del Rey, DFB Pokal, Coppa Italia, etc.)
  const isDomesticCup = lStr.includes('cup') || lStr.includes('pokal') ||
    lStr.includes('copa del rey') || lStr.includes('coppa italia') ||
    lStr.includes('coupe de france') || lStr.includes('beker') ||
    lStr.includes('taca de portugal');

  // 6. High-Goal Shootout Leagues (Avg > 3.2 goals, Over 1.5 hits in 89-100%)
  const isHighScoring = lStr.includes('eredivisie') || lStr.includes('keuken') ||
    lStr.includes('austria') || lStr.includes('premiership') ||
    lStr.includes('eliteserien') || lStr.includes('allsvenskan') ||
    lStr.includes('superliga') || lStr.includes('pro league') ||
    lStr.includes('ligue 1') || lStr.includes('ligue 2') ||
    lStr.includes('bundesliga') || lStr.includes('switzerland');

  // 7. Defensive / Low-Scoring Grinds (Avg 1.4 - 2.2 goals, Under 3.5 hits 80-100%)
  const isDefensive = lStr.includes('brazil') || lStr.includes('série a') || lStr.includes('serie a - brazil') ||
    lStr.includes('la liga') || lStr.includes('segunda') ||
    lStr.includes('argentina') || lStr.includes('chile') || lStr.includes('colombia') ||
    lStr.includes('afc champions league two') || lStr.includes('greece') || lStr.includes('russia') ||
    lStr.includes('ukraine') || lStr.includes('south africa') || lStr.includes('peru') ||
    lStr.includes('bolivia') || lStr.includes('paraguay') || lStr.includes('uruguay');

  // 8. High-Draw Parity Traps (Draws occur in 35-50% of matches!)
  const isHighDraw = lStr.includes('mls') || lStr.includes('serie b') ||
    lStr.includes('liga mx') || lStr.includes('championship') ||
    lStr.includes('ekstraklasa') || lStr.includes('first league - czech');

  // 9. Home Fortresses (Home wins/draws in 75-88% of matches)
  const isHomeFortress = lStr.includes('süper lig') || lStr.includes('super lig') ||
    lStr.includes('league one') || lStr.includes('league two') ||
    lStr.includes('2. bundesliga') || lStr.includes('pro league - saudi') ||
    lStr.includes('saudi') || lStr.includes('primeira liga') ||
    lStr.includes('serie a');

  let recommendation = '';
  let primarySafe = '';
  let strategyAnalysis = '';

  // ── 0. BLOCKBUSTER CLASHES (Big vs Big across any league or tournament) ──
  if (isBig) {
    if (isOddsClose) {
      if (isDefensive || isSouthAmericanCups) {
        recommendation = `Under 3.5 Goals`;
        primarySafe = `Safe: Under 3.5 Goals`;
        strategyAnalysis = `Blockbuster Derby (${league}): Heavyweight clash with close odds. Defensive buffer (Under 3.5).`;
      } else {
        recommendation = `Over 1.5 Goals`;
        primarySafe = `Safe: Over 1.5 Goals`;
        strategyAnalysis = `Blockbuster Clash (${league}): Evenly matched titans, goals market is the winning pick (Over 1.5).`;
      }
    } else if (isAwayOddsFav && (aOdds < hOdds - 0.20 || fAp > fHp + 5)) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Blockbuster Clash (${league}): Market odds favor away giant ${away} (X2 Double Chance - No blind home bias).`;
    } else {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Blockbuster Clash (${league}): Market odds favor home giant ${home} (1X Double Chance).`;
    }
  }

  // ── 1. SPECIALIZED TOURNAMENT LOGIC ──
  else if (isUCL || isEuroCups) {
    if (fHp >= 65 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `European Cup: Heavy Home Favorite (${fHp}% Win).`;
    } else if (fAp >= 60 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `European Cup: Dominant Away Giant (${fAp}% Win).`;
    } else if (isAwayFav && probX2 >= 65) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `European Cup: Compound X2 Advantage for Away Quality (${probX2}%).`;
    } else if (isHomeFav && prob1X >= 65) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `European Cup: Compound 1X Advantage for Home (${prob1X}%).`;
    } else {
      recommendation = `Over 1.5 Goals`;
      primarySafe = `Safe: Over 1.5 Goals`;
      strategyAnalysis = `European Cup Strategy: Open Goals Market (Over 1.5).`;
    }
  }

  // ── 2. SOUTH AMERICAN CONTINENTAL & INTERNATIONAL TOURNAMENTS ──
  else if (isSouthAmericanCups || isInternational) {
    if (fHp >= 65 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `International/Continental: Strong Host Advantage (${fHp}%).`;
    } else if (fAp >= 60 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `International/Continental: Superior Away Giant (${fAp}%).`;
    } else if (isAwayFav && probX2 >= 64) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `International/Continental: Compound X2 Coverage (${probX2}%).`;
    } else if (isHomeFav && prob1X >= 64) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `International/Continental: Compound 1X Coverage (${prob1X}%).`;
    } else {
      recommendation = `Under 3.5 Goals`;
      primarySafe = `Safe: Under 3.5 Goals`;
      strategyAnalysis = `Tournament Strategy: Cautious Knockout Context (Under 3.5).`;
    }
  }

  // ── 3. DOMESTIC KNOCKOUT CUPS ──
  else if (isDomesticCup) {
    if (fHp >= 70 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Domestic Cup: Overwhelming Home Giant (Prob >= 70%).`;
    } else if (fAp >= 65 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Domestic Cup: Quality Away Giant (Prob >= 65%).`;
    } else if (isAwayFav && probX2 >= 65) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Domestic Cup Strategy: Away Double Chance (X2 ${probX2}%).`;
    } else if (isHomeFav && prob1X >= 65) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Domestic Cup Strategy: 1X Upset Shield (${prob1X}%).`;
    } else {
      recommendation = `Over 1.5 Goals`;
      primarySafe = `Safe: Over 1.5 Goals`;
      strategyAnalysis = `Domestic Cup Strategy: Open Knockout Action (Over 1.5).`;
    }
  }

  // ── 4. DEFENSIVE LEAGUES ──
  else if (isDefensive) {
    if (fHp >= 65 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Defensive League: Heavy Home Dominance (${fHp}%).`;
    } else if (fAp >= 60 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Defensive League: Heavy Away Dominance (${fAp}%).`;
    } else if (isAwayFav && probX2 >= 65) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Defensive League: Away Double Chance (X2 ${probX2}%).`;
    } else if (isHomeFav && prob1X >= 65) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Defensive League: Home Double Chance (1X ${prob1X}%).`;
    } else {
      recommendation = `Under 3.5 Goals`;
      primarySafe = `Safe: Under 3.5 Goals`;
      strategyAnalysis = `Defensive League Strategy: High-confidence Under 3.5 Goals.`;
    }
  }

  // ── 5. HIGH-DRAW LEAGUES ──
  else if (isHighDraw) {
    if (fHp >= 70 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `High-Draw League: Overwhelming Home Favorite (${fHp}%).`;
    } else if (fAp >= 65 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `High-Draw League: Overwhelming Away Favorite (${fAp}%).`;
    } else if (isAwayFav && probX2 >= 62) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `High-Draw League: Away Compound Shield (X2 covers draw ${fDp}%).`;
    } else if (isHomeFav && prob1X >= 62) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `High-Draw League: Home Compound Shield (1X covers draw ${fDp}%).`;
    } else {
      recommendation = `Over 1.5 Goals`;
      primarySafe = `Safe: Over 1.5 Goals`;
      strategyAnalysis = `High-Draw League Strategy: Tight match goals market.`;
    }
  }

  // ── 6. HOME FORTRESS LEAGUES (Turkey, Saudi, 2. Bundesliga, etc.) ──
  // CRITICAL: Never blindly give 1X to underdogs when an Away giant visits (e.g. Al Nassr)
  else if (isHomeFortress) {
    if (fHp >= 55 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Home Fortress League: Dominant Host (${fHp}% Win).`;
    } else if (isAwayFav) {
      if (fAp >= 58 || (hasOdds && aOdds <= 1.50)) {
        recommendation = `${away} to Win (2)`;
        primarySafe = `Safe: X2 (${away} or Draw)`;
        strategyAnalysis = `Home Fortress League: Dominant Away Giant overcomes fortress (${away} ${fAp}% Win).`;
      } else {
        recommendation = `X2 (${away} or Draw)`;
        primarySafe = `Safe: X2 (${away} or Draw)`;
        strategyAnalysis = `Home Fortress League: Away Favorite Double Chance (X2 ${probX2}%).`;
      }
    } else if (prob1X >= 64) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Home Fortress League: 1X Home Shield (${prob1X}% Win/Draw).`;
    } else {
      recommendation = `Over 1.5 Goals`;
      primarySafe = `Safe: Over 1.5 Goals`;
      strategyAnalysis = `Home Fortress League: Competitive tie goals market.`;
    }
  }

  // ── 7. HIGH-SCORING LEAGUES ──
  else if (isHighScoring) {
    if (fHp >= 65 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Goal-Fest League: Dominant Home Team (${fHp}%).`;
    } else if (fAp >= 60 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Goal-Fest League: Dominant Away Team (${fAp}%).`;
    } else {
      recommendation = `Over 1.5 Goals`;
      primarySafe = `Safe: Over 1.5 Goals`;
      strategyAnalysis = `Goal-Fest League Strategy: Reliable Over 1.5 Goals.`;
    }
  }

  // ── 8. UNIVERSAL BASELINE ──
  else {
    if (fHp >= 65 && !isAwayFav) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Clear Home Favorite (${fHp}%): Direct Win.`;
    } else if (fAp >= 60 && !isHomeFav) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Clear Away Favorite (${fAp}%): Direct Win.`;
    } else if (isAwayFav && probX2 >= 64) {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Away Compound Edge (X2 ${probX2}%): Covered.`;
    } else if (isHomeFav && prob1X >= 64) {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Home Compound Edge (1X ${prob1X}%): Covered.`;
    } else if (maxProb >= 42) {
      recommendation = `Over 1.5 Goals`;
      primarySafe = `Safe: Over 1.5 Goals`;
      strategyAnalysis = `Competitive Match: Goals Market (Over 1.5).`;
    } else {
      recommendation = `Under 3.5 Goals`;
      primarySafe = `Safe: Under 3.5 Goals`;
      strategyAnalysis = `Balanced Contest: Low-risk Under 3.5 Goals.`;
    }
  }

  // ── ANTI-CONTRADICTION FINAL SANITY GUARD ──
  // Mathematically impossible for a 1/1X pick to stand if Away has overwhelming odds/probability advantage, and vice versa!
  if (isAwayFav && (recommendation.includes(home) || recommendation.startsWith('1'))) {
    if (fAp >= 58 || (hasOdds && aOdds <= 1.50)) {
      recommendation = `${away} to Win (2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Corrected Alignment: Away Giant Favoritism (${away} ${fAp}% vs ${home} ${fHp}%).`;
    } else {
      recommendation = `X2 (${away} or Draw)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Corrected Alignment: Away Compound Edge (X2 ${probX2}%).`;
    }
  } else if (isHomeFav && (recommendation.includes(away) || recommendation.startsWith('2'))) {
    if (fHp >= 58 || (hasOdds && hOdds <= 1.50)) {
      recommendation = `${home} to Win (1)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Corrected Alignment: Home Favorite Favoritism (${home} ${fHp}% vs ${away} ${fAp}%).`;
    } else {
      recommendation = `1X (${home} or Draw)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Corrected Alignment: Home Compound Edge (1X ${prob1X}%).`;
    }
  }

  return { recommendation, primarySafe, strategyAnalysis };
}

  // Decision logic via League-Tailored Strategy Engine
  const { recommendation, primarySafe, strategyAnalysis } = determineLeagueStrategy(
    league, home, away, fHp, fDp, fAp, isBig, hOdds, aOdds
  );
  
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

  // Status
  const statusType = ev.status?.type || {};
  const state = statusType.state || 'pre';
  const statusName = (statusType.name || '').toUpperCase();
  const statusDetail = (statusType.detail || statusType.description || '').toLowerCase();
  const statusShortRaw = (statusType.shortDetail || '').toLowerCase();

  const isPostponed = statusName.includes('POSTPONED') ||
    statusName.includes('CANCEL') ||
    statusName.includes('SUSPEND') ||
    statusName.includes('DELAY') ||
    statusName.includes('ABANDON') ||
    statusDetail.includes('postponed') ||
    statusDetail.includes('cancel') ||
    statusDetail.includes('suspend') ||
    statusDetail.includes('delay') ||
    statusShortRaw.includes('postp') ||
    statusShortRaw.includes('ppd') ||
    statusShortRaw.includes('canc') ||
    statusShortRaw.includes('susp');

  let status, statusShort;
  if (isPostponed) {
    status = 'postponed';
    statusShort = 'PT';
  } else {
    const completed = statusType.completed || state === 'post';
    const live = state === 'in';
    statusShort = completed ? (statusType.shortDetail || 'FT') : (live ? (statusType.shortDetail || 'LIVE') : 'NS');
    status = completed ? 'finished' : (live ? 'live' : 'notStarted');
  }

  // Scores
  let homeScore = (homeComp.score !== undefined && homeComp.score !== null && homeComp.score !== '')
    ? parseInt(homeComp.score, 10) : null;
  let awayScore = (awayComp.score !== undefined && awayComp.score !== null && awayComp.score !== '')
    ? parseInt(awayComp.score, 10) : null;

  if (isPostponed && homeScore === 0 && awayScore === 0) {
    homeScore = null;
    awayScore = null;
  }

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

  const dateKey = (ev.date || '').slice(0, 10);
  const id = dateKey ? `${homeTeam}-${awayTeam}-${dateKey}`.replace(/\s+/g, '-') : `${homeTeam}-${awayTeam}`.replace(/\s+/g, '-');

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

  // Extract match website link from ESPN links or build canonical URL
  const matchUrl = ev.links?.find(l => l.rel?.includes('summary') || l.rel?.includes('desktop'))?.href 
    || (ev.id ? `https://www.espn.com/soccer/match/_/gameId/${ev.id}` : null);

  const homeId = String(homeComp.id || '');
  const details = comp.details || [];
  const events = details.map(d => {
    const isHome = String(d.team?.id || '') === homeId;
    const athlete1 = d.athletesInvolved?.[0] || {};
    const athlete2 = d.athletesInvolved?.[1] || {};
    const isSub = d.type?.text?.toLowerCase().includes('substitution') || d.type?.id === '11';
    const playerIn = athlete1.displayName || athlete1.shortName || '';
    const playerOut = athlete2.displayName || athlete2.shortName || '';
    const playerName = isSub
      ? (playerIn ? `▲ ${playerIn}${playerOut ? ' (for ▼ ' + playerOut + ')' : ''}` : 'Substitution')
      : (athlete1.displayName || athlete1.shortName || 'Unknown');
    const typeText = d.type?.text || (d.scoringPlay ? 'Goal' : (d.redCard ? 'Red Card' : (d.yellowCard ? 'Yellow Card' : 'Event')));

    return {
      type: typeText,
      clock: d.clock?.displayValue || '',
      team: isHome ? 'home' : 'away',
      player: playerName,
      playerIn: playerIn || null,
      playerOut: playerOut || null,
      scoringPlay: !!d.scoringPlay,
      redCard: !!d.redCard || typeText.toLowerCase().includes('red card'),
      yellowCard: !!d.yellowCard || typeText.toLowerCase().includes('yellow card'),
      penalty: !!d.penaltyKick,
      ownGoal: !!d.ownGoal
    };
  });

  const extractStats = (statistics) => {
    if (!Array.isArray(statistics)) return {};
    const map = {};
    for (const s of statistics) {
      if (s.name && s.displayValue !== undefined) map[s.name] = s.displayValue;
    }
    return {
      possession: parseFloat(map.possessionPct || '0') || 0,
      shots: parseInt(map.totalShots || '0', 10) || 0,
      shotsOnTarget: parseInt(map.shotsOnTarget || '0', 10) || 0,
      corners: parseInt(map.wonCorners || '0', 10) || 0,
      fouls: parseInt(map.foulsCommitted || '0', 10) || 0,
      yellowCards: parseInt(map.yellowCards || '0', 10) || 0,
      redCards: parseInt(map.redCards || '0', 10) || 0,
      saves: parseInt(map.saves || '0', 10) || 0,
      offsides: parseInt(map.offsides || '0', 10) || 0,
      accuratePasses: parseInt(map.accuratePasses || '0', 10) || 0,
      totalPasses: parseInt(map.totalPasses || '0', 10) || 0,
      passAccuracy: parseFloat(map.passPct || '0') ? Math.round(parseFloat(map.passPct) * (parseFloat(map.passPct) <= 1 ? 100 : 1)) : 0,
      tackles: parseInt(map.effectiveTackles || map.totalTackles || '0', 10) || 0,
      interceptions: parseInt(map.interceptions || '0', 10) || 0,
    };
  };

  const hStats = extractStats(homeComp.statistics);
  const aStats = extractStats(awayComp.statistics);
  const hasStats = (hStats.shots > 0 || aStats.shots > 0 || hStats.possession > 0 || hStats.corners > 0);

  const stats = hasStats ? {
    possessionHome: hStats.possession || (aStats.possession ? Math.round((100 - aStats.possession) * 10) / 10 : 50),
    possessionAway: aStats.possession || (hStats.possession ? Math.round((100 - hStats.possession) * 10) / 10 : 50),
    shotsHome: hStats.shots,
    shotsAway: aStats.shots,
    shotsOnTargetHome: hStats.shotsOnTarget,
    shotsOnTargetAway: aStats.shotsOnTarget,
    cornersHome: hStats.corners,
    cornersAway: aStats.corners,
    foulsHome: hStats.fouls,
    foulsAway: aStats.fouls,
    yellowCardsHome: hStats.yellowCards,
    yellowCardsAway: aStats.yellowCards,
    redCardsHome: hStats.redCards,
    redCardsAway: aStats.redCards,
    savesHome: hStats.saves,
    savesAway: aStats.saves,
    offsidesHome: hStats.offsides,
    offsidesAway: aStats.offsides,
    accuratePassesHome: hStats.accuratePasses,
    accuratePassesAway: aStats.accuratePasses,
    totalPassesHome: hStats.totalPasses,
    totalPassesAway: aStats.totalPasses,
    passAccuracyHome: hStats.passAccuracy,
    passAccuracyAway: aStats.passAccuracy,
    tacklesHome: hStats.tackles,
    tacklesAway: aStats.tackles,
    interceptionsHome: hStats.interceptions,
    interceptionsAway: aStats.interceptions
  } : null;

  const venueName = comp.venue?.fullName || '';
  const venueCity = comp.venue?.address?.city || '';
  const venue = venueName ? `${venueName}${venueCity ? ', ' + venueCity : ''}` : null;
  const attendance = comp.attendance || null;
  const seriesSummary = comp.series?.summary || (comp.series?.description ? `${comp.series.title || 'Aggregate'}: ${comp.series.description}` : null);
  const referee = (comp.officials && comp.officials[0]?.displayName) || null;

  function extractTeamLogo(compObj) {
    if (!compObj || !compObj.team) return '';
    const t = compObj.team;
    if (t.logo && typeof t.logo === 'string' && t.logo.startsWith('http')) return t.logo;
    if (Array.isArray(t.logos) && t.logos.length > 0) {
      const href = t.logos[0]?.href;
      if (href && typeof href === 'string' && href.startsWith('http')) return href;
    }
    if (t.id) {
      return `https://a.espncdn.com/i/teamlogos/soccer/500/${t.id}.png`;
    }
    return '';
  }

  return {
    id,
    espnEventId: ev.id,
    homeTeam,
    awayTeam,
    homeLogo: extractTeamLogo(homeComp),
    awayLogo: extractTeamLogo(awayComp),
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
    matchUrl,
    stats,
    events,
    venue,
    venueName: venueName || null,
    venueCity: venueCity || null,
    attendance,
    seriesSummary,
    referee,
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

  // Also query scorepanel for key dates to discover unlisted leagues (cups, friendlies, other regional divisions)
  for (const d of dates.slice(0, 3)) {
    try {
      const spUrl = `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${d}`;
      const spRes = await safeFetch(spUrl, 1);
      if (!spRes) continue;
      const spData = await spRes.json();
      for (const block of (spData.scores || [])) {
        const lName = block.leagues?.[0]?.name || 'Soccer';
        const lSlug = block.leagues?.[0]?.slug || 'soccer';
        if (isExcludedLeague(lName)) continue;
        for (const ev of (block.events || [])) {
          if (isExcludedLeague(ev.name || '')) continue;
          const match = parseEspnEvent(ev, lName, lSlug);
          if (!match) continue;
          if (!matchesMap.has(match.id)) {
            matchesMap.set(match.id, match);
            totalFetched++;
          }
        }
      }
    } catch (_) {}
  }

  console.log(`  ESPN: fetched ${totalFetched} unique matches across leagues`);
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

async function pushToRender(data) {
  try {
    const renderUrl = process.env.RENDER_URL || 'https://ai-football-predictions.onrender.com/api/update';
    const res = await fetch(renderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: data
    });
    if (res.ok) {
      console.log('  Pushed to Render Live Engine successfully');
    } else {
      console.warn(`  Render push returned status ${res.status}`);
    }
  } catch (err) {
    console.warn('  Render push notice:', err.message);
  }
}

async function pushToCloudflareKV(data) {
  if (!CF_ACCOUNT_ID || !CF_API_TOKEN || !CF_KV_NS_ID) {
    console.log('Skipping CF KV push (missing credentials).');
    return;
  }
  try {
    const url = `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${CF_KV_NS_ID}/values/${KV_KEY}`;
    const res = await fetch(url, {
      method: 'PUT',
      headers: { 'Authorization': `Bearer ${CF_API_TOKEN}`, 'Content-Type': 'application/json' },
      body: data
    });
    const json = await res.json();
    if (!json.success) {
      console.warn(`  ⚠️ Cloudflare KV quota or write issue: ${JSON.stringify(json.errors)}`);
      return;
    }
    console.log('  Pushed to Cloudflare KV successfully');
  } catch (err) {
    console.warn('  ⚠️ Cloudflare KV network error:', err.message);
  }
}

// ─── Telegram Broadcasting ────────────────────────────────────────────────────
async function sendTelegramMessage(text) {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) return false;
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text, parse_mode: 'Markdown', disable_web_page_preview: true })
    });
    const result = await res.json();
    if (!result.ok) {
      console.warn('Telegram Markdown error, retrying without formatting:', result.description);
      const plainText = text.replace(/[*_`]/g, '');
      const retryRes = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID, text: plainText, disable_web_page_preview: true })
      });
      const retryResult = await retryRes.json();
      return retryResult.ok;
    }
    return true;
  } catch (e) {
    console.error('Error posting to Telegram:', e.message);
    return false;
  }
}

async function postDailyDigestToTelegram(matches) {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    console.log('Skipping Telegram: Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID');
    return [];
  }
  
  const todayStr = new Date().toISOString().slice(0, 10);
  const todaysMatches = matches.filter(m => m.date.startsWith(todayStr) && m.prediction && m.status !== 'postponed' && !m.statusShort?.toLowerCase().includes('postp'));
  
  if (todaysMatches.length === 0) {
    console.log('No matches today to post to Telegram.');
    return [];
  }

  // Filter for today's non-finished matches (so we don't pick already completed matches)
  const upcomingToday = todaysMatches.filter(m => m.status !== 'finished' && m.statusShort !== 'FT');
  const candidatePool = upcomingToday.length > 0 ? upcomingToday : todaysMatches;

  // Rank matches by highest probability and confidence to identify the 2 best banker picks to kill off the game
  candidatePool.sort((a, b) => {
    const probA = Math.max(a.prediction?.homeWinProbability || 0, a.prediction?.awayWinProbability || 0, a.prediction?.drawProbability || 0);
    const probB = Math.max(b.prediction?.homeWinProbability || 0, b.prediction?.awayWinProbability || 0, b.prediction?.drawProbability || 0);
    if (probB !== probA) {
      return probB - probA;
    }
    const edgeA = Math.abs(a.oddsRating || 0);
    const edgeB = Math.abs(b.oddsRating || 0);
    return edgeB - edgeA;
  });

  // Pick ONLY the top 2 best picks
  const topPicks = candidatePool.slice(0, 2);

  const dateFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric'
  });

  let msg = `🎯 *AI SCORECAST: TOP 2 BANKER PICKS* 🎯\n` +
            `📅 *${dateFormatted}*\n\n` +
            `Here are today's 2 highest-probability AI banker picks selected to kill off the game:\n\n`;

  topPicks.forEach((m, idx) => {
    const time = new Date(m.date).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', timeZone: 'UTC' }) + ' UTC';
    const rec = m.prediction?.recommendation || 'Direct Win';
    const prob = Math.max(m.prediction?.homeWinProbability || 0, m.prediction?.awayWinProbability || 0, m.prediction?.drawProbability || 0);
    const safeOption = (m.prediction?.stakingOptions && m.prediction?.stakingOptions.length > 0)
      ? m.prediction.stakingOptions[0]
      : 'High Confidence';
    const label = idx === 0 ? '⭐ *PICK #1 — LOCK OF THE DAY*' : '⭐ *PICK #2 — HIGH CONFIDENCE*';

    msg += `${label}\n` +
           `⚽ *${m.homeTeam} vs ${m.awayTeam}*\n` +
           `🏆 ${m.league || 'Featured Competition'}\n` +
           `⏰ Kickoff: ${time}\n` +
           `💡 *Pick:* ${rec}\n` +
           `🔥 *Probability:* ${prob}%\n` +
           `🛡️ *Safe Staking:* ${safeOption}\n\n`;
  });

  msg += `────────────────────\n` +
         `📊 *Looking for all other matches?*\n` +
         `We only post our 2 best lock picks here on Telegram.\n\n` +
         `For live scores, head-to-head stats, and predictions for *all 300+ matches*, visit our web dashboard:\n\n` +
         `👉 [Open Live Prediction Dashboard](https://kwesiwindsurf-crypto.github.io/ai-football-predictions/)\n` +
         `📲 _All matches and live scorecards updated in real time!_`;

  const ok = await sendTelegramMessage(msg);
  if (ok) {
    console.log(`✅ Successfully posted top ${topPicks.length} banker picks to Telegram!`);
    return topPicks.map((m, idx) => ({
      id: m.id,
      homeTeam: m.homeTeam,
      awayTeam: m.awayTeam,
      league: m.league,
      recommendation: m.prediction.recommendation,
      isPickOfTheDay: idx === 0,
      date: m.date
    }));
  }
  return [];
}

function evaluatePrediction(rec, hScore, aScore, hTeam, aTeam) {
  const h = parseInt(hScore, 10);
  const a = parseInt(aScore, 10);
  if (isNaN(h) || isNaN(a)) return { result: 'PENDING', isDraw: false };
  
  const total = h + a;
  const isDraw = (h === a);
  const recStr = rec || '';

  let result = 'UNKNOWN';

  if (recStr.includes('to Win (1)')) {
    result = h > a ? 'WON' : 'LOST';
  } else if (recStr.includes('to Win (2)')) {
    result = a > h ? 'WON' : 'LOST';
  } else if (recStr.includes('or Draw') || recStr.includes('Double Chance') || recStr.includes('1X') || recStr.includes('X2')) {
    const isHome = recStr.includes(hTeam) || recStr.includes('1X');
    const isAway = recStr.includes(aTeam) || recStr.includes('X2');
    if (isHome && !isAway) result = h >= a ? 'WON' : 'LOST';
    else if (isAway && !isHome) result = a >= h ? 'WON' : 'LOST';
    else if (recStr.includes('12')) result = h !== a ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 0.5')) {
    result = total >= 1 ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 1.5')) {
    result = total >= 2 ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 2.5')) {
    result = total >= 3 ? 'WON' : 'LOST';
  } else if (recStr.includes('Over 3.5')) {
    result = total >= 4 ? 'WON' : 'LOST';
  } else if (recStr.includes('Under 1.5')) {
    result = total < 2 ? 'WON' : 'LOST';
  } else if (recStr.includes('Under 2.5')) {
    result = total < 3 ? 'WON' : 'LOST';
  } else if (recStr.includes('Under 3.5')) {
    result = total < 4 ? 'WON' : 'LOST';
  } else if (recStr.includes('Both Teams To Score') || recStr.includes('BTTS')) {
    result = (h > 0 && a > 0) ? 'WON' : 'LOST';
  } else if (recStr.toLowerCase().includes('draw')) {
    result = h === a ? 'WON' : 'LOST';
  }

  return { result, isDraw };
}

async function checkAndPostMatchResults(activePicks, matches, todayResults = []) {
  if (!activePicks || activePicks.length === 0 || !TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    return { remainingPicks: activePicks || [], updatedTodayResults: todayResults };
  }

  const remainingPicks = [];
  const updatedTodayResults = [...todayResults];

  for (const pick of activePicks) {
    const match = matches.find(m => m.id === pick.id);
    if (!match || match.status !== 'FT') {
      remainingPicks.push(pick);
      continue;
    }

    const hScore = match.homeScore;
    const aScore = match.awayScore;
    const { result, isDraw } = evaluatePrediction(pick.recommendation, hScore, aScore, match.homeTeam, match.awayTeam);

    const isPod = pick.isPickOfTheDay ? '⭐ *PICK OF THE DAY RESULT* ⭐\n\n' : '🚨 *FULL TIME RESULT* 🚨\n\n';
    let statusLine = '🏁 *FINAL*';
    if (result === 'WON') {
      statusLine = isDraw ? '✅ *RESULT: WON (Draw Covered)*' : '✅ *RESULT: WON*';
    } else if (result === 'LOST') {
      statusLine = isDraw ? '❌ *RESULT: LOST (Match Ended Draw)*' : '❌ *RESULT: LOST*';
    }

    const msg = `${isPod}` +
                `⚽ *${match.homeTeam} ${hScore} - ${aScore} ${match.awayTeam}*\n` +
                `🏆 ${match.league || pick.league || ''}\n\n` +
                `💡 *Our Pick:* ${pick.recommendation}\n` +
                `${statusLine}\n\n` +
                `🌐 [View Full Match Details & Scorecard](https://kwesiwindsurf-crypto.github.io/ai-football-predictions/)\n` +
                `📲 _Check the app for live results & upcoming predictions!_`;

    const success = await sendTelegramMessage(msg);
    if (!success) {
      remainingPicks.push(pick);
    } else {
      console.log(`✅ Posted result for ${match.homeTeam} vs ${match.awayTeam} (${result}, ${hScore}-${aScore}) to Telegram!`);
      updatedTodayResults.push({
        id: match.id,
        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        league: match.league || pick.league || '',
        homeScore: hScore,
        awayScore: aScore,
        recommendation: pick.recommendation,
        isPickOfTheDay: !!pick.isPickOfTheDay,
        result,
        isDraw
      });
      await sleep(600);
    }
  }

  return { remainingPicks, updatedTodayResults };
}

async function postDailyDashboardToTelegram(todayResults) {
  if (!todayResults || todayResults.length === 0 || !TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    return false;
  }

  const total = todayResults.length;
  const wins = todayResults.filter(r => r.result === 'WON').length;
  const draws = todayResults.filter(r => r.isDraw).length;
  const losses = todayResults.filter(r => r.result === 'LOST').length;
  const decided = wins + losses;
  const winRate = decided > 0 ? Math.round((wins / decided) * 100) : (total > 0 ? Math.round((wins / total) * 100) : 0);

  const dateFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric'
  });

  let msg = `📊 *DAILY PERFORMANCE DASHBOARD* 📊\n` +
            `📅 *${dateFormatted}*\n\n` +
            `🎯 *Today's Scorecard:*\n` +
            `✅ *Wins:* ${wins}\n` +
            `🤝 *Draws:* ${draws} match${draws === 1 ? '' : 'es'}\n` +
            `❌ *Losses:* ${losses}\n` +
            `📈 *Accuracy:* ${winRate}% (${wins}/${decided || total})\n\n` +
            `────────────────────\n` +
            `📋 *Matches Breakdown:*\n`;

  for (const r of todayResults) {
    const icon = r.result === 'WON' ? '✅' : r.result === 'LOST' ? '❌' : '🏁';
    const pod = r.isPickOfTheDay ? ' ⭐' : '';
    const drawTag = r.isDraw ? ' (Draw)' : '';
    msg += `• *${r.homeTeam} ${r.homeScore} - ${r.awayScore} ${r.awayTeam}*${pod}\n` +
           `  Pick: ${r.recommendation} ➔ ${icon} *${r.result}*${drawTag}\n`;
  }

  msg += `────────────────────\n` +
         `🌐 [View Verified Scorecard & Full Details](https://kwesiwindsurf-crypto.github.io/ai-football-predictions/)\n` +
         `📲 _Check tomorrow's fixtures & early predictions in the app!_`;

  const success = await sendTelegramMessage(msg);
  if (success) {
    console.log(`✅ Successfully posted Daily Performance Dashboard (${total} matches) to Telegram!`);
    return true;
  }
  return false;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('Starting ESPN-only scraper...');

  // 0. Load existing KV data so we can preserve predictions & historical matches
  console.log('Loading existing matches from KV to preserve predictions & historical archive...');
  const currentKvData = await getCloudflareKV();
  const existingMatchesMap = new Map();
  if (currentKvData && currentKvData.matchesData && currentKvData.matchesData.matches) {
    for (const m of currentKvData.matchesData.matches) {
      existingMatchesMap.set(m.id, m);
    }
  }

  // Load permanent historical archive from KV
  const historicalMatchesMap = new Map();
  if (currentKvData && Array.isArray(currentKvData.historicalMatches)) {
    for (const hm of currentKvData.historicalMatches) {
      historicalMatchesMap.set(hm.id, hm);
    }
  }

  // Also load local history file if present
  try {
    const localHistPath = path.join(__dirname, '..', 'docs', 'data', 'history.json');
    if (fs.existsSync(localHistPath)) {
      const localHist = JSON.parse(fs.readFileSync(localHistPath, 'utf8'));
      if (Array.isArray(localHist)) {
        for (const hm of localHist) {
          if (!historicalMatchesMap.has(hm.id)) historicalMatchesMap.set(hm.id, hm);
        }
      }
    }
  } catch (_) {}

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
          return { avgRating: 0, formation: rosterObj.formation || null, startingXI, bench };
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
    let existing = existingMatchesMap.get(m.id);
    if (!existing) {
      // Fallback for older legacy IDs without date suffix, strictly validating league matches
      const legacyId = `${m.homeTeam}-${m.awayTeam}`.replace(/\s+/g, '-');
      const candidate = existingMatchesMap.get(legacyId);
      if (candidate && candidate.league === m.league) {
        existing = candidate;
      }
    }
    if (existing && existing.prediction) {
      const analysisText = existing.prediction.analysis || '';
      const hasCompetitionMismatch = analysisText.includes('Cup') && !m.league.toLowerCase().includes('cup');
      if (!hasCompetitionMismatch) {
        m.prediction = existing.prediction;
      }
      if (existing.homeOdds !== undefined) m.homeOdds = existing.homeOdds;
      if (existing.drawOdds !== undefined) m.drawOdds = existing.drawOdds;
      if (existing.awayOdds !== undefined) m.awayOdds = existing.awayOdds;
      if (existing.oddsRating !== undefined) m.oddsRating = existing.oddsRating;
      if (existing.h2hSummary !== undefined && existing.h2hSummary !== null) m.h2hSummary = existing.h2hSummary;
      if (!m.matchUrl && existing.matchUrl) m.matchUrl = existing.matchUrl;
    }
  }

  // 3. Telegram Broadcast & Result Monitoring
  const FORCE_TELEGRAM = process.env.FORCE_TELEGRAM === 'true' || process.argv.includes('--push-telegram');
  const FORCE_DASHBOARD = process.env.FORCE_DASHBOARD === 'true' || process.argv.includes('--post-dashboard');

  let lastTelegramPostDate = null;
  let lastDashboardDate = null;
  let activeTelegramPicks = [];
  let todayResults = [];

  if (currentKvData) {
    if (currentKvData.lastTelegramPostDate) lastTelegramPostDate = currentKvData.lastTelegramPostDate;
    if (currentKvData.lastDashboardDate) lastDashboardDate = currentKvData.lastDashboardDate;
    if (Array.isArray(currentKvData.activeTelegramPicks)) {
      activeTelegramPicks = currentKvData.activeTelegramPicks;
    } else if (currentKvData.activeTelegramPick) {
      activeTelegramPicks = [currentKvData.activeTelegramPick];
    }
    // Only keep todayResults if they are from today
    if (Array.isArray(currentKvData.todayResults) && currentKvData.lastTelegramPostDate === todayStr) {
      todayResults = currentKvData.todayResults;
    }
  }

  // A. Check if any active picks have finished and post individual FT results
  if (activeTelegramPicks.length > 0) {
    console.log(`\nChecking results for ${activeTelegramPicks.length} active Telegram pick(s)...`);
    const { remainingPicks, updatedTodayResults } = await checkAndPostMatchResults(activeTelegramPicks, matches, todayResults);
    activeTelegramPicks = remainingPicks;
    todayResults = updatedTodayResults;
  }

  // B. Post Daily Digest of all games once per day (or if forced)
  if (lastTelegramPostDate !== todayStr || FORCE_TELEGRAM) {
    console.log(`\nNew day detected! Attempting to post Top 2 Banker Picks to Telegram...`);
    const newActivePicks = await postDailyDigestToTelegram(matches);
    if (newActivePicks && newActivePicks.length > 0) {
      const existingIds = new Set(activeTelegramPicks.map(p => p.id));
      for (const p of newActivePicks) {
        if (!existingIds.has(p.id)) {
          activeTelegramPicks.push(p);
        }
      }
      lastTelegramPostDate = todayStr; // Update flag ONLY on successful post
      todayResults = []; // Reset results for new day
      lastDashboardDate = null;
    }
  } else {
    console.log(`\nTelegram: Already posted today's digest (${todayStr}). Active picks being monitored: ${activeTelegramPicks.length}`);
  }

  // C. Post Daily Dashboard when all today's matches have concluded
  // Condition: we have results for today, no remaining active picks for today, and dashboard hasn't been posted yet today
  const remainingTodayPicks = activeTelegramPicks.filter(p => p.date && p.date.startsWith(todayStr));
  const shouldPostDashboard = (todayResults.length > 0 && remainingTodayPicks.length === 0 && lastDashboardDate !== todayStr) || (FORCE_DASHBOARD && todayResults.length > 0);

  if (shouldPostDashboard) {
    console.log(`\nAll today's matches have finished! Posting Daily Performance Dashboard...`);
    const dashboardSent = await postDailyDashboardToTelegram(todayResults);
    if (dashboardSent) {
      lastDashboardDate = todayStr;
    }
  }

  // Prune any picks older than 48 hours to avoid indefinite buildup
  const twoDaysAgo = new Date(Date.now() - 48 * 3600 * 1000).toISOString();
  activeTelegramPicks = activeTelegramPicks.filter(p => !p.date || p.date >= twoDaysAgo);

  // 3.5. Fetch full table standings for major competitions
  console.log('\nFetching live standings across major competitions...');
  const standingsByLeague = [];
  const MAJOR_STANDINGS_SLUGS = [
    { slug: 'eng.1', name: 'Premier League', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/23.png', id: 1 },
    { slug: 'esp.1', name: 'La Liga', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/15.png', id: 2 },
    { slug: 'ita.1', name: 'Serie A', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/12.png', id: 3 },
    { slug: 'ger.1', name: 'Bundesliga', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/10.png', id: 4 },
    { slug: 'fra.1', name: 'Ligue 1', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/9.png', id: 5 },
    { slug: 'ned.1', name: 'Eredivisie', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/11.png', id: 6 },
    { slug: 'por.1', name: 'Primeira Liga', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/14.png', id: 7 },
    { slug: 'tur.1', name: 'Süper Lig', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/18.png', id: 8 },
    { slug: 'usa.1', name: 'Major League Soccer', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/19.png', id: 9 },
    { slug: 'sau.1', name: 'Saudi Pro League', logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2800.png', id: 10 }
  ];

  for (const item of MAJOR_STANDINGS_SLUGS) {
    try {
      const sRes = await safeFetch(`https://site.api.espn.com/apis/v2/sports/soccer/${item.slug}/standings`, 1);
      if (sRes && sRes.ok) {
        const sData = await sRes.json();
        const children = sData.children || [];
        if (children.length > 0) {
          const entries = children[0].standings?.entries || [];
          const standings = [];
          for (const entry of entries) {
            const team = entry.team || {};
            const stats = entry.stats || [];
            const getStat = (n) => {
              const st = stats.find(s => s.name === n || s.type === n);
              return st ? (st.value || 0) : 0;
            };
            const logos = team.logos || [];
            const logo = logos.length > 0 ? (logos[0].href || '') : '';

            standings.push({
              rank: getStat('rank') || (standings.length + 1),
              name: team.displayName || team.name || 'Team',
              logo,
              points: getStat('points'),
              goalsDiff: getStat('pointDifferential'),
              played: getStat('gamesPlayed'),
              win: getStat('wins'),
              draw: getStat('ties'),
              lose: getStat('losses')
            });
          }
          standings.sort((a, b) => a.rank - b.rank);
          standingsByLeague.push({
            id: item.id,
            name: item.name,
            logo: item.logo,
            standings
          });
        }
      }
    } catch (_) {}
  }
  console.log(`  Fetched full table standings for ${standingsByLeague.length} competitions.`);

  // 4. Accumulate permanent historical matches for the website (days ++)
  for (const m of matches) {
    if (m.status === 'finished' || m.statusShort === 'FT') {
      historicalMatchesMap.set(m.id, m);
    }
  }
  for (const em of existingMatchesMap.values()) {
    if (em.status === 'finished' || em.statusShort === 'FT') {
      if (!historicalMatchesMap.has(em.id)) {
        historicalMatchesMap.set(em.id, em);
      }
    }
  }

  const historicalMatches = Array.from(historicalMatchesMap.values());
  historicalMatches.sort((a, b) => new Date(b.date) - new Date(a.date));
  console.log(`\n  Permanent historical archive: ${historicalMatches.length} total matches preserved for the website.`);

  // Write history to docs/data/history.json for persistent Git storage
  try {
    const docsDataDir = path.join(__dirname, '..', 'docs', 'data');
    if (!fs.existsSync(docsDataDir)) fs.mkdirSync(docsDataDir, { recursive: true });
    const historyFilePath = path.join(docsDataDir, 'history.json');
    fs.writeFileSync(historyFilePath, JSON.stringify(historicalMatches, null, 2));
    console.log(`  Updated ${historyFilePath}`);
  } catch (err) {
    console.warn('  Could not write docs/data/history.json:', err.message);
  }

  // Mobile app data: ONLY rolling 7-day fixtures and standings (strips 3.6MB historical archive)
  const appData = JSON.stringify({
    matchesData: {
      lastUpdated: new Date().toISOString(),
      scrapedBy: 'espn-only',
      matches // Rolling 7-day window for the Flutter app
    },
    standingsData: {
      lastUpdated: new Date().toISOString(),
      standingsByLeague
    },
    lastTelegramPostDate,
    lastDashboardDate,
    activeTelegramPicks,
    todayResults
  });

  console.log('\nPushing to Render Live Engine...');
  await pushToRender(appData);

  console.log('\nPushing to Cloudflare KV...');
  await pushToCloudflareKV(appData);
  console.log(`Done! Pushed clean ${matches.length} rolling matches to Render & Cloudflare KV.`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
