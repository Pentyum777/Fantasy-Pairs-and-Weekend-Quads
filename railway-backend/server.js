// server.js
global.liveStatsCache = {};

import { startDFSWorker } from "./dfs_worker.js";
import express from "express";
import fs from "fs";
import path from "path";
import cors from "cors";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dfsMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "dfs_map.json"), "utf8")
);

const squiggleMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "squiggle_map.json"), "utf8")
);

console.log("🚀 DFS + Squiggle backend starting...");

// Start Puppeteer worker for each DFS match
Object.values(dfsMap).forEach((dfsId) => {
  if (dfsId) startDFSWorker(String(dfsId));
});

const port = process.env.PORT || 8080;
const app = express();

app.use(cors({ origin: "*", methods: ["GET", "POST", "OPTIONS"] }));
app.options("*", cors());
app.use(express.json());

// ------------------------------------------------------
// Helpers
// ------------------------------------------------------
const SELECTIONS_ROOT = path.join(process.cwd(), "selections");
const SEASON_RESULTS_ROOT = path.join(process.cwd(), "season_results");

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function normalizeGameType(gameType) {
  if (!gameType) return null;
  return String(gameType).trim().toLowerCase();
}

// ------------------------------------------------------
// Root
// ------------------------------------------------------
app.get("/", (req, res) => {
  res.json({ ok: true, message: "DFS + Squiggle backend is running" });
});

// ------------------------------------------------------
// Save selections
// ------------------------------------------------------
app.post("/saveSelections", (req, res) => {
  try {
    const { gameType, season, round, punterNames, picks } = req.body;

    if (!gameType) {
      res.header("Access-Control-Allow-Origin", "*");
      return res.status(400).json({ error: "gameType is required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      res.header("Access-Control-Allow-Origin", "*");
      return res.status(400).json({ error: "Invalid gameType" });
    }

    const safeSeason = season ?? "generic";
    const safeRound = round ?? 0;

    const dirPath = path.join(
      SELECTIONS_ROOT,
      String(safeSeason),
      normalizedGameType
    );
    ensureDir(dirPath);

    const filePath = path.join(
      dirPath,
      `${normalizedGameType}_round_${safeRound}.json`
    );

    const payload = {
      lastUpdated: Date.now(),
      punterNames: Array.isArray(punterNames) ? punterNames : [],
      picks: Array.isArray(picks) ? picks : [],
    };

    fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), "utf8");

    console.log(`💾 Saved selections → ${filePath}`);

    res.json({ ok: true, lastUpdated: payload.lastUpdated });
  } catch (err) {
    console.error("💥 saveSelections error:", err);
    res.header("Access-Control-Allow-Origin", "*");
    res.status(500).json({ error: "Failed to save selections" });
  }
});

// ------------------------------------------------------
// Load selections
// ------------------------------------------------------
app.get("/loadSelections", (req, res) => {
  try {
    const gameType = req.query.gameType;
    const season = req.query.season;
    const round = req.query.round;

    if (!gameType) {
      res.header("Access-Control-Allow-Origin", "*");
      return res.status(400).json({ error: "gameType is required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      res.header("Access-Control-Allow-Origin", "*");
      return res.status(400).json({ error: "Invalid gameType" });
    }

    const safeSeason = season ?? "generic";
    const safeRound = round ?? 0;

    const dirPath = path.join(
      SELECTIONS_ROOT,
      String(safeSeason),
      normalizedGameType
    );
    const filePath = path.join(
      dirPath,
      `${normalizedGameType}_round_${safeRound}.json`
    );

    if (!fs.existsSync(filePath)) {
      return res.json({
        ok: true,
        lastUpdated: 0,
        data: { punterNames: [], picks: [] },
      });
    }

    const json = JSON.parse(fs.readFileSync(filePath, "utf8"));

    res.json({
      ok: true,
      lastUpdated: json.lastUpdated || 0,
      data: {
        punterNames: Array.isArray(json.punterNames) ? json.punterNames : [],
        picks: Array.isArray(json.picks) ? json.picks : [],
      },
    });
  } catch (err) {
    console.error("💥 loadSelections error:", err);
    res.header("Access-Control-Allow-Origin", "*");
    res.status(500).json({ error: "Failed to load selections" });
  }
});

// ------------------------------------------------------
// Save round results
// ------------------------------------------------------
app.post("/saveRoundResults", (req, res) => {
  try {
    const { season, round, gameType, punters } = req.body;

    if (season == null || round == null || !gameType) {
      res.header("Access-Control-Allow-Origin", "*");
      return res.status(400).json({
        error: "season, round and gameType are required",
      });
    }

    const numericSeason = Number(season);
    const numericRound = Number(round);
    const normalizedGameType = normalizeGameType(gameType);

    if (!normalizedGameType) {
      res.header("Access-Control-Allow-Origin", "*");
      return res.status(400).json({ error: "Invalid gameType" });
    }

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
    res.header("Access-Control-Allow-Origin", "*");
    res.status(500).json({ error: "Failed to save round results" });
  }
});

// ------------------------------------------------------
// Load season results
// ------------------------------------------------------
app.get("/seasonResults", (req, res) => {
  try {
    const { season, gameType } = req.query;

    if (!season || !gameType) {
      res.header("Access-Control-Allow-Origin", "*");
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
      return JSON.parse(fs.readFileSync(fullPath, "utf8"));
    });

    res.json({ ok: true, results });
  } catch (err) {
    console.error("💥 seasonResults error:", err);
    res.header("Access-Control-Allow-Origin", "*");
    res.status(500).json({ error: "Failed to load season results" });
  }
});

// ------------------------------------------------------
// Fantasy endpoint (DFS cache + Squiggle)
// ------------------------------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const cdMatchId = req.params.matchId;
  const dfsId = dfsMap[cdMatchId];
  const squiggleGameId = squiggleMap[cdMatchId];

  if (!dfsId) {
    return res.status(404).json({
      error: "No DFS mapping for matchId",
      matchId: cdMatchId
    });
  }

  const dfsData = global.liveStatsCache[dfsId] || { players: [], meta: {} };

  let meta = {
    homeScore: dfsData.meta.homeScore ?? 0,
    awayScore: dfsData.meta.awayScore ?? 0,
    quarter: dfsData.meta.quarter ?? "",
    clock: "",
    status: dfsData.meta.status ?? ""
  };

  if (squiggleGameId) {
    try {
      const squiggleMeta = await fetchSquiggleMeta(squiggleGameId);
      meta = { ...meta, ...squiggleMeta };
    } catch {}
  }

  return res.json({
    matchId: cdMatchId,
    homeScore: meta.homeScore,
    awayScore: meta.awayScore,
    quarter: meta.quarter,
    clock: meta.clock,
    status: meta.status,
    players: dfsData.players
  });
});

// ------------------------------------------------------
// Squiggle metadata fetcher
// ------------------------------------------------------
async function fetchSquiggleMeta(gameId) {
  const url = `https://api.squiggle.com.au/?q=games&game=${gameId}`;

  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0" }
    });

    const json = await response.json();
    const games = json.games || [];

    if (!games.length) {
      return {
        homeScore: 0,
        awayScore: 0,
        quarter: "",
        clock: "",
        status: ""
      };
    }

    const g = games[0];

    if (g.complete === 100) {
      return {
        homeScore: g.hscore ?? 0,
        awayScore: g.ascore ?? 0,
        quarter: "Final",
        clock: "FT",
        status: "Full Time"
      };
    }

    if (g.complete > 0) {
      return {
        homeScore: g.hscore ?? 0,
        awayScore: g.ascore ?? 0,
        quarter: g.timestr || "",
        clock: "",
        status: "In Progress"
      };
    }

    return {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "Upcoming"
    };
  } catch {
    return {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: ""
    };
  }
}

// ------------------------------------------------------
// DFS Worker Health Check
// ------------------------------------------------------
app.get("/health/dfs/:matchId", (req, res) => {
  const cdMatchId = req.params.matchId;
  const dfsId = dfsMap[cdMatchId];

  if (!dfsId) {
    return res.status(404).json({
      ok: false,
      error: "No DFS mapping for matchId",
      matchId: cdMatchId
    });
  }

  const cached = global.liveStatsCache[dfsId];

  if (!cached) {
    return res.json({
      ok: true,
      dfsId,
      workerRunning: false,
      lastUpdate: 0,
      ageSeconds: null,
      playerCount: 0,
      meta: {},
      message: "Worker has not yet populated the cache"
    });
  }

  const ageSeconds = Math.floor((Date.now() - cached.timestamp) / 1000);

  return res.json({
    ok: true,
    dfsId,
    workerRunning: true,
    lastUpdate: cached.timestamp,
    ageSeconds,
    playerCount: cached.players.length,
    meta: cached.meta
  });
});

// ------------------------------------------------------
// Start server
// ------------------------------------------------------
app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 DFS + Squiggle backend running on port ${port}`);
});
