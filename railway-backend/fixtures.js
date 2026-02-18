import fs from "fs";
import { getSquiggleStatusForMatch } from "./squiggle_service.js";

// Load JSON maps manually (Railway-safe)
import path from "path";

const squiggleMap = JSON.parse(
  fs.readFileSync(path.resolve("railway-backend/squiggle_map.json"), "utf8")
);

const dfsMap = JSON.parse(
  fs.readFileSync(path.resolve("railway-backend/dfs_map.json"), "utf8")
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