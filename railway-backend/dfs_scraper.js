// dfs_scraper.js
// JSON-based DFS fetcher (no Playwright)

import fetch from "node-fetch";

export async function scrapeDFS(dfsId) {
  const url = `https://dfsaustralia.com/api/afl-game-stats?gameId=${dfsId}`;

  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0" },
    });

    if (!res.ok) {
      throw new Error(`DFS API returned ${res.status}`);
    }

    const json = await res.json();

    // Defensive: ensure players array exists
    const players = Array.isArray(json.players) ? json.players : [];

    // Normalize to the shape your backend + Flutter expect
    const normalisedPlayers = players
      .filter((p) => p && p.id)
      .map((p) => ({
        id: String(p.id),
        fantasyPoints: p.fantasyPoints ?? 0,
        goals: p.goals ?? 0,
        behinds: p.behinds ?? 0,
        disposals: p.disposals ?? 0,
        marks: p.marks ?? 0,
        tackles: p.tackles ?? 0,
        hitouts: p.hitouts ?? 0,
        clearances: p.clearances ?? 0,
        metresGained: p.metresGained ?? 0,
        goalAssists: p.goalAssists ?? 0,
        timeOnGroundPercentage: p.timeOnGroundPercentage ?? 0,
      }));

    return { players: normalisedPlayers };
  } catch (err) {
    console.error("💥 DFS JSON fetch failed:", err);
    return { players: [] };
  }
}