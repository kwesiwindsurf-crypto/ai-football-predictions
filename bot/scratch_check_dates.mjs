import fs from 'fs';

const raw = fs.readFileSync('c:\\Users\\alexa\\StudioProjects\\ai_football_predictions\\assets\\data\\default_matches.json', 'utf8');
const data = JSON.parse(raw);
const matches = data.matchesData.matches;

const dateCounts = {};
for (const m of matches) {
  const d = m.date.slice(0, 10);
  dateCounts[d] = (dateCounts[d] || 0) + 1;
}

console.log("Match count per date:");
console.table(dateCounts);

const leagues = new Set(matches.map(m => m.league));
console.log("Total leagues:", leagues.size);
