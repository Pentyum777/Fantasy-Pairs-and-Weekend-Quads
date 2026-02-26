// dfs_scraper.js
// Correct DFS Australia JSON scraper (no Playwright)

import fetch from "node-fetch";

export async function scrapeDFS(dfsId) {
  const url = `https://dfsaustralia.com/wp-admin/admin-ajax.php?action=afl_game_stats_call_mysql&id=${dfsId}`;

  try {
    const res = await fetch(url, {
      method: "GET",
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json,text/html",
      },
    });

    if (!res.ok) {
      throw new Error(`DFS returned HTTP ${res.status}`);
    }

    const json = await res.json();

    // DFS returns:
    // {
    //   homeTeam: [...],
    //   awayTeam: [...],
    //   home: [...],
    //   away: [...]
    // }

    const home = Array.isArray(json.home) ? json.home : [];
    const away = Array.isArray(json.away) ? json.away : [];

    const rawPlayers = [...home, ...away];

    const normalisedPlayers = rawPlayers
      .filter((p) => p && p.playerId)
      .map((p) => {
        const kicks = Number(p.kicks ?? 0);
        const handballs = Number(p.handballs ?? 0);
        const disposals = kicks + handballs;

        return {
          id: String(p.playerId),
          fantasyPoints: Number(p.fantasyPoints ?? 0),
          goals: Number(p.goals ?? 0),
          behinds: Number(p.behinds ?? 0),
          disposals,
          marks: Number(p.marks ?? 0),
          tackles: Number(p.tackles ?? 0),
          hitouts: Number(p.hitouts ?? 0),
          clearances: Number(p.clearances ?? 0),
          metresGained: Number(p.metresGained ?? 0),
          goalAssists: Number(p.goalAssists ?? 0),
          timeOnGroundPercentage: Number(p.timeOnGroundPercentage ?? 0),
        };
      });

    return { players: normalisedPlayers };
  } catch (err) {
    console.error("💥 DFS fetch failed:", err);
    return { players: [] };
  }
}