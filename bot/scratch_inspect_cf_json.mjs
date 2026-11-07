import fs from 'fs';

const raw = fs.readFileSync('C:\\Users\\alexa\\.gemini\\antigravity-ide\\brain\\dfa70a82-db8c-47c4-9dfb-a100532b7a40\\.system_generated\\steps\\728\\content.md', 'utf8');

// The file has a header like:
// Source: ...
// ---
// JSON...
const jsonStart = raw.indexOf('{');
const jsonStr = raw.slice(jsonStart);

const data = JSON.parse(jsonStr);

console.log("Top-level keys:", Object.keys(data));
if (data.matchesData) {
  console.log("matchesData keys:", Object.keys(data.matchesData));
  console.log("matches is Array?:", Array.isArray(data.matchesData.matches));
  console.log("matches count:", data.matchesData.matches.length);
  if (data.matchesData.matches.length > 0) {
    const firstMatch = data.matchesData.matches[0];
    console.log("Sample match keys:", Object.keys(firstMatch));
    console.log("Sample match:", JSON.stringify(firstMatch, null, 2).slice(0, 500));
  }
}
if (data.standingsData) {
  console.log("standingsData keys:", Object.keys(data.standingsData));
}
