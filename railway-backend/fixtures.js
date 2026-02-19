import fs from "fs";
import { getSquiggleStatusForMatch } from "./squiggle_service.js";
import path from "path";

// Load JSON maps manually (Railway-safe)
const squiggleMap = JSON.parse(
  fs.readFileSync(path.resolve("squiggle_map.json"), "utf8")
);

const dfsMap = JSON.parse(
  fs.readFileSync(path.resolve("dfs_map.json"), "utf8")
);

/**
 * Returns all matches that are currently live.
 * Output: [{ matchId, dfsId }]
 */
export async function getLiveMatches() {
  const live = [];

  for (const matchId of Object.keys(squiggleMap)) {
    const status = await getSquiggleStatusForMatch(matchId);

    if (status === "In Progress") {
      const dfsId = dfsMap[matchId];

      if (dfsId) {
        live.push({ matchId, dfsId });
      } else {
        console.warn(`⚠ No DFS ID found for live match ${matchId}`);
      }
    }
  }

  return live;
}
