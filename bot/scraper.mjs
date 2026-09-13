// GitHub Actions Full Scraper
// Runs with no subrequest/time limits, scrapes ALL matches + lineups, pushes to Cloudflare KV
import * as cheerio from 'cheerio';

const CF_ACCOUNT_ID = process.env.CF_ACCOUNT_ID;
const CF_API_TOKEN  = process.env.CF_API_TOKEN;
const CF_KV_NS_ID   = process.env.CF_KV_NAMESPACE_ID;
const KV_KEY        = 'latest_soccer_data';

// ─── League Codes ────────────────────────────────────────────────────────────
const KNOWN_LEAGUES = {
  'UK1': 'England - Premier League',   'EN1': 'England - Premier League',
  'UK2': 'England - Championship',     'EN2': 'England - Championship',
  'UK3': 'England - League One',       'UK4': 'England - League Two',
  'ES1': 'Spain - La Liga',            'ES2': 'Spain - Segunda División',
  'IT1': 'Italy - Serie A',            'IT2': 'Italy - Serie B',
  'DE1': 'Germany - Bundesliga',       'DE2': 'Germany - 2. Bundesliga',
  'FR1': 'France - Ligue 1',           'FR2': 'France - Ligue 2',
  'NL1': 'Netherlands - Eredivisie',   'PT1': 'Portugal - Primeira Liga',
  'PT2': 'Portugal - Liga Portugal 2', 'US1': 'USA - Major League Soccer (MLS)',
  'TR1': 'Turkey - Süper Lig',         'TU1': 'Turkey - Süper Lig',
  'BR1': 'Brazil - Série A',           'BR2': 'Brazil - Série B',
  'AR1': 'Argentina - Liga Profesional','MX1': 'Mexico - Liga MX',
  'MX2': 'Mexico - Liga de Expansión MX','SA1': 'Saudi Arabia - Pro League',
  'CL1': 'Chile - Primera División',   'CO1': 'Colombia - Primera A',
  'PE1': 'Peru - Liga 1',              'DK1': 'Denmark - Superliga',
  'DK2': 'Denmark - 1st Division',     'SK1': 'Slovakia - Super Liga',
  'CZ1': 'Czech Republic - First League','PL1': 'Poland - Ekstraklasa',
  'UA1': 'Ukraine - Premier League',   'GR1': 'Greece - Super League',
  'SC1': 'Scotland - Premiership',     'SC2': 'Scotland - Championship',
  'IR1': 'Ireland - Premier Division', 'NO1': 'Norway - Eliteserien',
  'SE1': 'Sweden - Allsvenskan',       'CH1': 'Switzerland - Super League',
  'AT1': 'Austria - Bundesliga',       'BE1': 'Belgium - Pro League',
  'ZA1': 'South Africa - Premier League','EE1': 'Estonia - Meistriliiga',
  'FI1': 'Finland - Veikkausliiga',
  'CLICU': 'Copa Libertadores / Sudamericana',
  'CL': 'UEFA - Champions League',
  'EL': 'UEFA - Europa League',
  'ECL': 'UEFA - Conference League'
};

// ─── Top 5 Country Pages ─────────────────────────────────────────────────────
const TOP_COUNTRIES = [
  { country: 'Spain',   defaultLeague: 'Spain - La Liga',         url: 'https://soccer-rating.com/Spain/'   },
  { country: 'France',  defaultLeague: 'France - Ligue 1',         url: 'https://soccer-rating.com/France/'  },
  { country: 'Germany', defaultLeague: 'Germany - Bundesliga',     url: 'https://soccer-rating.com/Germany/' },
  { country: 'Italy',   defaultLeague: 'Italy - Serie A',          url: 'https://soccer-rating.com/Italy/'   },
  { country: 'England', defaultLeague: 'England - Premier League', url: 'https://soccer-rating.com/England/' }
];

// ─── User-Agent Pool (20 realistic modern browser UAs) ──────────────────────
const USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 Edg/123.0.0.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:125.0) Gecko/20100101 Firefox/125.0',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (iPad; CPU OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36',
  'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 OPR/108.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Vivaldi/6.7.3329.35',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0',
  'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0'
];

function getRandomUserAgent() {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function formatLeagueName(rawCode, country) {
  const code = (rawCode || '').trim();
  if (KNOWN_LEAGUES[code]) return KNOWN_LEAGUES[code];
  if (country) {
    const n = (code.match(/\d+/) || [])[0];
    if (n) {
      const s = n === '1' ? '1st' : n === '2' ? '2nd' : n === '3' ? '3rd' : `${n}th`;
      return `${country} - ${s} Division`;
    }
    return `${country} League`;
  }
  return code || 'General League';
}

function parseMatchDate(title) {
  if (!title) return new Date().toISOString();
  const m = title.match(/(\d{1,2})\/(\d{1,2})\s+(\d{1,2}):(\d{2})/);
  if (!m) return new Date().toISOString();
  const year = new Date().getUTCFullYear();
  const day = m[1].padStart(2, '0');
  const month = m[2].padStart(2, '0');
  const hour = m[3].padStart(2, '0');
  const min = m[4].padStart(2, '0');
  // soccer-rating.com operates in UTC+1 (BST/CET)
  return new Date(`${year}-${month}-${day}T${hour}:${min}:00+01:00`).toISOString();
}

function parseLineupTable($, sel) {
  const startingXI = [], bench = [];
  let isBench = false;
  $(sel).find('tr').each((_, row) => {
    if ($(row).find('hr').length) { isBench = true; return; }
    const nameDiv = $(row).find('div.nomobil').text().trim() || $(row).find('td').eq(1).text().trim();
    if (!nameDiv) return;
    const posM = nameDiv.match(/\(([A-Z]{2})\)/);
    const player = {
      number: $(row).find('td').eq(0).text().trim().replace('#',''),
      name: nameDiv.replace(/\([A-Z]{2}\)/,'').trim(),
      position: posM ? posM[1] : 'MF',
      rating: parseInt($(row).find('td').eq(3).text().trim(), 10) || 0,
      stats: $(row).find('td').eq(2).text().trim()
    };
    if (isBench || startingXI.length >= 11) bench.push(player);
    else startingXI.push(player);
  });
  const avg = startingXI.length
    ? Math.round(startingXI.reduce((s, p) => s + p.rating, 0) / startingXI.length) : 0;
  return { avgRating: avg, startingXI, bench };
}

async function safeFetch(url, retries = 2, customHeaders = {}) {
  const ua = getRandomUserAgent();
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': ua, ...customHeaders } });
      if (res.ok) return res;
      if (i < retries) await sleep(500);
    } catch (e) {
      if (i < retries) await sleep(500);
    }
  }
  return null;
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function probs(r) {
  if (r < -10) return [60, 20, 20];
  if (r >  10) return [20, 20, 60];
  return [33, 34, 33];
}

function generateStakingOptions(home, away, rating, hp, ap, hOdds = null, dOdds = null, aOdds = null, primarySafe = null) {
  const isHomeFav = hp >= ap;
  const fav = isHomeFav ? home : away;
  const favOdds = isHomeFav ? hOdds : aOdds;

  const safeOdds = favOdds ? Math.max(1.15, +(favOdds * 0.70).toFixed(2)) : 1.25;
  const dnbOdds = favOdds ? Math.max(1.30, +(favOdds * 0.82).toFixed(2)) : 1.70;

  const safeLabel = primarySafe || `Safe: ${isHomeFav ? '1X' : 'X2'} (${fav} or Draw) (${safeOdds})`;

  return [
    safeLabel,
    `Value: ${fav} Draw No Bet (${dnbOdds})`,
    `Risky: ${fav} to WIN by 2+ Goals (2.85)`,
    `BTTS: Both Teams To Score - Yes (1.78)`,
    `Goals: Over 1.5 Total Goals (1.34)`
  ];
}

function makePrediction(home, away, rating, hp, dp, ap, hOdds = null, dOdds = null, aOdds = null, league = '', h2hSummary = null) {
  const isUCL = (league || '').toLowerCase().includes('champions league') || (league || '').toLowerCase().includes('ucl');

  let recommendation = '';
  let strategyAnalysis = '';
  let primarySafeOption = '';

  const hasOdds = hOdds !== null && aOdds !== null && hOdds > 0 && aOdds > 0;
  const oddsDiff = hasOdds ? (hOdds - aOdds) : 0;
  const isEvenOdds = hasOdds ? Math.abs(oddsDiff) <= 0.15 : Math.abs(hp - ap) <= 5;
  const isHomeUnderdog = hasOdds ? (hOdds >= aOdds + 1.50) : (hp + 15 <= ap);
  const isHomeFavorite = hasOdds ? (hOdds <= 1.50) : (hp >= ap + 25);

  // 1. Champions League Strategy
  if (isUCL) {
    const isLeg1 = (league || '').toLowerCase().includes('leg 1') || (league || '').toLowerCase().includes('1st leg');
    if (isLeg1) {
      recommendation = rating < 0 ? `${home} or Draw (1X)` : `${away} or Draw (X2)`;
      primarySafeOption = rating < 0 ? `Safe: 1X (${home} or Draw)` : `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `UCL Knockout Leg 1: Stalemate protection active (${recommendation}).`;
    } else {
      recommendation = `${home} or ${away} (Home or Away Win - 12)`;
      primarySafeOption = `Safe: 12 (${home} or ${away} Win)`;
      strategyAnalysis = `UCL Group Stage / Leg 2: Forced attacking scenario active (12).`;
    }
  } 
  // 2. Even Odds Rule (Check H2H)
  else if (isEvenOdds) {
    let hWins = 0, aWins = 0, draws = 0;
    if (h2hSummary) {
      const cleanH2H = h2hSummary.replace(/\s*\([\d\-,\s]+\)/g, '');
      const wonMatches = [...cleanH2H.matchAll(/([A-Za-z0-9\s\.\-]+?)\s+won\s+(\d+)/gi)];
      for (const m of wonMatches) {
        const tName = (m[1] || '').trim().toLowerCase();
        const count = parseInt(m[2] || '0', 10);
        if (tName.includes(home.toLowerCase()) || home.toLowerCase().includes(tName)) {
          hWins = count;
        } else if (tName.includes(away.toLowerCase()) || away.toLowerCase().includes(tName)) {
          aWins = count;
        }
      }
      const drawMatch = cleanH2H.match(/(\d+)\s+Draw/i);
      if (drawMatch) draws = parseInt(drawMatch[1] || '0', 10);
    }

    if (hWins > aWins) {
      recommendation = `${home} or Draw (1X)`;
      primarySafeOption = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Even Odds Fixture: H2H favors home team (${hWins} vs ${aWins} wins). Output 1X.`;
    } else if (aWins > hWins) {
      recommendation = `${away} or Draw (X2)`;
      primarySafeOption = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Even Odds Fixture: H2H favors away team (${aWins} vs ${hWins} wins). Output X2.`;
    } else {
      recommendation = `${home} or ${away} (Home or Away Win - 12)`;
      primarySafeOption = `Safe: 12 (${home} or ${away} Win)`;
      strategyAnalysis = `Even Odds Fixture: H2H is a dead tie. Output 12 (Force a decisive outcome).`;
    }
  }
  // 3. Home Favorite Rule (Home Odds <= 1.50)
  else if (isHomeFavorite) {
    recommendation = `${home} or Draw & Over 1.5 Goals (1X + Over 1.5)`;
    primarySafeOption = `Safe: 1X + Over 1.5 Goals (${home} or Draw & Over 1.5 Goals)`;
    strategyAnalysis = `Home Favorite (Odds <= 1.50): Compound market 1X + Over 1.5 Goals executed to preserve multiplier value.`;
  }
  // 4. Home Underdog Rule (Home Odds >= Away Odds + 1.50)
  else if (isHomeUnderdog) {
    const isVolatileLeague = (league || '').toLowerCase().includes('mls') || (league || '').toLowerCase().includes('bundesliga');
    if (isVolatileLeague) {
      recommendation = `${home} or ${away} (Home or Away Win - 12)`;
      primarySafeOption = `Safe: 12 (${home} or ${away} Win)`;
      strategyAnalysis = `Home Underdog Exception: Volatile league historical draw rate < 20%. Output 12 to capture volatility.`;
    } else {
      recommendation = `${away} or Draw (X2)`;
      primarySafeOption = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Home Underdog: Guarding against parked bus. Output X2.`;
    }
  }
  // 5. Default Market Rule
  else {
    if (rating < -5 || (hasOdds && hOdds < aOdds)) {
      recommendation = `${home} or Draw (1X)`;
      primarySafeOption = `Safe: 1X (${home} or Draw)`;
      strategyAnalysis = `Standard Market: Home team favored by market odds (Rating: ${rating}).`;
    } else if (rating > 5 || (hasOdds && aOdds < hOdds)) {
      recommendation = `${away} or Draw (X2)`;
      primarySafeOption = `Safe: X2 (${away} or Draw)`;
      strategyAnalysis = `Standard Market: Away team favored by market odds (Rating: ${rating}).`;
    } else {
      recommendation = `${home} or ${away} (Home or Away Win - 12)`;
      primarySafeOption = `Safe: 12 (${home} or ${away} Win)`;
      strategyAnalysis = `Standard Market: Balanced match, outputting double chance 12.`;
    }
  }

  return {
    homeWinProbability: hp,
    drawProbability: dp,
    awayWinProbability: ap,
    recommendation: recommendation,
    analysis: `${strategyAnalysis}\nOdds rating: ${rating}.`,
    stakingOptions: generateStakingOptions(home, away, rating, hp, ap, hOdds, dOdds, aOdds, primarySafeOption)
  };
}

function parseH2H($, homeTeam, awayTeam) {
  const clean = (s) => (s || '').toLowerCase().replace(/[\.\-\d\s]+/g, '').trim();
  const hClean = clean(homeTeam);
  const aClean = clean(awayTeam);
  if (!hClean || !aClean) return null;

  const pastMeetings = [];

  $('table').each((_, tbl) => {
    if (!$(tbl).text().includes('Res.')) return;

    $(tbl).find('tr').each((_, row) => {
      const tds = $(row).find('td');
      if (tds.length < 10) return;

      const teamsText = tds.eq(2).text().trim();
      const scoreText = tds.last().text().trim();
      if (!scoreText || !scoreText.includes(':')) return;

      const rowClean = clean(teamsText);
      if ((rowClean.includes(hClean) || hClean.includes(rowClean)) && 
          (rowClean.includes(aClean) || aClean.includes(rowClean))) {
        const dateText = tds.eq(1).text().trim();
        pastMeetings.push({
          date: dateText,
          teams: teamsText,
          score: scoreText.replace(':', '-')
        });
      }
    });
  });

  if (pastMeetings.length === 0) return null;

  let hWins = 0, aWins = 0, draws = 0;
  for (const m of pastMeetings) {
    const [s1, s2] = m.score.split('-').map(Number);
    const firstTeam = m.teams.split('-')[0].trim();
    const isHomeFirst = clean(firstTeam).includes(hClean);

    const hScore = isHomeFirst ? s1 : s2;
    const aScore = isHomeFirst ? s2 : s1;

    if (hScore > aScore) hWins++;
    else if (aScore > hScore) aWins++;
    else draws++;
  }

  return `${homeTeam} won ${hWins}, ${awayTeam} won ${aWins}, ${draws} Draw${draws === 1 ? '' : 's'} in last ${pastMeetings.length} meetings.`;
}

// ─── Phase 1: Homepage global picks ──────────────────────────────────────────
async function scrapeHomepage(matchesMap, nowMs) {
  const res = await safeFetch('https://soccer-rating.com');
  if (!res) { console.warn('Homepage fetch failed'); return; }
  const $ = cheerio.load(await res.text());

  $('table tr.clickrow').each((_, el) => {
    try {
      const link = $(el).attr('data-href');
      const td1 = $(el).find('td').eq(0);
      const td2 = $(el).find('td').eq(1);
      const td4 = $(el).find('td').eq(3);
      const teamsText = td1.text().replace('↓','').replace('↑','').trim();
      const parts = teamsText.split('-');
      const homeTeam = parts[0]?.trim();
      const awayTeam = parts.length > 1 ? parts[1]?.trim() : '';
      if (!homeTeam || !awayTeam) return;

      const flagImg = td2.find('img.flag-icon');
      const country = flagImg.attr('alt') || '';
      const flagSrc = flagImg.attr('src') || '';
      const flagUrl = flagSrc ? `https://soccer-rating.com${flagSrc.startsWith('/') ? flagSrc : '/'+flagSrc}` : '';
      const matchTimeTitle = flagImg.attr('title') || '';
      const fullLeagueName = formatLeagueName(td2.text().replace(/[\d\.]+/,'').trim(), country);
      const matchDateIso = parseMatchDate(matchTimeTitle);
      const matchDateMs = new Date(matchDateIso).getTime();
      // Keep matches from the last 48 hours (yesterday & today) plus upcoming
      if (matchDateMs && matchDateMs < nowMs - 48*60*60*1000) return;

      const rMatch = td4.text().replace(/\s+/,' ').trim().match(/([\-\d]+)\/([\-\d]+)/);
      const oddsRating = rMatch ? parseInt(rMatch[1],10) : 0;
      const [hp, dp, ap] = probs(oddsRating);
      const isLive = matchDateMs && matchDateMs <= nowMs && matchDateMs >= nowMs - 110*60*1000;
      const id = `${homeTeam}-${awayTeam}`.replace(/\s+/g,'-');

      matchesMap.set(id, {
        id, homeTeam, awayTeam,
        homeLogo: flagUrl, awayLogo: flagUrl,
        league: fullLeagueName,
        date: matchDateIso,
        status: isLive ? 'live' : 'notStarted',
        statusShort: isLive ? '1H' : 'NS',
        homeScore: 0, awayScore: 0,
        oddsRating, matchUrl: link,
        homeOdds: null, drawOdds: null, awayOdds: null,
        homeRank: null, awayRank: null,
        homeForm: '', homePoints: 0, awayForm: '', awayPoints: 0,
        homeLineup: null, awayLineup: null,
        h2hSummary: null,
        prediction: makePrediction(homeTeam, awayTeam, oddsRating, hp, dp, ap, null, null, null, fullLeagueName)
      });
    } catch(e) { /* skip */ }
  });
  console.log(`  Homepage: ${matchesMap.size} matches`);
}

// ─── Phase 2: Top 5 country pages ────────────────────────────────────────────
async function scrapeCountryPages(matchesMap) {
  const year = new Date().getUTCFullYear();
  for (const c of TOP_COUNTRIES) {
    const res = await safeFetch(c.url);
    if (!res) { console.warn(`Failed: ${c.country}`); await sleep(300); continue; }
    const $ = cheerio.load(await res.text());
    let added = 0;

    $('table').each((_, tbl) => {
      if (!$(tbl).text().includes('Available Odds')) return;
      $(tbl).find('tr').each((_, row) => {
        const tds = $(row).find('td');
        if (tds.length < 8) return;
        const dateParts = tds.eq(0).text().trim().match(/(\d{1,2})\/(\d{1,2})/);
        if (!dateParts) return;

        const homeLink = tds.eq(4).find('a');
        const awayLink = tds.eq(6).find('a');
        const homeTeam = homeLink.text().trim() || tds.eq(4).text().replace('↓','').replace('↑','').trim();
        const awayTeam = awayLink.text().trim() || tds.eq(6).text().replace('↓','').replace('↑','').trim();
        if (!homeTeam || !awayTeam) return;

        const hHref = homeLink.attr('href') || '';
        const aHref = awayLink.attr('href') || '';
        const hM = hHref.match(/\/([^\/]+)\/(\d+)\/?/);
        const aM = aHref.match(/\/([^\/]+)\/(\d+)\/?/);
        const matchUrl = hM && aM ? `/${hM[1]}-${aM[1]}/${hM[2]}/${aM[2]}/` : hHref || '';
        const oddsRating = parseInt(tds.eq(1).text().trim(), 10) || 0;
        const flagSrc = tds.eq(3).find('img').attr('src') || '';
        const flagUrl = flagSrc ? `https://soccer-rating.com${flagSrc.startsWith('/') ? flagSrc : '/'+flagSrc}` : '';
        const d = parseInt(dateParts[1],10);
        const mo = parseInt(dateParts[2],10) - 1;
        const matchDateIso = new Date(Date.UTC(year, mo, d, 19, 0)).toISOString();
        const [hp, dp, ap] = probs(oddsRating);
        const id = `${homeTeam}-${awayTeam}`.replace(/\s+/g,'-');

        const titleAttr = (tds.eq(0).attr('title') || '').trim();
        let status = 'notStarted';
        let statusShort = 'NS';
        let homeScore = 0;
        let awayScore = 0;

        const finishedMatch = titleAttr.match(/Finished\s+(\d+)\s*[:\-]\s*(\d+)/i);
        const liveMatch = titleAttr.match(/Live\s+(\d+)\s*[:\-]\s*(\d+)/i);

        if (finishedMatch) {
          status = 'finished';
          statusShort = 'FT';
          homeScore = parseInt(finishedMatch[1], 10);
          awayScore = parseInt(finishedMatch[2], 10);
        } else if (liveMatch) {
          status = 'live';
          statusShort = '1H';
          homeScore = parseInt(liveMatch[1], 10);
          awayScore = parseInt(liveMatch[2], 10);
        }

        if (!matchesMap.has(id)) {
          matchesMap.set(id, {
            id, homeTeam, awayTeam,
            homeLogo: flagUrl, awayLogo: flagUrl,
            league: c.defaultLeague, date: matchDateIso,
            status, statusShort,
            homeScore, awayScore,
            oddsRating, matchUrl, homeTeamUrl: hHref, awayTeamUrl: aHref,
            homeOdds: parseFloat(tds.eq(7).text()) || null,
            drawOdds: parseFloat(tds.eq(8).text()) || null,
            awayOdds: parseFloat(tds.eq(9).text()) || null,
            homeRank: null, awayRank: null,
            homeForm: '', homePoints: 0, awayForm: '', awayPoints: 0,
            homeLineup: null, awayLineup: null,
            h2hSummary: null,
            prediction: makePrediction(homeTeam, awayTeam, oddsRating, hp, dp, ap, parseFloat(tds.eq(7).text()) || null, parseFloat(tds.eq(8).text()) || null, parseFloat(tds.eq(9).text()) || null, c.defaultLeague)
          });
          added++;
        }
      });
    });
    console.log(`  ${c.country}: +${added} new matches`);
    await sleep(200);
  }
}

// ─── Phase 3: Deep-scrape ALL match pages for lineups + form ─────────────────
async function deepScrapeAll(matches) {
  const todayIso = new Date().toISOString().substring(0,10);
  const PRIORITY = ['Premier League','La Liga','Serie A','Bundesliga','Ligue 1','Champions League','Europa League','Copa Libertadores'];

  matches.sort((a, b) => {
    const at = (a.date||'').startsWith(todayIso) ? 0 : 1;
    const bt = (b.date||'').startsWith(todayIso) ? 0 : 1;
    if (at !== bt) return at - bt;
    const ap = PRIORITY.some(k => a.league.includes(k)) ? 0 : 1;
    const bp = PRIORITY.some(k => b.league.includes(k)) ? 0 : 1;
    return ap - bp;
  });

  const withMatchUrl = matches.filter(m => !!m.matchUrl && (!m.homeLineup?.startingXI?.length));
  console.log(`  Deep scraping ${withMatchUrl.length} match pages (skipping ${matches.filter(m => m.homeLineup?.startingXI?.length).length} already cached)...`);

  const BATCH = 8;
  for (let i = 0; i < withMatchUrl.length; i += BATCH) {
    const batch = withMatchUrl.slice(i, i + BATCH);
    await Promise.all(batch.map(async (match) => {
      const url = `https://soccer-rating.com${match.matchUrl.startsWith('/') ? match.matchUrl : '/'+match.matchUrl}`;
      const res = await safeFetch(url);
      if (!res) return;
      const html = await res.text();
      const $ = cheerio.load(html);

      // Extract exact match kickoff time from JSON-LD schema
      const startDateMatch = html.match(/"startDate":\s*"([^"]+)"/);
      if (startDateMatch && startDateMatch[1]) {
        try {
          const parsedDate = new Date(startDateMatch[1]);
          if (!isNaN(parsedDate.getTime())) {
            match.date = parsedDate.toISOString();
          }
        } catch (_) {}
      }

      const fm = html.match(/Form Last 3 Games[\s\S]*?(\d+)\s*P[^\(]*\(([WDL]+)\)[\s\S]*?(\d+)\s*P[^\(]*\(([WDL]+)\)/i);
      if (fm) {
        match.homePoints = parseInt(fm[1],10); match.homeForm = fm[2];
        match.awayPoints = parseInt(fm[3],10); match.awayForm = fm[4];
        match.prediction.analysis = `Odds rating: ${match.oddsRating}.\nHome Form: ${match.homeForm} (${match.homePoints} pts)\nAway Form: ${match.awayForm} (${match.awayPoints} pts)`;
      }

      // Extract League Rank / Position
      const rankRegex = /([A-Za-z0-9\.\s\-]+)\s+is ranked #(\d+)/gi;
      let rm;
      while ((rm = rankRegex.exec(html)) !== null) {
        const tName = rm[1].trim().toLowerCase();
        const rNum = parseInt(rm[2], 10);
        if (tName.includes(match.homeTeam.toLowerCase()) || match.homeTeam.toLowerCase().includes(tName)) {
          match.homeRank = rNum;
        } else if (tName.includes(match.awayTeam.toLowerCase()) || match.awayTeam.toLowerCase().includes(tName)) {
          match.awayRank = rNum;
        }
      }
      if (!match.homeRank) {
        const singleRank = html.match(/is ranked #(\d+) in/i);
        if (singleRank) match.homeRank = parseInt(singleRank[1], 10);
      }
      const home = parseLineupTable($, '#line1');
      const away = parseLineupTable($, '#line2');
      if (home.startingXI.length > 0) { match.homeLineup = home; match.awayLineup = away; }

      // Parse Head-to-Head past meetings
      const h2h = parseH2H($, match.homeTeam, match.awayTeam);
      if (h2h) {
        match.h2hSummary = h2h;
      }

      // Re-generate prediction with full H2H and league context
      match.prediction = makePrediction(
        match.homeTeam,
        match.awayTeam,
        match.oddsRating,
        match.prediction.homeWinProbability,
        match.prediction.drawProbability,
        match.prediction.awayWinProbability,
        match.homeOdds,
        match.drawOdds,
        match.awayOdds,
        match.league,
        match.h2hSummary
      );
    }));
    process.stdout.write(`    [${i+batch.length}/${withMatchUrl.length}] ✓\n`);
    await sleep(100);
  }

  // Fallback: team pages for any match still missing lineups
  const noLineup = matches.filter(m => !m.homeLineup?.startingXI?.length && m.homeTeamUrl && m.awayTeamUrl);
  if (noLineup.length > 0) {
    console.log(`  Team-page fallback for ${noLineup.length} matches...`);
    for (let i = 0; i < noLineup.length; i += BATCH) {
      const batch = noLineup.slice(i, i + BATCH);
      await Promise.all(batch.map(async (match) => {
        const hUrl = `https://soccer-rating.com${match.homeTeamUrl.startsWith('/') ? match.homeTeamUrl : '/'+match.homeTeamUrl}`;
        const aUrl = `https://soccer-rating.com${match.awayTeamUrl.startsWith('/') ? match.awayTeamUrl : '/'+match.awayTeamUrl}`;
        const [hRes, aRes] = await Promise.all([safeFetch(hUrl), safeFetch(aUrl)]);
        if (hRes) { const $h = cheerio.load(await hRes.text()); match.homeLineup = parseLineupTable($h, '#line1'); }
        if (aRes) { const $a = cheerio.load(await aRes.text()); match.awayLineup = parseLineupTable($a, '#line1'); }
      }));
      await sleep(100);
    }
  }
}

// ─── Phase 4: Live & Recent Scores Engine ────────────────────────────────────
function cleanTeamName(name) {
  if (!name) return '';
  return name
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\b(fc|cf|sc|afc|ac|as|cd|sv|fsv|mfk|de|la|the|club|calcio)\b/gi, '')
    .replace(/[^a-z0-9]/g, '')
    .trim();
}

function teamsMatch(a, b) {
  const cA = cleanTeamName(a);
  const cB = cleanTeamName(b);
  if (!cA || !cB) return false;
  if (cA === cB) return true;
  if (cA.length >= 4 && cB.length >= 4) {
    if (cA.includes(cB) || cB.includes(cA)) return true;
  }
  return false;
}

async function fetchEspnScoresForDate(dateStr = '') {
  try {
    const url = dateStr 
      ? `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=${dateStr}`
      : `https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel`;
    const res = await safeFetch(url, 2);
    if (!res) return [];
    const data = await res.json();
    const scores = data.scores || [];
    const eventsList = [];

    for (const block of scores) {
      const league = block.leagues?.[0]?.name || 'International League';
      for (const ev of (block.events || [])) {
        const comp = ev.competitions?.[0];
        if (!comp) continue;
        const home = comp.competitors?.find(c => c.homeAway === 'home');
        const away = comp.competitors?.find(c => c.homeAway === 'away');
        if (!home || !away) continue;

        const statusObj = ev.status || comp.status || {};
        const type = statusObj.type || {};
        const state = type.state || ''; // 'pre', 'in', 'post'
        const completed = type.completed || state === 'post';
        const detail = type.shortDetail || type.detail || (completed ? 'FT' : '');

        const homeScore = (home.score !== undefined && home.score !== null && home.score !== '') ? parseInt(home.score, 10) : null;
        const awayScore = (away.score !== undefined && away.score !== null && away.score !== '') ? parseInt(away.score, 10) : null;

        eventsList.push({
          homeName: home.team?.displayName || home.team?.name || '',
          awayName: away.team?.displayName || away.team?.name || '',
          homeLogo: home.team?.logo || '',
          awayLogo: away.team?.logo || '',
          league,
          homeScore,
          awayScore,
          completed,
          state,
          detail,
          date: ev.date
        });
      }
    }
    return eventsList;
  } catch (e) {
    console.warn(`ESPN score fetch error (${dateStr}):`, e.message);
    return [];
  }
}

const SPORTS_API_KEY = process.env.SPORTS_API_KEY || '3d923c01afee89b7b9ae92761979ef56';

async function fetchApiSportsEventsForDate(dateIsoStr) {
  if (!SPORTS_API_KEY) return [];
  try {
    const url = `https://v3.football.api-sports.io/fixtures?date=${dateIsoStr}`;
    const res = await safeFetch(url, 2, { 'x-apisports-key': SPORTS_API_KEY });
    if (!res) return [];
    const data = await res.json();
    const fixtures = data.response || [];
    const events = [];

    for (const f of fixtures) {
      const home = f.teams?.home;
      const away = f.teams?.away;
      if (!home || !away) continue;

      const sShort = f.fixture?.status?.short || '';
      const isFinished = ['FT', 'AET', 'PEN'].includes(sShort);
      const isLive = ['1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE'].includes(sShort);

      events.push({
        homeName: home.name || '',
        awayName: away.name || '',
        homeLogo: home.logo || '',
        awayLogo: away.logo || '',
        league: `${f.league?.country ? f.league.country + ' - ' : ''}${f.league?.name || 'Soccer'}`,
        homeScore: f.goals?.home !== null && f.goals?.home !== undefined ? f.goals.home : null,
        awayScore: f.goals?.away !== null && f.goals?.away !== undefined ? f.goals.away : null,
        completed: isFinished,
        state: isFinished ? 'post' : (isLive ? 'in' : 'pre'),
        detail: sShort || (isFinished ? 'FT' : ''),
        date: f.fixture?.date
      });
    }
    return events;
  } catch (e) {
    console.warn(`API-Sports error for ${dateIsoStr}:`, e.message);
    return [];
  }
}

async function fetchAllLiveAndRecentScores() {
  console.log('\nFetching live & recent match scores (today & yesterday)...');
  const now = new Date();
  const todayYmd = now.toISOString().slice(0, 10);
  const todayStr = todayYmd.replace(/-/g, '');
  const yesterdayDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const yesterdayYmd = yesterdayDate.toISOString().slice(0, 10);
  const yesterdayStr = yesterdayYmd.replace(/-/g, '');

  // 1. Primary: API-Sports (works reliably on GitHub Actions cloud runners)
  let todayEvents = await fetchApiSportsEventsForDate(todayYmd);
  let yesterdayEvents = await fetchApiSportsEventsForDate(yesterdayYmd);
  console.log(`  API-Sports: ${todayEvents.length} today, ${yesterdayEvents.length} yesterday`);

  // 2. Fallback / supplementary: ESPN
  if (todayEvents.length === 0 || yesterdayEvents.length === 0) {
    console.log('  Checking ESPN for additional/fallback scores...');
    const [espnLive, espnToday, espnYest] = await Promise.all([
      fetchEspnScoresForDate(''),
      fetchEspnScoresForDate(todayStr),
      fetchEspnScoresForDate(yesterdayStr)
    ]);
    if (todayEvents.length === 0) todayEvents = [...espnLive, ...espnToday];
    if (yesterdayEvents.length === 0) yesterdayEvents = espnYest;
  }

  const allEvents = [...todayEvents, ...yesterdayEvents];
  console.log(`  Retrieved ${allEvents.length} total score events (${yesterdayEvents.length} yesterday)`);
  return { allEvents, yesterdayEvents };
}

function applyScoresToMatches(matches, scoreEvents, yesterdayEvents = []) {
  let updatedCount = 0;
  for (const match of matches) {
    const matched = scoreEvents.find(ev =>
      teamsMatch(match.homeTeam, ev.homeName) && teamsMatch(match.awayTeam, ev.awayName)
    );

    if (matched) {
      if (matched.homeScore !== null && matched.awayScore !== null) {
        match.homeScore = matched.homeScore;
        match.awayScore = matched.awayScore;
      }

      if (matched.completed) {
        match.status = 'finished';
        match.statusShort = matched.detail || 'FT';
      } else if (matched.state === 'in') {
        match.status = 'live';
        match.statusShort = matched.detail || 'LIVE';
      }
      updatedCount++;
    }
  }
  console.log(`  Applied real-time scores to ${updatedCount} matches`);

  // Ensure yesterday's finished matches are included so the user can always see yesterday's results
  let addedYest = 0;
  for (const ev of yesterdayEvents) {
    if (!ev.completed || ev.homeScore === null || ev.awayScore === null) continue;
    const exists = matches.some(m =>
      teamsMatch(m.homeTeam, ev.homeName) && teamsMatch(m.awayTeam, ev.awayName)
    );
    if (!exists && ev.homeName && ev.awayName) {
      const id = `${ev.homeName}-${ev.awayName}`.replace(/\s+/g, '-');
      matches.push({
        id,
        homeTeam: ev.homeName,
        awayTeam: ev.awayName,
        homeLogo: ev.homeLogo || '',
        awayLogo: ev.awayLogo || '',
        league: ev.league || 'International League',
        date: ev.date,
        status: 'finished',
        statusShort: ev.detail || 'FT',
        homeScore: ev.homeScore,
        awayScore: ev.awayScore,
        oddsRating: 0,
        matchUrl: null,
        homeOdds: null, drawOdds: null, awayOdds: null,
        homeRank: null, awayRank: null,
        homeForm: '', homePoints: 0, awayForm: '', awayPoints: 0,
        homeLineup: null, awayLineup: null,
        h2hSummary: null,
        prediction: makePrediction(ev.homeName, ev.awayName, 0, 33, 34, 33)
      });
      addedYest++;
    }
  }
  if (addedYest > 0) {
    console.log(`  Backfilled ${addedYest} completed matches from yesterday to guarantee yesterday's results`);
  }
}

// ─── Cloudflare KV Helpers ───────────────────────────────────────────────────
async function getExistingKVMatches() {
  if (!CF_ACCOUNT_ID || !CF_API_TOKEN || !CF_KV_NS_ID) return [];
  try {
    const url = `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${CF_KV_NS_ID}/values/${KV_KEY}`;
    const res = await safeFetch(url, 1, { 'Authorization': `Bearer ${CF_API_TOKEN}` });
    if (!res) return [];
    const json = await res.json();
    return json?.matchesData?.matches || [];
  } catch (e) {
    console.warn('Could not read existing KV data:', e.message);
    return [];
  }
}

async function pushToCloudflareKV(data) {
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

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  if (!CF_ACCOUNT_ID || !CF_API_TOKEN || !CF_KV_NS_ID) {
    console.error('Missing CF_ACCOUNT_ID, CF_API_TOKEN, or CF_KV_NAMESPACE_ID env vars');
    process.exit(1);
  }

  console.log('Starting GitHub Actions scraper (incremental + live scores)...');
  const nowMs = Date.now();
  const matchesMap = new Map();

  // 1. Fetch existing matches from Cloudflare KV
  console.log('\nFetching existing KV matches for incremental merge...');
  const existingMatches = await getExistingKVMatches();
  console.log(`  Found ${existingMatches.length} matches in current KV store`);

  // 2. Scrape fresh picks from homepage
  console.log('\nPhase 1: Scraping homepage (global daily picks)...');
  await scrapeHomepage(matchesMap, nowMs);

  // 3. Scrape Top 5 country pages
  console.log('\nPhase 2: Scraping Top 5 country pages...');
  await scrapeCountryPages(matchesMap);

  // 4. Merge with existing KV matches (keep yesterday & today results, preserve lineups & ranks)
  const cutoffMs = nowMs - 48 * 60 * 60 * 1000;
  let preservedCount = 0;
  for (const ex of existingMatches) {
    const dMs = new Date(ex.date).getTime();
    if (dMs && dMs >= cutoffMs) {
      if (!matchesMap.has(ex.id)) {
        matchesMap.set(ex.id, ex);
        preservedCount++;
      } else {
        const current = matchesMap.get(ex.id);
        if (!current.homeLineup && ex.homeLineup) current.homeLineup = ex.homeLineup;
        if (!current.awayLineup && ex.awayLineup) current.awayLineup = ex.awayLineup;
        if (!current.homeRank && ex.homeRank) current.homeRank = ex.homeRank;
        if (!current.awayRank && ex.awayRank) current.awayRank = ex.awayRank;
        if (!current.h2hSummary && ex.h2hSummary) current.h2hSummary = ex.h2hSummary;
        if (ex.status === 'finished') {
          current.status = 'finished';
          current.statusShort = ex.statusShort || 'FT';
          current.homeScore = ex.homeScore;
          current.awayScore = ex.awayScore;
        }
      }
    }
  }
  console.log(`  Preserved ${preservedCount} existing/yesterday matches from previous runs`);

  let matches = Array.from(matchesMap.values());
  console.log(`\nTotal: ${matches.length} matches across ${new Set(matches.map(m => m.league)).size} leagues`);
  const dates = [...new Set(matches.map(m => m.date.substring(0, 10)))].sort();
  console.log('Dates included:', dates.join(', '));

  // 5. Deep-scrape match pages only for matches that need lineups
  console.log('\nPhase 3: Deep-scraping uncached match pages...');
  await deepScrapeAll(matches);

  const withLineups = matches.filter(m => m.homeLineup?.startingXI?.length > 0).length;
  console.log(`\nLineup coverage: ${withLineups}/${matches.length} matches`);

  // 6. Fetch live & recent scores from ESPN and update scores & statuses
  try {
    const { allEvents, yesterdayEvents } = await fetchAllLiveAndRecentScores();
    applyScoresToMatches(matches, allEvents, yesterdayEvents);
  } catch (err) {
    console.warn('Live score fetching failed, proceeding with current data:', err.message);
  }

  // 7. Push updated data to Cloudflare KV
  const finalData = JSON.stringify({
    matchesData: { lastUpdated: new Date().toISOString(), scrapedBy: 'github-actions', matches },
    standingsData: null
  });

  console.log('\nPhase 5: Pushing updated matches + scores to Cloudflare KV...');
  await pushToCloudflareKV(finalData);
  console.log(`Done! ${matches.length} matches live in KV.`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
