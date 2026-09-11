import * as cheerio from 'cheerio';

async function testTodayMatchUrls() {
  const matches = [
    { name: 'Sevilla vs Valencia', url: 'https://soccer-rating.com/Sevilla-FC-FC-Valencia/1061/1073/' },
    { name: 'Rennes vs Marseille', url: 'https://soccer-rating.com/Stade-Rennes-Olympique-Marseille/1083/1084/' },
    { name: 'Union Berlin vs Schalke', url: 'https://soccer-rating.com/1.-FC-Union-Berlin-FC-Schalke-04/1879/1012/' },
    { name: 'Venezia vs Fiorentina', url: 'https://soccer-rating.com/SSC-Venezia-AC-Fiorentina/2311/1020/' }
  ];

  for (const m of matches) {
    const res = await fetch(m.url);
    console.log(m.name, 'Status:', res.status);
    if (res.status === 200) {
      const html = await res.text();
      const $ = cheerio.load(html);
      console.log('  #line1 rows:', $('#line1 tr').length, '#line2 rows:', $('#line2 tr').length);
      const form = html.match(/Form Last 3 Games[\s\S]*?(\d+)\s*P[^\(]*\(([WDL]+)\)[\s\S]*?(\d+)\s*P[^\(]*\(([WDL]+)\)/i);
      console.log('  Form found:', !!form);
    }
  }
}
testTodayMatchUrls();
