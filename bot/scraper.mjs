// GitHub Actions Full Scraper — ESPN Only
// Fetches ALL matches, scores, and odds exclusively from ESPN.
// Pushes the result to Cloudflare KV for the Flutter app to consume.

const CF_ACCOUNT_ID = process.env.CF_ACCOUNT_ID;
const CF_API_TOKEN  = process.env.CF_API_TOKEN;
const CF_KV_NS_ID   = process.env.CF_KV_NAMESPACE_ID;
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;
const KV_KEY        = 'latest_soccer_data';

// ─── Keywords used to filter out women's / youth / irrelevant matches ─────────
const EXCLUDED_LEAGUE_KEYWORDS = [
  'women', 'woman', 'femenino', 'feminine', 'frauen', 'dames',
  'femmes', 'nwsl', 'wsl', 'nwsl', 'u17', 'u19', 'u20', 'u21', 'u23',
  'youth', 'reserve', 'friendlies', 'international friendly',
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

// ─── Generate probabilities from ESPN moneyline decimal odds ──────────────────
function oddsToProbs(hOdds, dOdds, aOdds) {
  if (!hOdds || !aOdds) return { hp: 45, dp: 25, ap: 30 };
  const rawH = 1 / hOdds;
  const rawD = dOdds ? 1 / dOdds : 0;
  const rawA = 1 / aOdds;
  const total = rawH + rawD + rawA;
  return {
    hp: Math.round((rawH / total) * 100),
    dp: Math.round((rawD / total) * 100),
    ap: Math.round((rawA / total) * 100),
  };
}

// ─── Generate a synthetic rating from odds ────────────────────────────────────
function oddsToRating(hOdds, aOdds) {
  if (!hOdds || !aOdds) return 0;
  const diff = (1 / hOdds) - (1 / aOdds);
  return Math.max(-25, Math.min(25, Math.round(-(diff / 0.01))));
}

// ─── Staking options ──────────────────────────────────────────────────────────
function generateStakingOptions(home, away, hp, ap, hOdds, dOdds, aOdds, primarySafe) {
  const isHomeFav = hp >= ap;
  const fav = isHomeFav ? home : away;
  const favOdds = isHomeFav ? hOdds : aOdds;
  const dnbOdds = favOdds ? Math.max(1.30, parseFloat((favOdds * 0.82).toFixed(2))) : 1.70;
  return [
    primarySafe || `Safe: ${isHomeFav ? '1X' : 'X2'} (${fav} or Draw)`,
    `Value: ${fav} Draw No Bet (${dnbOdds})`,
    `Risky: ${fav} to WIN by 2+ Goals (2.85)`,
    `BTTS: Both Teams To Score - Yes (1.78)`,
    `Goals: Over 1.5 Total Goals (1.34)`
  ];
}

// ─── Prediction engine ────────────────────────────────────────────────────────
function makePrediction(home, away, hOdds, dOdds, aOdds, league) {
  const hasOdds = hOdds > 0 && aOdds > 0;
  const { hp, dp, ap } = oddsToProbs(hOdds, dOdds, aOdds);
  const rating = oddsToRating(hOdds, aOdds);
  const oddsDiff = hasOdds ? hOdds - aOdds : 0;

  const isUCL = (league || '').toLowerCase().includes('champions league');
  const isEvenOdds = hasOdds ? Math.abs(oddsDiff) <= 0.15 : rating === 0;
  const isHomeFavorite = hasOdds ? hOdds <= 1.5 : rating <= -10;
  const isHomeUnderdog = hasOdds ? hOdds >= aOdds + 1.5 : rating >= 10;
  const isVolatileLeague = (league || '').toLowerCase().includes('mls') || (league || '').toLowerCase().includes('bundesliga');

  let recommendation = '';
  let strategyAnalysis = '';
  let primarySafe = '';
  let fHp = hp, fDp = dp, fAp = ap;

  if (isUCL) {
    recommendation = rating < 0 ? `${home} or Draw (1X)` : `${away} or Draw (X2)`;
    primarySafe = rating < 0 ? `Safe: 1X (${home} or Draw)` : `Safe: X2 (${away} or Draw)`;
    strategyAnalysis = `UCL: Stalemate protection active.`;
    fDp = 35; fHp = rating < 0 ? 45 : 20; fAp = rating < 0 ? 20 : 45;
  } else if (isEvenOdds) {
    recommendation = `Over 0.5 Goals`;
    primarySafe = `Safe: Over 0.5 Goals`;
    strategyAnalysis = `Even Odds (Tight Match): Output Over 0.5 Goals.`;
    fHp = 45; fDp = 10; fAp = 45;
  } else if (isHomeFavorite) {
    recommendation = `${home} or Draw & Over 1.5 Goals (1X + Over 1.5)`;
    primarySafe = `Safe: 1X + Over 1.5 Goals (${home} or Draw & Over 1.5 Goals)`;
    strategyAnalysis = `Home Favorite (Odds ≤ 1.50): Compound 1X + Over 1.5 Goals.`;
    fHp = Math.max(hp, 65); fDp = 22; fAp = 13;
  } else if (isHomeUnderdog) {
    if (isVolatileLeague) {
      recommendation = `Over 0.5 Goals`;
      primarySafe = `Safe: Over 0.5 Goals`;
      strategyAnalysis = `Home Underdog in volatile league: Over 0.5 Goals.`;
      fHp = 42; fDp = 10; fAp = 48;
    } else {
      recommendation = `${away} or Draw (X2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Away Favored / Home Underdog: Output X2.`;
      fAp = Math.max(ap, 60); fDp = 25; fHp = 15;
    }
  } else {
    if (!hasOdds || hOdds < aOdds) {
      recommendation = `${home} or Draw (1X)`;
      primarySafe = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Standard Market: Home team favored.`;
      fHp = 55; fDp = 27; fAp = 18;
    } else if (aOdds < hOdds) {
      recommendation = `${away} or Draw (X2)`;
      primarySafe = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Standard Market: Away team favored.`;
      fHp = 18; fDp = 27; fAp = 55;
    } else {
      recommendation = `Over 0.5 Goals`;
      primarySafe = `Safe: Over 0.5 Goals`;
      strategyAnalysis = `Standard Market: Balanced match, Over 0.5 Goals.`;
      fHp = 45; fDp = 10; fAp = 45;
    }
  }

  return {
    homeWinProbability: fHp,
    drawProbability: fDp,
    awayWinProbability: fAp,
    recommendation,
    analysis: `${strategyAnalysis}\nRating: ${rating}.`,
    stakingOptions: generateStakingOptions(home, away, fHp, fAp, hOdds, dOdds, aOdds, primarySafe)
  };
}

// ─── Fetch ESPN fixtures for a single league slug and date string ──────────────
async function fetchEspnLeagueFixtures(slug, dateStr) {
  const url = `https://site.api.espn.com/apis/site/v2/sports/soccer/${slug}/scoreboard?dates=${dateStr}&limit=100`;
  const res = await safeFetch(url, 1);
  if (!res) return [];
  try {
    const data = await res.json();
    return data.events || [];
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
    oddsRating: oddsToRating(hOdds, aOdds),
    espnLeagueSlug: leagueSlug, // Internal use
    homeRank: null,
    awayRank: null,
    homeForm,
    awayForm,
    homePoints,
    awayPoints,
    homeLineup: null,
    awayLineup: null,
    h2hSummary: null,
    matchUrl: null,
    prediction: makePrediction(homeTeam, awayTeam, hOdds, dOdds, aOdds, leagueLabel)
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
    }
  } catch (e) {
    console.error('Error posting to Telegram:', e.message);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('Starting ESPN-only scraper...');
  console.log(`Fetching fixtures for yesterday → +6 days from ESPN...`);

  const matches = await fetchAllEspnFixtures();
  const leagues = new Set(matches.map(m => m.league));

  console.log(`\nTotal: ${matches.length} matches across ${leagues.size} leagues`);
  const dates = [...new Set(matches.map(m => m.date.substring(0, 10)))].sort();
  console.log('Dates included:', dates.join(', '));

  // 2. Fetch Lineups for Today's and Live Matches
  console.log('\nFetching lineups for matches happening today or live...');
  const todayStr = new Date().toISOString().slice(0, 10);
  const matchesToEnrich = matches.filter(m => m.date.startsWith(todayStr) || m.status === 'live');
  
  // Process in small batches to avoid spamming the API
  const batchSize = 10;
  for (let i = 0; i < matchesToEnrich.length; i += batchSize) {
    const batch = matchesToEnrich.slice(i, i + batchSize);
    await Promise.all(batch.map(async (m) => {
      const summary = await fetchEspnSummary(m.espnLeagueSlug, m.espnEventId);
      if (!summary || !summary.rosters || summary.rosters.length < 2) return;
      
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
      
      // Match roster to home/away
      const r1 = summary.rosters[0];
      const r2 = summary.rosters[1];
      const r1IsHome = r1.homeAway === 'home';
      
      m.homeLineup = parseLineup(r1IsHome ? r1 : r2);
      m.awayLineup = parseLineup(r1IsHome ? r2 : r1);
    }));
  }
  
  // Clean up internal slug before upload
  matches.forEach(m => delete m.espnLeagueSlug);

  // 3. Telegram Broadcast (Once per day)
  // Use the same todayStr already defined above
  let lastTelegramPostDate = null;
  const currentKvData = await getCloudflareKV();
  if (currentKvData && currentKvData.lastTelegramPostDate) {
    lastTelegramPostDate = currentKvData.lastTelegramPostDate;
  }

  if (lastTelegramPostDate !== todayStr) {
    console.log(`\nNew day detected! Attempting to post Pick of the Day to Telegram...`);
    await postPickOfTheDayToTelegram(matches);
    lastTelegramPostDate = todayStr; // Update flag
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
    lastTelegramPostDate
  });

  console.log('\nPushing to Cloudflare KV...');
  await pushToCloudflareKV(finalData);
  console.log(`Done! ${matches.length} matches live in KV.`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
