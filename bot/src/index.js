// Cloudflare Worker — Pure Fast Reader
// All scraping is done by GitHub Actions → data lives in KV → this serves it fast from the edge
export default {
  async fetch(request, env) {
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=300', // 5-min browser cache
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }

    try {
      const data = await env.SCORES_KV.get('latest_soccer_data', { type: 'text' });

      if (!data) {
        return new Response(
          JSON.stringify({ error: 'No data available yet. GitHub Actions scraper may not have run yet.' }),
          { status: 503, headers }
        );
      }

      return new Response(data, { status: 200, headers });
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'KV read error', message: e.message }),
        { status: 500, headers }
      );
    }
  },
};
