async function test() {
  console.log("Testing Cloudflare worker...");
  try {
    const t0 = Date.now();
    const res = await fetch("https://ai-football-bot.xantechs00.workers.dev/");
    console.log("CF Status:", res.status, "Time:", Date.now() - t0, "ms");
    const json = await res.json();
    console.log("CF Matches count:", json?.matchesData?.matches?.length);
    if (json?.matchesData?.matches?.length > 0) {
      console.log("First match:", json.matchesData.matches[0].homeTeam, "vs", json.matchesData.matches[0].awayTeam, "status:", json.matchesData.matches[0].status, "date:", json.matchesData.matches[0].date);
      // Let's inspect all dates present in CF matches:
      const dates = new Set(json.matchesData.matches.map(m => m.date));
      console.log("Sample match dates:", Array.from(dates).slice(0, 10));
    }
  } catch (e) {
    console.error("CF Worker failed:", e.message);
  }

  console.log("\nTesting Render server...");
  try {
    const t0 = Date.now();
    const res = await fetch("https://ai-football-predictions.onrender.com/", { signal: AbortSignal.timeout(5000) });
    console.log("Render Status:", res.status, "Time:", Date.now() - t0, "ms");
  } catch (e) {
    console.error("Render failed:", e.message);
  }
}

test();
