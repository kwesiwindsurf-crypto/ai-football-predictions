import * as cheerio from 'cheerio';

async function testMatchUrl() {
  const url = 'https://soccer-rating.com/Sevilla-FC-FC-Valencia/1061/1073/';
  const res = await fetch(url);
  console.log('Status for /Sevilla-FC-FC-Valencia/1061/1073/:', res.status);
  const html = await res.text();
  console.log('Length:', html.length);
  const $ = cheerio.load(html);
  console.log('Lineup table #line1 rows:', $('#line1 tr').length);
  console.log('Lineup table #line2 rows:', $('#line2 tr').length);
  console.log('Title:', $('title').text());
}
testMatchUrl();
