import express from "express";
import fs from "fs";
import path from "path";
import cors from "cors";

import { scrapeDFS } from "./dfs_scraper.js";

// Load DFS mapping
const dfsMap = JSON.parse(
  fs.readFileSync("./dfs_map.json", "utf8")
);

// Load Squiggle mapping
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
// In-memory per-game-type selections (live snapshot)
// ------------------------------------------------------
let selectionsByGameType = {};

// Save selections for a specific game type (live state)
app.post("/saveSelections", (req, res) => {
  const { gameType, punterNames, picks } = req.body;

  if (!gameType) {
    return res.status(400).json({ error: "gameType is required" });
  }

  selectionsByGameType[gameType] = {
    lastUpdated: Date.now(),
    data: {
      punterNames,
      picks,
    },
  };

  console.log(`💾 Saved selections for ${gameType}`);
  res.json({
    ok: true,
    lastUpdated: selectionsByGameType[gameType].lastUpdated,
  });
});

// Load selections for a specific game type (live state)
app.get("/loadSelections", (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");

  const gameType = req.query.gameType;

  if (!gameType) {
    return res.status(400).json({ error: "gameType is required" });
  }

  const snapshot = selectionsByGameType[gameType];

  if (!snapshot) {
    return res.json({
      ok: true,
      lastUpdated: 0,
      data: null,
    });
  }

  res.json({
    ok: true,
    lastUpdated: snapshot.lastUpdated,
    data: snapshot.data,
  });
});

// ------------------------------------------------------
// Persistent season results (future-proof, skips 2025)
// ------------------------------------------------------

// Base folder for season results
const SEASON_RESULTS_ROOT = path.join(process.cwd(), "season_results");

// Ensure directory exists
function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

// Normalise gameType keys (frontend should already send canonical keys)
function normalizeGameType(gameType) {
  if (!gameType) return null;
  return String(gameType).trim().toLowerCase();
}

// Save round results for a given season + gameType
// This is called when a round is "completed" in your app.
app.post("/saveRoundResults", (req, res) => {
  try {
    const {
      season,
      round,
      gameType,
      punters, // [{ name, total, picks: [{ playerId, score, ... }] }]
    } = req.body;

    if (season == null || round == null || !gameType) {
      return res.status(400).json({
        error: "season, round and gameType are required",
      });
    }

    const numericSeason = Number(season);
    const numericRound = Number(round);
    const normalizedGameType = normalizeGameType(gameType);

    if (!normalizedGameType) {
      return res.status(400).json({ error: "Invalid gameType" });
    }

    // Skip 2025 test data; allow 2026 and beyond
    if (numericSeason <= 2025) {
      console.log(
        `⚠️ Skipping persistent save for test season ${numericSeason}, gameType=${normalizedGameType}, round=${numericRound}`
      );
      return res.json({ ok: true, skipped: true });
    }

    const seasonDir = path.join(SEASON_RESULTS_ROOT, String(numericSeason));
    const gameTypeDir = path.join(seasonDir, normalizedGameType);

    ensureDir(gameTypeDir);

    const fileName = `round_${numericRound}.json`;
    const filePath = path.join(gameTypeDir, fileName);

    const payload = {
      season: numericSeason,
      round: numericRound,
      gameType: normalizedGameType,
      timestamp: Date.now(),
      punters: Array.isArray(punters) ? punters : [],
    };

    fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), "utf8");

    console.log(
      `📁 Saved season result: season=${numericSeason}, gameType=${normalizedGameType}, round=${numericRound}`
    );

    res.json({ ok: true, path: filePath });
  } catch (err) {
    console.error("💥 saveRoundResults error:", err);
    res.status(500).json({ error: "Failed to save round results" });
  }
});

// (Optional) Fetch all results for a season + gameType
// You may not use this immediately, but it's ready for Season Review UI.
app.get("/seasonResults", (req, res) => {
  try {
    const { season, gameType } = req.query;

    if (!season || !gameType) {
      return res.status(400).json({
        error: "season and gameType are required",
      });
    }

    const numericSeason = Number(season);
    const normalizedGameType = normalizeGameType(gameType);

    const gameTypeDir = path.join(
      SEASON_RESULTS_ROOT,
      String(numericSeason),
      normalizedGameType
    );

    if (!fs.existsSync(gameTypeDir)) {
      return res.json({ ok: true, results: [] });
    }

    const files = fs
      .readdirSync(gameTypeDir)
      .filter((f) => f.startsWith("round_") && f.endsWith(".json"))
      .sort();

    const results = files.map((file) => {
      const fullPath = path.join(gameTypeDir, file);
      const json = JSON.parse(fs.readFileSync(fullPath, "utf8"));
      return json;
    });

    res.json({ ok: true, results });
  } catch (err) {
    console.error("💥 seasonResults error:", err);
    res.status(500).json({ error: "Failed to load season results" });
  }
});

// ------------------------------------------------------
// Simple in-memory cache (5-minute TTL) for Squiggle meta
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
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
      },
    });

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

  console.log("➡️ Incoming matchId:", matchId);
  console.log("➡️ DFS ID:", dfsId);
  console.log("➡️ Squiggle Game ID:", squiggleGameId);

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
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
      console.log("📡 Fetching Squiggle metadata for game:", squiggleGameId);
      meta = await fetchSquiggleMeta(squiggleGameId);
      console.log("📊 Squiggle metadata returned:", meta);
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
    console.error("💥 Combined DFS + Squiggle error:", err);
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