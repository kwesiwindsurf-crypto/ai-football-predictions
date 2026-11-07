import fs from 'fs';

const raw = fs.readFileSync('c:\\Users\\alexa\\StudioProjects\\ai_football_predictions\\assets\\data\\default_matches.json', 'utf8');
const data = JSON.parse(raw);

const allMatches = data.matchesData.matches;
console.log("Original match count:", allMatches.length);

// Keep matches from yesterday (Oct 26) through next week (Nov 3)
const cleanMatches = allMatches.filter(m => {
  const d = m.date.slice(0, 10);
  return d >= '2026-10-26' && d <= '2026-11-03';
});

console.log("Clean active matches count:", cleanMatches.length);

// Sort chronologically
cleanMatches.sort((a, b) => new Date(a.date) - new Date(b.date));

const freshPayload = {
  matchesData: {
    lastUpdated: new Date().toISOString(),
    scrapedBy: 'fresh-clean-sync',
    matches: cleanMatches
  },
  standingsData: data.standingsData || { standingsByLeague: [] }
};

const jsonStr = JSON.stringify(freshPayload);
fs.writeFileSync('c:\\Users\\alexa\\StudioProjects\\ai_football_predictions\\assets\\data\\default_matches.json', jsonStr);

console.log("Wrote fresh clean dataset to assets/data/default_matches.json");
console.log("Clean file size:", (Buffer.byteLength(jsonStr) / 1024).toFixed(1), "KB");
