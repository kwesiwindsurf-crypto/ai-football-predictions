import * as cheerio from 'cheerio';

async function check() {
  const res = await fetch('https://soccer-rating.com/Spain/');
  const html = await res.text();
  const $ = cheerio.load(html);

  $('table').each((i, tbl) => {
    if (!$(tbl).text().includes('Available Odds')) return;
    $(tbl).find('tr').each((j, row) => {
      const tds = $(row).find('td');
      if (tds.length < 8) return;
      const hLink = tds.eq(4).find('a');
      const aLink = tds.eq(6).find('a');
      console.log('Row', j, 'hLink:', hLink.attr('href'), '| aLink:', aLink.attr('href'), '| text:', hLink.text(), 'vs', aLink.text());
    });
  });
}
check();
