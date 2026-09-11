import * as cheerio from 'cheerio';

async function go() {
  const res = await fetch('https://soccer-rating.com/Sevilla-FC/1061/');
  const html = await res.text();
  const $ = cheerio.load(html);
  const players = [];
  $('#line1 tr').each((i, row) => {
    const name = $(row).find('div.nomobil').text().trim();
    if (name) players.push(name);
  });
  console.log(`Sevilla lineup (${players.length} players):`);
  if (players.length > 0) {
    players.forEach(p => console.log(' -', p));
  } else {
    console.log('  (No players published yet - squad announcement pending)');
    // Show raw HTML of #line1 to confirm it's blank placeholders
    console.log('Raw sample:', $('#line1 tr').first().html());
  }
}
go();
