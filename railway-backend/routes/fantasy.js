import express from "express";
import { scrapeDFS } from "../services/dfsScraper.js";
import { getSquiggleMatch } from "../services/squiggleService.js";
import dfsMap from "../data/dfs_map.json" assert { type: "json" };

const router = express.Router();

/**
 * GET /fantasy/:matchId
 * Returns combined Squiggle + DFS stats for a match
 */
router.get("/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  try {
    // 1. Get Squiggle match metadata
    const squiggle = await getSquiggleMatch(matchId);

    if (!squiggle) {
      return res.status(404).json({
        ok: false,
        message: `No Squiggle match found for matchId ${matchId}`,
      });
    }

    // 2. Look up DFS ID for this match
    const dfsId = dfsMap[matchId];

    if (!dfsId) {
      return res.status(200).json({
        ok: true,
        matchId,
        match: squiggle,
        players: [],
        message: "No DFS ID mapped for this match",
      });
    }

    // 3. Scrape DFS stats using the new event feed
    const dfsStats = await scrapeDFS(dfsId);

    // 4. Build response object
    const response = {
      ok: true,
      matchId,
      match: squiggle,
      players: dfsStats,
    };

    return res.json(response);
  } catch (err) {
    console.error("Error in /fantasy route:", err);
    return res.status(500).json({
      ok: false,
      message: "Internal server error",
    });
  }
});

export default router;