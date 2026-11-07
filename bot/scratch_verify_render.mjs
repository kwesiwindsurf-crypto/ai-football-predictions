console.log("Testing GET from Render...");
const t0 = Date.now();
const res = await fetch('https://ai-football-predictions.onrender.com/', { signal: AbortSignal.timeout(10000) });
console.log("Status:", res.status, "Time:", Date.now() - t0, "ms");
const json = await res.json();
console.log("Matches count:", json?.matchesData?.matches?.length);
console.log("Standings leagues count:", json?.standingsData?.standingsByLeague?.length);
