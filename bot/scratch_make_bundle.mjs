import fs from 'fs';
import path from 'path';

const raw = fs.readFileSync('C:\\Users\\alexa\\.gemini\\antigravity-ide\\brain\\dfa70a82-db8c-47c4-9dfb-a100532b7a40\\.system_generated\\steps\\728\\content.md', 'utf8');
const jsonStart = raw.indexOf('{');
const data = JSON.parse(raw.slice(jsonStart));

const cleanData = {
  matchesData: data.matchesData || { matches: [] },
  standingsData: data.standingsData || { standingsByLeague: [] }
};

const outDir = path.resolve('assets/data');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

const outPath = path.join(outDir, 'default_matches.json');
fs.writeFileSync(outPath, JSON.stringify(cleanData));

console.log("Successfully wrote bundled asset to", outPath);
console.log("File size:", (fs.statSync(outPath).size / 1024).toFixed(1), "KB");
console.log("Matches count:", cleanData.matchesData.matches.length);
