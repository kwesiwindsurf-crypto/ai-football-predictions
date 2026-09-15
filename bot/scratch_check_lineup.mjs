async function run() {
  try {
    // 1. Get a recent finished match from the English Premier League
    const scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard?dates=20260914&limit=10';
    let res = await fetch(scoreboardUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    let data = await res.json();
    
    // Fallback if no matches found yesterday, try picking from another league or date
    let eventId = data.events?.[0]?.id;
    
    if (!eventId) {
      // Just hardcode a known past match ID from earlier this month/year (e.g. Man Utd vs Fulham)
      // Or query today's scoreboard for any league that has finished matches
      const espRes = await fetch('https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard?dates=20260915');
      const espData = await espRes.json();
      eventId = espData.events?.[0]?.id;
    }

    if (!eventId) {
      console.log('Could not find a match ID to check.');
      return;
    }

    console.log('Fetching summary for Match ID:', eventId);

    // 2. Fetch the summary for that specific match
    const summaryUrl = `https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event=${eventId}`;
    const summaryRes = await fetch(summaryUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    const summaryData = await summaryRes.json();

    const rosters = summaryData.rosters;
    if (!rosters || rosters.length === 0) {
      console.log('No lineups found for this match yet (it might not have started).');
      return;
    }

    // 3. Print the lineup for the first team
    const team = rosters[0];
    console.log(`\n--- Lineup for ${team.team.displayName} ---`);
    console.log(`Formation: ${team.formation}`);
    console.log('\nStarting XI:');
    
    team.roster.forEach(player => {
      if (player.starter) {
        console.log(`- [#${player.athlete.jersey || '?'}] ${player.athlete.displayName} (${player.position?.abbreviation || 'N/A'})`);
      }
    });

    console.log('\nSubstitutes (Bench):');
    team.roster.forEach(player => {
      if (!player.starter) {
        console.log(`- [#${player.athlete.jersey || '?'}] ${player.athlete.displayName} (${player.position?.abbreviation || 'N/A'})`);
      }
    });

  } catch (e) {
    console.error('Error fetching lineup:', e.message);
  }
}

run();
