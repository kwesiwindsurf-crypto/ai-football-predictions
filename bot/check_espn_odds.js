const https = require('https');

https.get('https://site.api.espn.com/apis/site/v2/sports/soccer/scorepanel?dates=20260915', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      const scores = parsed.scores || [];
      let foundOdds = false;
      for (const block of scores) {
        for (const ev of (block.events || [])) {
          for (const comp of (ev.competitions || [])) {
            if (comp.odds) {
              console.log('Found odds for match:', ev.name);
              console.log(JSON.stringify(comp.odds, null, 2));
              foundOdds = true;
              break;
            }
          }
          if (foundOdds) break;
        }
        if (foundOdds) break;
      }
      if (!foundOdds) {
        console.log('No odds found in any match for this date.');
      }
    } catch (e) {
      console.error(e);
    }
  });
});
