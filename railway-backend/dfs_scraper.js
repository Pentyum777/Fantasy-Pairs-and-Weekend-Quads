// ❌ No more Playwright
// import { chromium } from "playwright";

// ✅ Pure HTTP fetch
import fetch from "node-fetch";

export async function scrapeDFS(dfsId) {
  const url = `https://dfsaustralia.com/wp-json/dfs/v1/afl-game-stats?gameId=${dfsId}`;

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json",
      },
      timeout: 8000,
    });

    if (!response.ok) {
      console.error("DFS API returned error:", response.status);
      return { players: [], meta: {} };
    }

    const json = await response.json();

    // DFS returns an array of players with stats
    const rows = json?.players || [];

    const players = rows
      .map((p) => {
        const {
          playerId,
          playerName,
          kicks,
          handballs,
          marks,
          tackles,
          hitouts,
          freesFor,
          freesAgainst,
          goals,
          behinds,
          tog, // time on ground %
          startingPosition,
          benchReason,
        } = p;

        const isSubOrOut =
          startingPosition === "SUB" ||
          benchReason === "Sub Tactical" ||
          benchReason === "Sub Injured" ||
          benchReason === "Injured" ||
          benchReason === "OUT";

        if (isSubOrOut) return null;

        const fantasyPoints =
          kicks * 3 +
          handballs * 2 +
          marks * 3 +
          tackles * 4 +
          hitouts * 1 +
          freesFor * 1 +
          freesAgainst * -3 +
          goals * 6 +
          behinds * 1;

        return {
          id: playerId || playerName,
          name: playerName,
          team: "",
          stats: {
            fantasyPoints,
            kicks,
            handballs,
            marks,
            tackles,
            hitouts,
            freesFor,
            freesAgainst,
            goals,
            behinds,
            timeOnGroundPercentage: tog,
          },
        };
      })
      .filter(Boolean);

    // Metadata (DFS includes this too)
    const meta = {
      homeScore: json?.homeScore ?? 0,
      awayScore: json?.awayScore ?? 0,
      quarter: json?.quarter ?? "",
      clock: json?.clock ?? "",
    };

    return { players, meta };
  } catch (err) {
    console.error("DFS fetch failed:", err);
    return { players: [], meta: {} };
  }
}