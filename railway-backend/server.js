import express from "express";
import fs from "fs";
import path from "path";
import cors from "cors";

import { scrapeDFS } from "./dfs_scraper.js";

const dfsMap = JSON.parse(fs.readFileSync("./dfs_map.json", "utf8"));
const squiggleMap = JSON.parse(fs.readFileSync("./squiggle_map.json", "utf8"));

console.log("🚀 DFS + Squiggle backend starting...");

const port = process.env.PORT || 8080;
const app = express();

// CORS
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(200);
  next();
});

app.use(cors({ origin: "*" }));
app.use(express.json());

// Root
app.get("/", (req, res) => {
  res.send("DFS + Squiggle backend is running");
});

// ------------------------------
// Squiggle metadata fetcher
// ------------------------------
async function fetchSquiggleMeta(gameId) {
  const url = `https://api.squiggle.com.au/?q=games&game=${gameId}`;

  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0" },
    });

    const json = await response.json();
    const games = json.games || [];

    if (!games.length) {
      console.warn("⚠ Squiggle returned no games for", gameId);
      return {
        homeScore: 0,
        awayScore: 0,
        quarter: "",
        clock: "",
        status: "",
      };
    }

    const g = games[0];

    const homeScore = g.hscore ?? 0;
    const awayScore = g.ascore ?? 0;

    let quarter = "";
    let clock = "";
    let status = "";

    if (g.complete === 100) {
      quarter = "Final";
      clock = "FT";
      status = "Full Time";
    } else if (g.complete > 0) {
      quarter = g.timestr || "";
      clock = "";
      status = "In Progress";
    } else {
      status = "Upcoming";
    }

    return { homeScore, awayScore, quarter, clock, status };
  } catch (err) {
    console.error("Squiggle fetch failed:", err);
    return {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "",
    };
  }
}

// ------------------------------
// Fantasy endpoint (DFS + Squiggle)
// ------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const dfsId = dfsMap[matchId];
  const squiggleGameId = squiggleMap[matchId];

  console.log("➡ Incoming matchId:", matchId);
  console.log("➡ DFS ID:", dfsId);
  console.log("➡ Squiggle ID:", squiggleGameId);

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  try {
    // ALWAYS scrape DFS — no gating
    const dfsData = await scrapeDFS(dfsId);

    if (!dfsData || !dfsData.players) {
      return res.status(500).json({ error: "DFS returned no player data" });
    }

    let meta = {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "",
    };

    if (squiggleGameId) {
      meta = await fetchSquiggleMeta(squiggleGameId);
    }

    res.json({
      matchId,
      homeScore: meta.homeScore,
      awayScore: meta.awayScore,
      quarter: meta.quarter,
      clock: meta.clock,
      status: meta.status,
      players: dfsData.players,
    });
  } catch (err) {
    console.error("💥 Combined DFS + Squiggle error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// ------------------------------
// Metadata-only endpoint
// ------------------------------
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;
  const squiggleGameId = squiggleMap[matchId];

  if (!squiggleGameId) {
    return res.status(404).json({ error: "No Squiggle mapping for matchId" });
  }

  try {
    const meta = await fetchSquiggleMeta(squiggleGameId);
    res.json({ matchId, match: meta });
  } catch (err) {
    console.error("Squiggle meta error:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 DFS + Squiggle backend running on port ${port}`);
});