import * as cheerio from 'cheerio';

async function checkTeamPage() {
  // Team page pattern
  const url = 'https://soccer-rating.com/FC-Bayern-Muenchen/151/';
  const res = await fetch(url);
  const html = await res.text();
  const $ = cheerio.load(html);
  console.log('Title:', $('title').text());
  console.log('#line1 tr count:', $('#line1 tr').length);
  console.log('#line2 tr count:', $('#line2 tr').length);

  // Look for links to matches on team page
  const matchLinks = [];
  $('a[href]').each((i, el) => {
    const href = $(el).attr('href');
    if (href && href.match(/\/[^\/]+-[^\/]+\/\d+\/\d+\//)) {
      matchLinks.push(href);
    }
  });
  console.log('\nMatch-pattern links on team page (max 10):');
  matchLinks.slice(0, 10).forEach(l => console.log(' ', l));

  // Check what #line1 actually contains
  console.log('\n#line1 HTML sample:');
  const line1 = $('#line1');
  if (line1.length) {
    console.log(line1.html()?.substring(0, 500));
  } else {
    console.log('(no #line1 found)');
    // Search for next match lineup section
    $('table').each((i, t) => {
      const txt = $(t).text();
      if (txt.includes('GK') || txt.includes('Starting') || txt.includes('Lineup')) {
        console.log(`Table ${i} seems to have lineup info:`, txt.substring(0, 200));
      }
    });
  }
}
checkTeamPage();
