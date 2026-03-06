import fetch from "node-fetch";

/**
 * Scrape DFS stats using the official event feed.
 * @param {number} dfsId - The DFS gameId (e.g., 8041)
 * @returns {Promise<Array>} Array of aggregated player stats
 */
export async function scrapeDFS(dfsId) {
  try {
    // 1. Fetch the full season event feed
    const url = "https://dfsaustralia-apps.com/shiny/afl-live-scoring/liveScoring2026.json";
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
      },
      timeout: 10000,
    });

    if (!res.ok) {
      console.error("DFS event feed returned error:", res.status);
      return [];
    }

    const events = await res.json();

    // 2. Filter events for this specific match
    const matchEvents = events.filter((e) => e.id === dfsId);

    if (matchEvents.length === 0) {
      console.warn(`No DFS events found for gameId ${dfsId}`);
      return [];
    }

    // 3. Aggregate stats by player
    const stats = {};

    for (const ev of matchEvents) {
      const pid = ev.playerId;

      if (!stats[pid]) {
        stats[pid] = {
          id: pid,
          name: ev.playerName,
          team: ev.teamAbbr,
          kicks: 0,
          handballs: 0,
          marks: 0,
          tackles: 0,
          hitouts: 0,
          freesFor: 0,
          freesAgainst: 0,
          goals: 0,
          behinds: 0,
          fantasyPoints: 0,
        };
      }

      // 4. Increment stat counters
      switch (ev.statRank) {
        case "kick":
          stats[pid].kicks++;
          break;
        case "handball":
          stats[pid].handballs++;
          break;
        case "mark":
          stats[pid].marks++;
          break;
        case "tackle":
          stats[pid].tackles++;
          break;
        case "hitout":
          stats[pid].hitouts++;
          break;
        case "freefor":
          stats[pid].freesFor++;
          break;
        case "freeagainst":
          stats[pid].freesAgainst++;
          break;
        case "goal":
          stats[pid].goals++;
          break;
        case "behind":
          stats[pid].behinds++;
          break;
      }
    }

    // 5. Compute fantasy points for each player
    for (const pid of Object.keys(stats)) {
      const s = stats[pid];

      s.fantasyPoints =
        s.kicks * 3 +
        s.handballs * 2 +
        s.marks * 3 +
        s.tackles * 4 +
        s.hitouts * 1 +
        s.freesFor * 1 -
        s.freesAgainst * 3 +
        s.goals * 6 +
        s.behinds * 1;
    }

    // 6. Return as array
    return Object.values(stats);
  } catch (err) {
    console.error("DFS scraper failed:", err);
    return [];
  }
}
