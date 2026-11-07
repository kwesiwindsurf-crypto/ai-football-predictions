import fs from 'fs';

const raw = fs.readFileSync('C:\\Users\\alexa\\.gemini\\antigravity-ide\\brain\\dfa70a82-db8c-47c4-9dfb-a100532b7a40\\.system_generated\\steps\\728\\content.md', 'utf8');
const jsonStart = raw.indexOf('{');
const data = JSON.parse(raw.slice(jsonStart));

console.log("Total bytes:", raw.length);
for (const key of Object.keys(data)) {
  const size = JSON.stringify(data[key]).length;
  console.log(`Key ${key}: ${(size / 1024).toFixed(1)} KB`);
}

if (data.matchesData && data.matchesData.matches) {
  console.log("\nMatches count:", data.matchesData.matches.length);
  // How many matches are today / upcoming vs historical?
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);
  console.log("Current date:", todayStr);
  
  const statusCounts = {};
  for (const m of data.matchesData.matches) {
    statusCounts[m.status] = (statusCounts[m.status] || 0) + 1;
  }
  console.log("Matches by status:", statusCounts);
}
