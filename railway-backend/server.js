import express from "express";
import fs from "fs";
import cors from "cors";

import { scrapeDFS } from "./dfs_scraper.js";

// Load DFS mapping
const dfsMap = JSON.parse(
  fs.readFileSync("./dfs_map.json", "utf8")
);

// Load Squiggle mapping (your matchId → Squiggle gameId)
const squiggleMap = JSON.parse(
  fs.readFileSync("./squiggle_map.json", "utf8")
);

console.log("CORS-enabled DFS + Squiggle backend starting...");

const port = process.env.PORT || 8080;
const app = express();

// ------------------------------------------------------
// Explicit OPTIONS handler (fixes Railway preflight blocking)
// ------------------------------------------------------
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

// Enable CORS for Flutter Web
app.use(cors({ origin: "*" }));
app.options("*", cors());

app.use(express.json());

// Root route
app.get("/", (req, res) => {
  res.send("DFS + Squiggle backend is running");
});

// ------------------------------------------------------
// Simple in-memory cache (5-minute TTL)
// ------------------------------------------------------
const metaCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000;

function getCachedMeta(key) {
  const entry = metaCache.get(key);
  if (!entry) return null;

  const isExpired = Date.now() - entry.timestamp > CACHE_TTL_MS;
  if (isExpired) {
    metaCache.delete(key);
    return null;
  }
  return entry.data;
}

function setCachedMeta(key, data) {
  metaCache.set(key, {
    timestamp: Date.now(),
    data,
  });
}

// ------------------------------------------------------
// Squiggle metadata fetcher
// ------------------------------------------------------
async function fetchSquiggleMeta(gameId) {
  const cached = getCachedMeta(`squiggle:${gameId}`);
  if (cached) return cached;

  const url = `https://api.squiggle.com.au/?q=games;game=${gameId}`;

  try {
    // Create a timeout controller
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    const response = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);

    const json = await response.json();
    const games = json.games || [];

    if (!games.length) {
      console.warn("Squiggle returned no games for", gameId);
      const empty = {
        homeScore: 0,
        awayScore: 0,
        quarter: "",
        clock: "",
        status: "",
      };
      setCachedMeta(`squiggle:${gameId}`, empty);
      return empty;
    }

    const g = games[0];

    const homeScore = g.hscore ?? 0;
    const awayScore = g.ascore ?? 0;

    const complete = g.complete ?? 0;
    let status = "";
    let quarter = "";
    let clock = "";

    if (complete === 100) {
      status = "Full Time";
      quarter = "Final";
      clock = "FT";
    }

    const meta = {
      homeScore,
      awayScore,
      quarter,
      clock,
      status,
    };

    setCachedMeta(`squiggle:${gameId}`, meta);
    return meta;

  } catch (err) {
    console.error("Squiggle fetch failed:", err);
    const empty = {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "",
    };
    setCachedMeta(`squiggle:${gameId}`, empty);
    return empty;
  }
}


// ------------------------------------------------------
// Fantasy stats endpoint (DFS + Squiggle)
// ------------------------------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const dfsId = dfsMap[matchId];
  const squiggleGameId = squiggleMap[matchId];

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  if (!squiggleGameId) {
    console.warn("No Squiggle mapping for matchId", matchId);
  }

  try {
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
      homeScore: meta.homeScore ?? 0,
      awayScore: meta.awayScore ?? 0,
      quarter: meta.quarter ?? "",
      clock: meta.clock ?? "",
      status: meta.status ?? "",
      players: dfsData.players,
    });
  } catch (err) {
    console.error("Combined DFS + Squiggle error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// ------------------------------------------------------
// Metadata-only endpoint (Squiggle only)
// ------------------------------------------------------
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const squiggleGameId = squiggleMap[matchId];
  if (!squiggleGameId) {
    return res.status(404).json({ error: "No Squiggle mapping for matchId" });
  }

  try {
    const meta = await fetchSquiggleMeta(squiggleGameId);

    res.json({
      matchId,
      match: meta,
    });
  } catch (err) {
    console.error("Squiggle meta error:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`DFS + Squiggle backend running on port ${port}`);
});