import fs from 'fs';

const raw = fs.readFileSync('c:\\Users\\alexa\\StudioProjects\\ai_football_predictions\\assets\\data\\default_matches.json', 'utf8');

console.log("Pinging Render...");
try {
  const res = await fetch('https://ai-football-predictions.onrender.com/health', { signal: AbortSignal.timeout(10000) });
  console.log("Render health check:", res.status, await res.text());
} catch (e) {
  console.log("Render ping note:", e.message);
}

console.log("Pushing clean fresh dataset to Render...");
try {
  const res = await fetch('https://ai-football-predictions.onrender.com/api/update', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: raw,
    signal: AbortSignal.timeout(30000)
  });
  console.log("Render update status:", res.status);
  const text = await res.text();
  console.log("Render update response:", text);
} catch (e) {
  console.error("Render update error:", e.message);
}
