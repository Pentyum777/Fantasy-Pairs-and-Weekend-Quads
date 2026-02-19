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
// Shared helpers
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
  res.send("DFS + Squiggle backend is running");
});

// ------------------------------------------------------
// Live selections (persistent, per gameType)
// ------------------------------------------------------

// Save selections (live state, shared, per gameType)
app.post("/saveSelections", (req, res) => {
  try {
    const { gameType, punterNames, picks } = req.body;

    if (!gameType) {
      return res.status(400).json({ error: "gameType is required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      return res.status(400).json({ error: "Invalid gameType" });
    }

    ensureDir(SELECTIONS_ROOT);

    const filePath = path.join(SELECTIONS_ROOT, `${normalizedGameType}.json`);
    const payload = {
      lastUpdated: Date.now(),
      punterNames: Array.isArray(punterNames) ? punterNames : [],
      picks: Array.isArray(picks) ? picks : [],
    };

    fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), "utf8");

    console.log(
      `💾 Saved selections for gameType=${normalizedGameType} at ${payload.lastUpdated}`
    );

    res.json({
      ok: true,
      lastUpdated: payload.lastUpdated,
    });
  } catch (err) {
    console.error("💥 saveSelections error:", err);
    res.status(500).json({ error: "Failed to save selections" });
  }
});

// Load selections (live state, shared, per gameType)
app.get("/loadSelections", (req, res) => {
  try {
    const gameType = req.query.gameType;

    if (!gameType) {
      return res.status(400).json({ error: "gameType is required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      return res.status(400).json({ error: "Invalid gameType" });
    }

    const filePath = path.join(SELECTIONS_ROOT, `${normalizedGameType}.json`);

    if (!fs.existsSync(filePath)) {
      return res.json({
        ok: true,
        lastUpdated: 0,
        data: null,
      });
    }

    const json = JSON.parse(fs.readFileSync(filePath, "utf8"));

    res.json({
      ok: true,
      lastUpdated: json.lastUpdated || 0,
      data: {
        punterNames: json.punterNames || [],
        picks: json.picks || [],
      },
    });
  } catch (err) {
    console.error("💥 loadSelections error:", err);
    res.status(500).json({ error: "Failed to load selections" });
  }
});

// ------------------------------------------------------
// Squiggle metadata fetcher
// ------------------------------------------------------
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

// ------------------------------------------------------
// Fantasy endpoint (DFS + Squiggle)
// ------------------------------------------------------
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

// ------------------------------------------------------
// Metadata-only endpoint
// ------------------------------------------------------
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

// ------------------------------------------------------
// Persistent season results (unchanged)
// ------------------------------------------------------
app.post("/saveRoundResults", (req, res) => {
  try {
    const { season, round, gameType, punters } = req.body;

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
      return JSON.parse(fs.readFileSync(fullPath, "utf8"));
    });

    res.json({ ok: true, results });
  } catch (err) {
    console.error("💥 seasonResults error:", err);
    res.status(500).json({ error: "Failed to load season results" });
  }
});

// ------------------------------------------------------
// Start server
// ------------------------------------------------------
app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 DFS + Squiggle backend running on port ${port}`);
});
