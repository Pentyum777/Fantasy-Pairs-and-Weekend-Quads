import express from "express";
import cors from "cors";
import fs from "fs";

import { getDFSStatsForMatch } from "./dfscache.js";
import { getSquiggleStatusForMatch } from "./squiggle_service.js";
import { startLiveDFSLoop } from "./livescheduler.js";

// Load JSON maps manually (Railway-safe)
import path from "path";

const squiggleMap = JSON.parse(
  fs.readFileSync(path.resolve("railway-backend/squiggle_map.json"), "utf8")
);

const dfsMap = JSON.parse(
  fs.readFileSync(path.resolve("railway-backend/dfs_map.json"), "utf8")
);

console.log("🚀 DFS + Squiggle backend starting...");

const port = process.env.PORT || 8080;
const app = express();

// ------------------------------------------------------
// CORS + Preflight
// ------------------------------------------------------
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(200);
  next();
});

app.use(cors({ origin: "*" }));
app.use(express.json());

// ------------------------------------------------------
// Root route
// ------------------------------------------------------
app.get("/", (req, res) => {
  res.send("DFS + Squiggle backend is running");
});

// ------------------------------------------------------
// In-memory per-game-type selections (live state)
// ------------------------------------------------------

let selectionsByGameType = {};

// Save selections
app.post("/saveSelections", (req, res) => {
  const { gameType, season, round, punterNames, picks } = req.body;

  if (!gameType || !season || !round) {
    return res.status(400).json({
      error: "gameType, season, and round are required",
    });
  }

  const key = `${gameType}_${season}_${round}`;

  selectionsByGameType[key] = {
    lastUpdated: Date.now(),
    data: { punterNames, picks },
  };

  console.log(`💾 Saved selections for ${key}`);

  res.json({
    ok: true,
    lastUpdated: selectionsByGameType[key].lastUpdated,
  });
});

// Load selections
app.get("/loadSelections", (req, res) => {
  const { gameType, season, round } = req.query;

  if (!gameType || !season || !round) {
    return res.status(400).json({
      error: "gameType, season, and round are required",
    });
  }

  const key = `${gameType}_${season}_${round}`;
  const snapshot = selectionsByGameType[key];

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
// Fantasy stats endpoint (DFS + Squiggle)
// ------------------------------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const dfsId = dfsMap[matchId];
  const squiggleId = squiggleMap[matchId];

  console.log("➡️ Incoming matchId:", matchId);
  console.log("➡️ DFS ID:", dfsId);
  console.log("➡️ Squiggle ID:", squiggleId);

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  try {
    const dfsData = await getDFSStatsForMatch(matchId);

    let status = "Upcoming";
    if (squiggleId) {
      status = await getSquiggleStatusForMatch(matchId);
    }

    res.json({
      matchId,
      status,
      players: dfsData.players,
    });
  } catch (err) {
    console.error("💥 /fantasy error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// ------------------------------------------------------
// Squiggle status-only endpoint
// ------------------------------------------------------
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;
  const squiggleId = squiggleMap[matchId];

  if (!squiggleId) {
    return res.status(404).json({ error: "No Squiggle mapping for matchId" });
  }

  try {
    const status = await getSquiggleStatusForMatch(matchId);
    res.json({ matchId, status });
  } catch (err) {
    console.error("💥 /meta error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// ------------------------------------------------------
// Start server + live scheduler
// ------------------------------------------------------
app.listen(port, "0.0.0.0", () => {
  console.log(`✅ DFS + Squiggle backend running on port ${port}`);
  startLiveDFSLoop();
});