import fetch from "node-fetch";

export async function scrapeDFS(dfsId) {
  try {
    const url =
      "https://dfsaustralia-apps.com/shiny/afl-live-scoring/liveScoring2026.json";

    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
      },
      timeout: 10000,
    });

    if (!res.ok) {
      console.error("DFS feed returned error:", res.status);
      return [];
    }

    // ------------------------------------------------------------
    // SAFE JSON PARSE (bulletproof)
    // ------------------------------------------------------------
    let json;
    try {
      json = await res.json();
    } catch (err) {
      const text = await res.text();
      console.error("❌ DFS feed returned invalid JSON");
      console.error("Raw response snippet:", text.slice(0, 500));
      throw err;
    }

    // ------------------------------------------------------------
    // Validate structure
    // ------------------------------------------------------------
    if (!json.playerStats || !Array.isArray(json.playerStats)) {
      console.error("DFS feed missing playerStats array");
      return [];
    }

    // Convert dfsId to number
    const matchId = Number(dfsId);

    // Filter players for this match
    const players = json.playerStats.filter((p) => p.id === matchId);

    return players;
  } catch (err) {
    console.error("DFS scraper failed:", err);
    return [];
  }
}