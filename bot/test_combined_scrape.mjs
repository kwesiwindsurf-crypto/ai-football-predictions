import * as cheerio from 'cheerio';

const TOP_COUNTRIES = [
  { country: 'Spain', defaultLeague: 'Spain - La Liga', url: 'https://soccer-rating.com/Spain/' },
  { country: 'France', defaultLeague: 'France - Ligue 1', url: 'https://soccer-rating.com/France/' },
  { country: 'Germany', defaultLeague: 'Germany - Bundesliga', url: 'https://soccer-rating.com/Germany/' },
  { country: 'Italy', defaultLeague: 'Italy - Serie A', url: 'https://soccer-rating.com/Italy/' },
  { country: 'England', defaultLeague: 'England - Premier League', url: 'https://soccer-rating.com/England/' }
];

function parseCountryTable(html, countryName, defaultLeague) {
  const $ = cheerio.load(html);
  const matches = [];

  let matchCount = 0;
  $('table').each((i, tbl) => {
    const text = $(tbl).text();
    if (!text.includes('Available Odds')) return;

    const trs = $(tbl).find('tr');
    console.log(`[${countryName}] Table ${i} has "Available Odds", trs: ${trs.length}`);

    trs.each((j, row) => {
      const tds = $(row).find('td');
      if (tds.length < 8) return;

      const dateStr = tds.eq(0).text().trim();
      const dateParts = dateStr.match(/(\d{1,2})\/(\d{1,2})/);
      if (!dateParts) return;

      const ratingStr = tds.eq(1).text().trim();
      const oddsRating = parseInt(ratingStr, 10) || 0;
      const leagueCode = tds.eq(2).text().trim();
      const flagSrc = tds.eq(3).find('img').attr('src') || '';
      const flagUrl = flagSrc ? `https://soccer-rating.com${flagSrc.startsWith('/') ? flagSrc : '/' + flagSrc}` : '';

      const homeTeam = tds.eq(4).find('a').text().trim() || tds.eq(4).text().replace('↓','').replace('↑','').trim();
      const awayTeam = tds.eq(6).find('a').text().trim() || tds.eq(6).text().replace('↓','').replace('↑','').trim();
      const matchUrl = tds.eq(4).find('a').attr('href') || tds.eq(6).find('a').attr('href') || '';

      const hOdds = parseFloat(tds.eq(7).text().trim()) || null;
      const dOdds = parseFloat(tds.eq(8).text().trim()) || null;
      const aOdds = parseFloat(tds.eq(9).text().trim()) || null;

      if (!homeTeam || !awayTeam) return;

      const d = parseInt(dateParts[1], 10);
      const m = parseInt(dateParts[2], 10) - 1;
      const matchDateIso = new Date(Date.UTC(2026, m, d, 19, 0)).toISOString();

      let homeProb = 33;
      let awayProb = 33;
      let drawProb = 34;
      if (oddsRating < -10) {
        homeProb = 60; awayProb = 20; drawProb = 20;
      } else if (oddsRating > 10) {
        awayProb = 60; homeProb = 20; drawProb = 20;
      }

      matches.push({
        id: `${homeTeam}-${awayTeam}`.replace(/\s+/g, '-'),
        homeTeam,
        awayTeam,
        homeLogo: flagUrl,
        awayLogo: flagUrl,
        league: defaultLeague,
        date: matchDateIso,
        status: 'notStarted',
        statusShort: 'NS',
        homeScore: 0,
        awayScore: 0,
        oddsRating,
        homeOdds: hOdds,
        drawOdds: dOdds,
        awayOdds: aOdds,
        matchUrl,
        homeForm: '',
        homePoints: 0,
        awayForm: '',
        awayPoints: 0,
        homeLineup: null,
        awayLineup: null,
        prediction: {
          homeWinProbability: homeProb,
          drawProbability: drawProb,
          awayWinProbability: awayProb,
          recommendation: oddsRating < -5 ? `${homeTeam} to WIN (Value)` : (oddsRating > 5 ? `${awayTeam} to WIN (Value)` : 'Draw'),
          analysis: `Odds rating: ${oddsRating}. Calculated 1X2 odds: ${hOdds || '-'} / ${dOdds || '-'} / ${aOdds || '-'}.`,
          stakingOptions: [`Value Bet based on Rating: ${oddsRating}`]
        }
      });
    });
  });

  return matches;
}

async function test() {
  console.log('Fetching main page + 5 top countries with pacing...');
  const start = Date.now();
  // Fetch main page first, then countries sequentially with 150ms delay to respect server concurrency
  const mainRes = await fetch('https://soccer-rating.com');
  const mainHtml = await mainRes.text();

  const countryHtmlList = [];
  const countryResList = [];
  for (const c of TOP_COUNTRIES) {
    let res = await fetch(c.url);
    if (res.status !== 200) {
      await new Promise(r => setTimeout(r, 300));
      res = await fetch(c.url);
    }
    countryResList.push(res);
    countryHtmlList.push(await res.text());
    await new Promise(r => setTimeout(r, 150));
  }

  console.log(`Fetched all 6 pages in ${Date.now() - start}ms`);

  const allMatchesMap = new Map();

  for (let i = 0; i < TOP_COUNTRIES.length; i++) {
    console.log(`Fetch result for ${TOP_COUNTRIES[i].country}: status=${countryResList[i].status}, htmlLen=${countryHtmlList[i].length}`);
    const cMatches = parseCountryTable(countryHtmlList[i], TOP_COUNTRIES[i].country, TOP_COUNTRIES[i].defaultLeague);
    console.log(`Parsed ${TOP_COUNTRIES[i].country}: ${cMatches.length} matches`);
    for (const m of cMatches) {
      allMatchesMap.set(m.id, m);
    }
  }

  console.log(`Total unique matches from top 5 leagues: ${allMatchesMap.size}`);

  const dates = new Set();
  for (const m of allMatchesMap.values()) {
    dates.add(m.date.substring(0, 10));
  }
  console.log('Available Dates across Top 5 Leagues:', Array.from(dates).sort());

  console.log('\nMatches for TODAY (2026-09-11):');
  for (const m of allMatchesMap.values()) {
    if (m.date.startsWith('2026-09-11')) {
      console.log(`- ${m.league}: ${m.homeTeam} vs ${m.awayTeam}`);
    }
  }
}

test();
