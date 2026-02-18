import { getDFSStatsForMatch } from "./dfscache.js";
import { getLiveMatches } from "./fixtures.js";

const POLL_INTERVAL_MS = 15000;

export function startLiveDFSLoop() {
  console.log("🔄 Live DFS scheduler started (every 15 seconds)");

  setInterval(async () => {
    try {
      const liveMatches = await getLiveMatches();

      if (liveMatches.length === 0) {
        console.log("⏳ No live matches right now");
        return;
      }

      console.log(`🔥 Live matches detected: ${liveMatches.length}`);

      for (const match of liveMatches) {
        console.log(`➡ Updating DFS stats for match ${match.matchId}`);
        await getDFSStatsForMatch(match.matchId);
      }
    } catch (err) {
      console.error("❌ Live DFS loop error:", err);
    }
  }, POLL_INTERVAL_MS);
}