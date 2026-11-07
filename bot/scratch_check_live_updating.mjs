async function checkLive() {
  const url = 'https://ai-football-predictions.onrender.com/live?t=' + Date.now();
  console.log('Fetching live snapshot 1 from Render...');
  const res1 = await fetch(url);
  const data1 = await res1.json();
  console.log('Snapshot 1:');
  console.log('Status:', data1.status);
  console.log('lastUpdated:', data1.lastUpdated);
  console.log('hasLiveGame:', data1.hasLiveGame);
  console.log('Active/Finished matches count:', data1.count);

  const liveMatches = (data1.matches || []).filter(m => m.status === 'live');
  console.log('Currently LIVE matches in-play:', liveMatches.length);
  liveMatches.forEach(m => {
    console.log(` - [LIVE] ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam} | Clock: ${m.statusShort || m.elapsed} | League: ${m.league}`);
  });

  const ftMatches = (data1.matches || []).filter(m => m.status === 'finished' || m.statusShort === 'FT');
  console.log('Finished (FT) matches count:', ftMatches.length);
  ftMatches.slice(0, 5).forEach(m => {
    console.log(` - [FT] ${m.homeTeam} ${m.homeScore} - ${m.awayScore} ${m.awayTeam} | League: ${m.league}`);
  });

  // Now wait 35 seconds to see if lastUpdated changes or clock advances
  console.log('\nWaiting 35 seconds for Render polling cycle...');
  await new Promise(r => setTimeout(r, 35000));

  const url2 = 'https://ai-football-predictions.onrender.com/live?t=' + Date.now();
  console.log('Fetching live snapshot 2 from Render...');
  const res2 = await fetch(url2);
  const data2 = await res2.json();
  console.log('Snapshot 2:');
  console.log('lastUpdated:', data2.lastUpdated);
  console.log('Count:', data2.count);

  const isUpdated = data1.lastUpdated !== data2.lastUpdated;
  console.log('\n=== RESULT ===');
  console.log('Did lastUpdated change?', isUpdated ? 'YES' : 'NO');
  console.log('Snapshot 1 timestamp:', data1.lastUpdated);
  console.log('Snapshot 2 timestamp:', data2.lastUpdated);
}

checkLive().catch(console.error);
