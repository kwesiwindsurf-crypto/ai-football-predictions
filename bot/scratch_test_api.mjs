async function test() {
  const res = await fetch('https://ai-football-bot.xantechs00.workers.dev');
  const data = await res.json();
  const matches = data.matchesData?.matches || data.matches;
  
  if (!matches) {
    console.log("No matches found in API response");
    return;
  }
  
  const match = matches.find(m => m.homeTeam === 'Leganés' || m.awayTeam === 'Castellón');
  if (match) {
    console.log(`Found match: ${match.homeTeam} vs ${match.awayTeam}`);
    console.log(`h2hSummary: ${match.h2hSummary}`);
  } else {
    console.log("Match not found in the API response.");
  }
}
test();
