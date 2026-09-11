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

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36';

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
  return new Date(Date.UTC(new Date().getUTCFullYear(), +m[2]-1, +m[1], +m[3], +m[4])).toISOString();
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

async function safeFetch(url, retries = 2) {
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, { headers: { 'User-Agent': UA } });
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

function makePrediction(home, away, rating, hp, dp, ap) {
  return {
    homeWinProbability: hp,
    drawProbability: dp,
    awayWinProbability: ap,
    recommendation: rating < -5 ? `${home} to WIN (Value)` : rating > 5 ? `${away} to WIN (Value)` : 'Draw',
    analysis: `Scraped odds rating: ${rating}. Negative favors home, positive favors away.`,
    stakingOptions: [`Value Bet based on Rating: ${rating}`]
  };
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
      if (matchDateMs && matchDateMs < nowMs - 110*60*1000) return;

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
        status: isLive ? 'inPlay' : 'notStarted',
        statusShort: isLive ? '1H' : 'NS',
        homeScore: 0, awayScore: 0,
        oddsRating, matchUrl: link,
        homeTeamUrl: '', awayTeamUrl: '',
        homeForm: '', homePoints: 0, awayForm: '', awayPoints: 0,
        homeLineup: null, awayLineup: null,
        prediction: makePrediction(homeTeam, awayTeam, oddsRating, hp, dp, ap)
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

        if (!matchesMap.has(id)) {
          matchesMap.set(id, {
            id, homeTeam, awayTeam,
            homeLogo: flagUrl, awayLogo: flagUrl,
            league: c.defaultLeague, date: matchDateIso,
            status: 'notStarted', statusShort: 'NS',
            homeScore: 0, awayScore: 0,
            oddsRating, matchUrl, homeTeamUrl: hHref, awayTeamUrl: aHref,
            homeOdds: parseFloat(tds.eq(7).text()) || null,
            drawOdds: parseFloat(tds.eq(8).text()) || null,
            awayOdds: parseFloat(tds.eq(9).text()) || null,
            homeForm: '', homePoints: 0, awayForm: '', awayPoints: 0,
            homeLineup: null, awayLineup: null,
            prediction: makePrediction(homeTeam, awayTeam, oddsRating, hp, dp, ap)
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

  const withMatchUrl = matches.filter(m => !!m.matchUrl);
  console.log(`  Deep scraping ${withMatchUrl.length} match pages...`);

  const BATCH = 8;
  for (let i = 0; i < withMatchUrl.length; i += BATCH) {
    const batch = withMatchUrl.slice(i, i + BATCH);
    await Promise.all(batch.map(async (match) => {
      const url = `https://soccer-rating.com${match.matchUrl.startsWith('/') ? match.matchUrl : '/'+match.matchUrl}`;
      const res = await safeFetch(url);
      if (!res) return;
      const html = await res.text();
      const $ = cheerio.load(html);

      const fm = html.match(/Form Last 3 Games[\s\S]*?(\d+)\s*P[^\(]*\(([WDL]+)\)[\s\S]*?(\d+)\s*P[^\(]*\(([WDL]+)\)/i);
      if (fm) {
        match.homePoints = parseInt(fm[1],10); match.homeForm = fm[2];
        match.awayPoints = parseInt(fm[3],10); match.awayForm = fm[4];
        match.prediction.analysis = `Odds rating: ${match.oddsRating}.\nHome Form: ${match.homeForm} (${match.homePoints} pts)\nAway Form: ${match.awayForm} (${match.awayPoints} pts)`;
      }
      const home = parseLineupTable($, '#line1');
      const away = parseLineupTable($, '#line2');
      if (home.startingXI.length > 0) { match.homeLineup = home; match.awayLineup = away; }
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

// ─── Phase 4: Push to Cloudflare KV ──────────────────────────────────────────
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

  console.log('Starting GitHub Actions full scraper...');
  const nowMs = Date.now();
  const matchesMap = new Map();

  console.log('\nPhase 1: Scraping homepage (global daily picks)...');
  await scrapeHomepage(matchesMap, nowMs);

  console.log('\nPhase 2: Scraping Top 5 country pages...');
  await scrapeCountryPages(matchesMap);

  let matches = Array.from(matchesMap.values());
  console.log(`\nTotal: ${matches.length} matches across ${new Set(matches.map(m=>m.league)).size} leagues`);
  const dates = [...new Set(matches.map(m => m.date.substring(0,10)))].sort();
  console.log('Dates:', dates.join(', '));

  console.log('\nPhase 3: Deep-scraping all match pages...');
  await deepScrapeAll(matches);

  const withLineups = matches.filter(m => m.homeLineup?.startingXI?.length > 0).length;
  console.log(`\nLineup coverage: ${withLineups}/${matches.length} matches`);

  const finalData = JSON.stringify({
    matchesData: { lastUpdated: new Date().toISOString(), scrapedBy: 'github-actions', matches },
    standingsData: null
  });

  console.log('\nPhase 4: Pushing to Cloudflare KV...');
  await pushToCloudflareKV(finalData);
  console.log(`Done! ${matches.length} matches live.`);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
