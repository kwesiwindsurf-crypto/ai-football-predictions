const cheerio = require('cheerio');

async function scrape() {
  try {
    const res = await fetch('https://soccer-rating.com/Flamengo/w90/');
    const html = await res.text();
    const $ = cheerio.load(html);
    
    // Look for form or previous matches
    let h2hText = '';
    let homeForm = '';
    let awayForm = '';
    
    // The "Form Last 3 Games" table usually has "Form Last 3 Games" in its text
    $('table').each((i, el) => {
        const text = $(el).text();
        if (text.includes('Form Last 3 Games')) {
            console.log(`Table ${i} has form! Text:`, text.replace(/\s+/g, ' ').substring(0, 200));
            // Extract the W D L from the rows
            $(el).find('tr').each((j, row) => {
                const rowText = $(row).text().trim().replace(/\s+/g, ' ');
                if (rowText.includes('W') || rowText.includes('D') || rowText.includes('L')) {
                    console.log(`Form row: ${rowText}`);
                }
            });
        }
    });

  } catch (err) {
    console.error(err);
  }
}

scrape();
