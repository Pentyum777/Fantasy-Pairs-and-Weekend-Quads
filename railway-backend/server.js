// server.js
global.liveStatsCache = {};

import { startDFSWorker } from "./dfs_puppeteer_worker.js";
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
  startDFSWorker(String(dfsId));
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
