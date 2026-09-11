import * as cheerio from 'cheerio';

// Test the Bayern team page as a fallback for lineup data
async function checkTeamPageLineup() {
  // This is what a match page URL looks like:
  const matchPageUrl = 'https://soccer-rating.com/Sevilla-FC-FC-Valencia/1061/1073/';
  // This is what the team page URL looks like:
  const homeTeamUrl = 'https://soccer-rating.com/Sevilla-FC/1061/';
  const awayTeamUrl = 'https://soccer-rating.com/FC-Valencia/1073/';

  for (const [name, url] of [['Match Page', matchPageUrl], ['Sevilla Team Page', homeTeamUrl], ['Valencia Team Page', awayTeamUrl]]) {
    const res = await fetch(url);
    const html = await res.text();
    const $ = cheerio.load(html);
    const line1Trs = $('#line1 tr').length;
    const line2Trs = $('#line2 tr').length;
    const samplePlayer = $('#line1 tr').first().text().trim().substring(0, 80);
    console.log(`\n[${name}] ${url}`);
    console.log(`  #line1 rows: ${line1Trs}, #line2 rows: ${line2Trs}`);
    console.log(`  Sample: ${samplePlayer}`);
  }
}
checkTeamPageLineup();
