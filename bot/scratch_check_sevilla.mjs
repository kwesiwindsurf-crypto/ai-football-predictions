import * as cheerio from 'cheerio';

async function checkSevilla() {
  const url = 'https://soccer-rating.com/Sevilla-FC-FC-Valencia/1061/1073/';
  const res = await fetch(url);
  const html = await res.text();
  const $ = cheerio.load(html);

  console.log('#line1 tr count:', $('#line1 tr').length);
  $('#line1 tr').each((i, row) => {
    console.log(`Row ${i}: tds=${$(row).find('td').length} html=${$(row).html()?.substring(0, 100)}`);
  });
}
checkSevilla();
