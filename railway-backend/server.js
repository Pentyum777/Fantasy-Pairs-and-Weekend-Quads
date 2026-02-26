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
// GLOBAL CORS (applies to ALL responses, including 404)
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

    // ✅ Create directory: selections/<season>/<gameType>/
    const dirPath = path.join(
      SELECTIONS_ROOT,
      String(safeSeason),
      normalizedGameType
    );
    ensureDir(dirPath);

    // ✅ Save file: custom_pairs_round_0.json
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
    data: { punterNames: [], picks: [] }, // ✅ never null
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

    if (g.complete === 100) {
      return {
        homeScore: g.hscore ?? 0,
        awayScore: g.ascore ?? 0,
        quarter: "Final",
        clock: "FT",
        status: "Full Time",
      };
    }

    if (g.complete > 0) {
      return {
        homeScore: g.hscore ?? 0,
        awayScore: g.ascore ?? 0,
        quarter: g.timestr || "",
        clock: "",
        status: "In Progress",
      };
    }

    return {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "Upcoming",
    };
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
// Fantasy endpoint (DFS + Squiggle) — hardened
// ------------------------------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const cdMatchId = req.params.matchId;

  console.log("➡ Incoming CD_M matchId:", cdMatchId);

  const dfsId = dfsMap[cdMatchId];
  const squiggleGameId = squiggleMap[cdMatchId];

  if (!dfsId) {
    res.header("Access-Control-Allow-Origin", "*");
    return res.status(404).json({
      error: "No DFS mapping for matchId",
      matchId: cdMatchId,
      message: "This CD_M ID does not exist in dfs_map.json",
    });
  }

  let dfsData;
  try {
    dfsData = await scrapeDFS(dfsId);

    if (!dfsData || typeof dfsData !== "object") {
      throw new Error("DFS returned invalid payload");
    }

    if (!Array.isArray(dfsData.players)) {
      throw new Error("DFS payload missing 'players' array");
    }

    const normalisedPlayers = dfsData.players
      .filter((p) => p && p.id)
      .map((p) => ({
        id: String(p.id),
        fantasyPoints: p.fantasyPoints ?? 0,
        goals: p.goals ?? 0,
        behinds: p.behinds ?? 0,
        disposals: p.disposals ?? 0,
        marks: p.marks ?? 0,
        tackles: p.tackles ?? 0,
        hitouts: p.hitouts ?? 0,
        clearances: p.clearances ?? 0,
        metresGained: p.metresGained ?? 0,
        goalAssists: p.goalAssists ?? 0,
        timeOnGroundPercentage: p.timeOnGroundPercentage ?? 0,
      }));

    dfsData.players = normalisedPlayers;
  } catch (err) {
    console.error("💥 DFS error:", err);
    res.header("Access-Control-Allow-Origin", "*");
    return res.status(500).json({
      error: "DFS fetch failed",
      details: String(err),
      matchId: cdMatchId,
      dfsId,
    });
  }

  let meta = {
    homeScore: 0,
    awayScore: 0,
    quarter: "",
    clock: "",
    status: "",
  };

  if (squiggleGameId) {
    try {
      meta = await fetchSquiggleMeta(squiggleGameId);
    } catch (err) {
      console.warn("⚠ Squiggle metadata failed:", err);
    }
  }

  return res.json({
    matchId: cdMatchId,
    homeScore: meta.homeScore ?? 0,
    awayScore: meta.awayScore ?? 0,
    quarter: meta.quarter ?? "",
    clock: meta.clock ?? "",
    status: meta.status ?? "",
    players: dfsData.players,
  });
});

// ------------------------------------------------------
// Metadata-only endpoint
// ------------------------------------------------------
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;
  const squiggleGameId = squiggleMap[matchId];

  if (!squiggleGameId) {
    res.header("Access-Control-Allow-Origin", "*");
    return res.status(404).json({ error: "No Squiggle mapping for matchId" });
  }

  try {
    const meta = await fetchSquiggleMeta(squiggleGameId);
    res.json({ matchId, match: meta });
  } catch (err) {
    console.error("Squiggle meta error:", err);
    res.header("Access-Control-Allow-Origin", "*");
    res.status(500).json({ error: String(err) });
  }
});

// ------------------------------------------------------
// Persistent season results
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
// Start server
// ------------------------------------------------------
app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 DFS + Squiggle backend running on port ${port}`);
});