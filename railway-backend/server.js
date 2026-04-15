// server.js

import express from "express";
import fs from "fs";
import path from "path";
import cors from "cors";
import { fileURLToPath } from "url";
import { scrapeDFS } from "./dfs_scraper.js";
import { startRoundCompletionScheduler } from "./round_completion_scheduler.js";
import pkg from "pg";
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load mapping files
const dfsMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "dfs_map.json"), "utf8")
);

const squiggleMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "squiggle_map.json"), "utf8")
);

console.log("🚀 DFS + Squiggle backend starting...");

const port = process.env.PORT || 8080;
const app = express();

app.use(cors({ origin: "*", methods: ["GET", "POST", "OPTIONS"] }));
app.options("*", cors());
app.use(express.json());

// ------------------------------------------------------
// Helpers
// ------------------------------------------------------
const SEASON_RESULTS_ROOT = path.join("/data", "season_results");

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function normalizeGameType(gameType) {
  if (!gameType) return null;
  return String(gameType).trim().toLowerCase();
}

function calculateFantasyPoints(p) {
  return (
    (p.kicks ?? 0) * 3 +
    (p.handballs ?? 0) * 2 +
    (p.marks ?? 0) * 3 +
    (p.tackles ?? 0) * 4 +
    (p.freesFor ?? 0) * 1 +
    (p.freesAgainst ?? 0) * -3 +
    (p.hitouts ?? 0) * 1 +
    (p.goals ?? 0) * 6 +
    (p.behinds ?? 0) * 1
  );
}

// ------------------------------------------------------
// Root
// ------------------------------------------------------
app.get("/", (req, res) => {
  res.json({ ok: true, message: "DFS + Squiggle backend is running" });
});

// ------------------------------------------------------
// Save selections (Postgres)
// ------------------------------------------------------
app.post("/saveSelections", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");

  try {
    const { gameType, season, round, punterNames, picks } = req.body;

    if (!gameType) {
      return res.status(400).json({ error: "gameType is required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      return res.status(400).json({ error: "Invalid gameType" });
    }

    const safeSeason = season ?? 0;
    const safeRound = round ?? 0;

    const punterNamesJson = JSON.stringify(
      Array.isArray(punterNames) ? punterNames : []
    );

    const picksJson = JSON.stringify(
      Array.isArray(picks) ? picks : []
    );

    const result = await pool.query(
      `
      INSERT INTO selections (season, game_type, round, punter_names, picks)
      VALUES ($1, $2, $3, $4::jsonb, $5::jsonb)
      ON CONFLICT (season, game_type, round)
      DO UPDATE SET
        punter_names = EXCLUDED.punter_names,
        picks = EXCLUDED.picks,
        updated_at = NOW()
      RETURNING updated_at
      `,
      [
        safeSeason,
        normalizedGameType,
        safeRound,
        punterNamesJson,
        picksJson,
      ]
    );

    const updatedAt = result.rows[0]?.updated_at
      ? new Date(result.rows[0].updated_at).getTime()
      : Date.now();

    console.log(
      `💾 Saved selections → season=${safeSeason}, gameType=${normalizedGameType}, round=${safeRound}`
    );

    res.json({ ok: true, lastUpdated: updatedAt });
  } catch (err) {
    console.error("💥 saveSelections error:", err);
    res.status(500).json({ error: "Failed to save selections" });
  }
});

// ------------------------------------------------------
// Load selections (Postgres)
// ------------------------------------------------------
app.get("/loadSelections", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");

  try {
    const gameType = req.query.gameType;
    const season = req.query.season;
    const round = req.query.round;

    if (!gameType) {
      return res.status(400).json({ error: "gameType is required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      return res.status(400).json({ error: "Invalid gameType" });
    }

    const safeSeason = season ?? 0;
    const safeRound = round ?? 0;

    const result = await pool.query(
      `
      SELECT punter_names, picks, updated_at
      FROM selections
      WHERE season = $1 AND game_type = $2 AND round = $3
      LIMIT 1
      `,
      [safeSeason, normalizedGameType, safeRound]
    );

    if (result.rows.length === 0) {
      return res.json({
        ok: true,
        lastUpdated: 0,
        data: { punterNames: [], picks: [] },
      });
    }

    const row = result.rows[0];

    const lastUpdated = row.updated_at
      ? new Date(row.updated_at).getTime()
      : 0;

    res.json({
      ok: true,
      lastUpdated,
      data: {
        punterNames: Array.isArray(row.punter_names)
          ? row.punter_names
          : [],
        picks: Array.isArray(row.picks) ? row.picks : [],
      },
    });
  } catch (err) {
    console.error("💥 loadSelections error:", err);
    res.status(500).json({ error: "Failed to load selections" });
  }
});

// ------------------------------------------------------
// Save round results (filesystem)
// ------------------------------------------------------
app.post("/saveRoundResults", (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");

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

// ------------------------------------------------------
// Load season results
// ------------------------------------------------------
app.get("/seasonResults", (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");

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
// Load all completed rounds for a season + gameType (Postgres)
// Used by Championship screen on startup to restore history
// ------------------------------------------------------
app.get("/completedRounds", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");

  try {
    const { season, gameType } = req.query;

    if (!season || !gameType) {
      return res.status(400).json({ error: "season and gameType are required" });
    }

    const normalizedGameType = normalizeGameType(gameType);
    if (!normalizedGameType) {
      return res.status(400).json({ error: "Invalid gameType" });
    }

    // Load every saved round for this season + gameType, ordered by round number
    const result = await pool.query(
      `
      SELECT round, punter_names, picks, updated_at
      FROM selections
      WHERE season = $1 AND game_type = $2
      ORDER BY round ASC
      `,
      [Number(season), normalizedGameType]
    );

    // Debug: log what we found
    console.log(
      `📋 completedRounds query: season=${season}, gameType=${normalizedGameType}, rows=${result.rows.length}`
    );
    for (const row of result.rows) {
      const names = Array.isArray(row.punter_names) ? row.punter_names.filter(n => n && n.trim()) : [];
      const picks = Array.isArray(row.picks) ? row.picks : [];
      console.log(
        `  Round ${row.round}: ${names.length} named punters, ${picks.length} pick rows`
      );
    }

    const rounds = result.rows.map((row) => ({
      round: row.round,
      updatedAt: row.updated_at ? new Date(row.updated_at).getTime() : 0,
      punterNames: Array.isArray(row.punter_names) ? row.punter_names : [],
      picks: Array.isArray(row.picks) ? row.picks : [],
    }));

    console.log(
      `📋 completedRounds → season=${season}, gameType=${normalizedGameType}, count=${rounds.length}`
    );

    res.json({ ok: true, rounds });
  } catch (err) {
    console.error("💥 completedRounds error:", err);
    res.status(500).json({ error: "Failed to load completed rounds" });
  }
});

// ------------------------------------------------------

// ------------------------------------------------------

// ------------------------------------------------------
// Full match stats for a given matchId
// Returns all players from match_stats table (seeded from game files)
// Falls back to live DFS feed for current rounds
// ------------------------------------------------------
app.get("/matchStats/:matchId", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  const cdMatchId = req.params.matchId;
  const dfsId = dfsMap[cdMatchId];

  try {
    // 1. Try live DFS feed first (works for current round)
    if (dfsId) {
      const dfsPlayers = await scrapeDFS(dfsId);
      if (dfsPlayers && dfsPlayers.length > 0) {
        return res.json({
          ok: true,
          players: dfsPlayers.map(p => ({ ...p, af: calculateFantasyPoints(p) }))
        });
      }
    }

    // 2. Fall back to match_stats table (full player list for historical rounds)
    const result = await pool.query(
      `SELECT player_id, player_name, team,
              kicks, handballs, disposals, marks, tackles,
              hitouts, frees_for, frees_against, goals, behinds, tog, fantasy_points
       FROM match_stats
       WHERE match_id = $1
       ORDER BY fantasy_points DESC`,
      [cdMatchId]
    );

    if (result.rows.length > 0) {
      const players = result.rows.map(r => ({
        playerId:              r.player_id,
        playerName:            r.player_name,
        teamAbbr:              r.team,
        kicks:                 r.kicks,
        handballs:             r.handballs,
        disposals:             r.disposals,
        marks:                 r.marks,
        tackles:               r.tackles,
        hitouts:               r.hitouts,
        freesFor:              r.frees_for,
        freesAgainst:          r.frees_against,
        goals:                 r.goals,
        behinds:               r.behinds,
        timeOnGroundPercentage: r.tog,
        fantasyPoints:         r.fantasy_points,
        af:                    r.fantasy_points,
      }));
      return res.json({ ok: true, players });
    }

    // 3. Nothing found
    res.json({ ok: true, players: [] });

  } catch (err) {
    console.error("matchStats error:", err);
    res.status(500).json({ error: "Failed" });
  }
});



// 2026 fixture map: matchId -> {home, away, round}
const FIXTURES_2026 = {"CD_M20260140101": {"home": "CAR", "away": "RIC", "round": 1}, "CD_M20260140102": {"home": "ESS", "away": "HAW", "round": 1}, "CD_M20260140103": {"home": "WBD", "away": "GWS", "round": 1}, "CD_M20260140104": {"home": "GEE", "away": "FRE", "round": 1}, "CD_M20260140105": {"home": "SYD", "away": "BRL", "round": 1}, "CD_M20260140106": {"home": "COL", "away": "ADE", "round": 1}, "CD_M20260140107": {"home": "NTH", "away": "PTA", "round": 1}, "CD_M20260140108": {"home": "MEL", "away": "STK", "round": 1}, "CD_M20260140109": {"home": "GCS", "away": "WCE", "round": 1}, "CD_M20260140201": {"home": "HAW", "away": "SYD", "round": 2}, "CD_M20260140202": {"home": "ADE", "away": "WBD", "round": 2}, "CD_M20260140203": {"home": "RIC", "away": "GCS", "round": 2}, "CD_M20260140204": {"home": "GWS", "away": "STK", "round": 2}, "CD_M20260140205": {"home": "FRE", "away": "MEL", "round": 2}, "CD_M20260140206": {"home": "PTA", "away": "ESS", "round": 2}, "CD_M20260140207": {"home": "WCE", "away": "NTH", "round": 2}, "CD_M20260140301": {"home": "GEE", "away": "ADE", "round": 3}, "CD_M20260140302": {"home": "COL", "away": "GWS", "round": 3}, "CD_M20260140303": {"home": "STK", "away": "BRL", "round": 3}, "CD_M20260140304": {"home": "FRE", "away": "RIC", "round": 3}, "CD_M20260140305": {"home": "ESS", "away": "NTH", "round": 3}, "CD_M20260140306": {"home": "PTA", "away": "WCE", "round": 3}, "CD_M20260140307": {"home": "CAR", "away": "MEL", "round": 3}, "CD_M20260140401": {"home": "BRL", "away": "COL", "round": 4}, "CD_M20260140402": {"home": "NTH", "away": "CAR", "round": 4}, "CD_M20260140403": {"home": "ADE", "away": "FRE", "round": 4}, "CD_M20260140404": {"home": "RIC", "away": "PTA", "round": 4}, "CD_M20260140405": {"home": "WCE", "away": "SYD", "round": 4}, "CD_M20260140406": {"home": "MEL", "away": "GCS", "round": 4}, "CD_M20260140407": {"home": "WBD", "away": "ESS", "round": 4}, "CD_M20260140408": {"home": "HAW", "away": "GEE", "round": 4}, "CD_M20260140501": {"home": "ADE", "away": "CAR", "round": 5}, "CD_M20260140502": {"home": "COL", "away": "FRE", "round": 5}, "CD_M20260140503": {"home": "NTH", "away": "BRL", "round": 5}, "CD_M20260140504": {"home": "ESS", "away": "MEL", "round": 5}, "CD_M20260140505": {"home": "SYD", "away": "GCS", "round": 5}, "CD_M20260140506": {"home": "HAW", "away": "WBD", "round": 5}, "CD_M20260140507": {"home": "GEE", "away": "WCE", "round": 5}, "CD_M20260140508": {"home": "GWS", "away": "RIC", "round": 5}, "CD_M20260140509": {"home": "PTA", "away": "STK", "round": 5}, "CD_M20260140601": {"home": "CAR", "away": "COL", "round": 6}, "CD_M20260140602": {"home": "GEE", "away": "WBD", "round": 6}, "CD_M20260140603": {"home": "SYD", "away": "GWS", "round": 6}, "CD_M20260140604": {"home": "GCS", "away": "ESS", "round": 6}, "CD_M20260140605": {"home": "HAW", "away": "PTA", "round": 6}, "CD_M20260140606": {"home": "ADE", "away": "STK", "round": 6}, "CD_M20260140607": {"home": "NTH", "away": "RIC", "round": 6}, "CD_M20260140608": {"home": "MEL", "away": "BRL", "round": 6}, "CD_M20260140609": {"home": "WCE", "away": "FRE", "round": 6}, "CD_M20260140701": {"home": "WBD", "away": "SYD", "round": 7}, "CD_M20260140702": {"home": "RIC", "away": "MEL", "round": 7}, "CD_M20260140703": {"home": "HAW", "away": "GCS", "round": 7}, "CD_M20260140704": {"home": "ESS", "away": "COL", "round": 7}, "CD_M20260140705": {"home": "PTA", "away": "GEE", "round": 7}, "CD_M20260140706": {"home": "FRE", "away": "CAR", "round": 7}, "CD_M20260140707": {"home": "STK", "away": "WCE", "round": 7}, "CD_M20260140708": {"home": "BRL", "away": "ADE", "round": 7}, "CD_M20260140709": {"home": "GWS", "away": "NTH", "round": 7}, "CD_M20260140801": {"home": "COL", "away": "HAW", "round": 8}, "CD_M20260140802": {"home": "WBD", "away": "FRE", "round": 8}, "CD_M20260140803": {"home": "ADE", "away": "PTA", "round": 8}, "CD_M20260140804": {"home": "ESS", "away": "BRL", "round": 8}, "CD_M20260140805": {"home": "WCE", "away": "RIC", "round": 8}, "CD_M20260140806": {"home": "GEE", "away": "NTH", "round": 8}, "CD_M20260140807": {"home": "CAR", "away": "STK", "round": 8}, "CD_M20260140808": {"home": "SYD", "away": "MEL", "round": 8}, "CD_M20260140809": {"home": "GCS", "away": "GWS", "round": 8}, "CD_M20260140901": {"home": "FRE", "away": "HAW", "round": 9}, "CD_M20260140902": {"home": "BRL", "away": "CAR", "round": 9}, "CD_M20260140903": {"home": "PTA", "away": "WBD", "round": 9}, "CD_M20260140904": {"home": "NTH", "away": "SYD", "round": 9}, "CD_M20260140905": {"home": "GWS", "away": "ESS", "round": 9}, "CD_M20260140906": {"home": "GCS", "away": "STK", "round": 9}, "CD_M20260140907": {"home": "GEE", "away": "COL", "round": 9}, "CD_M20260140908": {"home": "MEL", "away": "WCE", "round": 9}, "CD_M20260140909": {"home": "RIC", "away": "ADE", "round": 9}, "CD_M20260141001": {"home": "BRL", "away": "GEE", "round": 10}, "CD_M20260141002": {"home": "SYD", "away": "COL", "round": 10}, "CD_M20260141003": {"home": "GCS", "away": "PTA", "round": 10}, "CD_M20260141004": {"home": "ADE", "away": "NTH", "round": 10}, "CD_M20260141005": {"home": "MEL", "away": "HAW", "round": 10}, "CD_M20260141006": {"home": "CAR", "away": "WBD", "round": 10}, "CD_M20260141007": {"home": "ESS", "away": "FRE", "round": 10}, "CD_M20260141008": {"home": "STK", "away": "RIC", "round": 10}, "CD_M20260141009": {"home": "WCE", "away": "GWS", "round": 10}, "CD_M20260141101": {"home": "HAW", "away": "ADE", "round": 11}, "CD_M20260141102": {"home": "RIC", "away": "ESS", "round": 11}, "CD_M20260141103": {"home": "FRE", "away": "STK", "round": 11}, "CD_M20260141104": {"home": "NTH", "away": "GCS", "round": 11}, "CD_M20260141105": {"home": "GEE", "away": "SYD", "round": 11}, "CD_M20260141106": {"home": "COL", "away": "WCE", "round": 11}, "CD_M20260141107": {"home": "PTA", "away": "CAR", "round": 11}, "CD_M20260141108": {"home": "GWS", "away": "BRL", "round": 11}, "CD_M20260141109": {"home": "WBD", "away": "MEL", "round": 11}, "CD_M20260141201": {"home": "STK", "away": "HAW", "round": 12}, "CD_M20260141202": {"home": "CAR", "away": "GEE", "round": 12}, "CD_M20260141203": {"home": "SYD", "away": "RIC", "round": 12}, "CD_M20260141204": {"home": "BRL", "away": "FRE", "round": 12}, "CD_M20260141205": {"home": "WBD", "away": "COL", "round": 12}, "CD_M20260141206": {"home": "MEL", "away": "GWS", "round": 12}, "CD_M20260141207": {"home": "WCE", "away": "ESS", "round": 12}, "CD_M20260141301": {"home": "ADE", "away": "GEE", "round": 13}, "CD_M20260141302": {"home": "HAW", "away": "WBD", "round": 13}, "CD_M20260141303": {"home": "NTH", "away": "FRE", "round": 13}, "CD_M20260141304": {"home": "GCS", "away": "BRL", "round": 13}, "CD_M20260141305": {"home": "WCE", "away": "PTA", "round": 13}, "CD_M20260141306": {"home": "SYD", "away": "STK", "round": 13}, "CD_M20260141307": {"home": "ESS", "away": "CAR", "round": 13}, "CD_M20260141308": {"home": "COL", "away": "MEL", "round": 13}, "CD_M20260141401": {"home": "WBD", "away": "ADE", "round": 14}, "CD_M20260141402": {"home": "GEE", "away": "GCS", "round": 14}, "CD_M20260141403": {"home": "MEL", "away": "ESS", "round": 14}, "CD_M20260141404": {"home": "NTH", "away": "WCE", "round": 14}, "CD_M20260141405": {"home": "PTA", "away": "SYD", "round": 14}, "CD_M20260141406": {"home": "RIC", "away": "BRL", "round": 14}, "CD_M20260141407": {"home": "STK", "away": "GWS", "round": 14}, "CD_M20260141501": {"home": "FRE", "away": "GEE", "round": 15}, "CD_M20260141502": {"home": "GCS", "away": "HAW", "round": 15}, "CD_M20260141503": {"home": "ADE", "away": "MEL", "round": 15}, "CD_M20260141504": {"home": "GWS", "away": "CAR", "round": 15}, "CD_M20260141505": {"home": "COL", "away": "PTA", "round": 15}, "CD_M20260141506": {"home": "RIC", "away": "NTH", "round": 15}, "CD_M20260141507": {"home": "STK", "away": "WBD", "round": 15}, "CD_M20260141601": {"home": "BRL", "away": "SYD", "round": 16}, "CD_M20260141602": {"home": "CAR", "away": "WCE", "round": 16}, "CD_M20260141603": {"home": "COL", "away": "RIC", "round": 16}, "CD_M20260141605": {"home": "HAW", "away": "GWS", "round": 16}, "CD_M20260141606": {"home": "NTH", "away": "ESS", "round": 16}, "CD_M20260141607": {"home": "PTA", "away": "ADE", "round": 16}, "CD_M20260141604": {"home": "FRE", "away": "GCS", "round": 16}, "CD_M20260141701": {"home": "ESS", "away": "STK", "round": 17}, "CD_M20260141702": {"home": "GEE", "away": "BRL", "round": 17}, "CD_M20260141703": {"home": "GCS", "away": "COL", "round": 17}, "CD_M20260141704": {"home": "GWS", "away": "FRE", "round": 17}, "CD_M20260141705": {"home": "HAW", "away": "MEL", "round": 17}, "CD_M20260141707": {"home": "RIC", "away": "CAR", "round": 17}, "CD_M20260141708": {"home": "SYD", "away": "WBD", "round": 17}, "CD_M20260141706": {"home": "PTA", "away": "NTH", "round": 17}, "CD_M20260141709": {"home": "WCE", "away": "ADE", "round": 17}, "CD_M20260141802": {"home": "BRL", "away": "ESS", "round": 18}, "CD_M20260141803": {"home": "CAR", "away": "HAW", "round": 18}, "CD_M20260141804": {"home": "COL", "away": "NTH", "round": 18}, "CD_M20260141806": {"home": "GWS", "away": "GEE", "round": 18}, "CD_M20260141807": {"home": "MEL", "away": "RIC", "round": 18}, "CD_M20260141808": {"home": "STK", "away": "PTA", "round": 18}, "CD_M20260141809": {"home": "WBD", "away": "WCE", "round": 18}, "CD_M20260141801": {"home": "ADE", "away": "GCS", "round": 18}, "CD_M20260141805": {"home": "FRE", "away": "SYD", "round": 18}, "CD_M20260141901": {"home": "COL", "away": "CAR", "round": 19}, "CD_M20260141902": {"home": "ESS", "away": "GWS", "round": 19}, "CD_M20260141903": {"home": "GEE", "away": "STK", "round": 19}, "CD_M20260141904": {"home": "GCS", "away": "WBD", "round": 19}, "CD_M20260141905": {"home": "NTH", "away": "MEL", "round": 19}, "CD_M20260141907": {"home": "RIC", "away": "HAW", "round": 19}, "CD_M20260141908": {"home": "SYD", "away": "ADE", "round": 19}, "CD_M20260141906": {"home": "PTA", "away": "FRE", "round": 19}, "CD_M20260141909": {"home": "WCE", "away": "BRL", "round": 19}, "CD_M20260142002": {"home": "BRL", "away": "PTA", "round": 20}, "CD_M20260142003": {"home": "CAR", "away": "GCS", "round": 20}, "CD_M20260142005": {"home": "GWS", "away": "SYD", "round": 20}, "CD_M20260142006": {"home": "HAW", "away": "ESS", "round": 20}, "CD_M20260142007": {"home": "NTH", "away": "STK", "round": 20}, "CD_M20260142008": {"home": "MEL", "away": "GEE", "round": 20}, "CD_M20260142009": {"home": "WBD", "away": "RIC", "round": 20}, "CD_M20260142001": {"home": "ADE", "away": "COL", "round": 20}, "CD_M20260142004": {"home": "FRE", "away": "WCE", "round": 20}, "CD_M20260142101": {"home": "CAR", "away": "BRL", "round": 21}, "CD_M20260142102": {"home": "COL", "away": "GEE", "round": 21}, "CD_M20260142103": {"home": "ESS", "away": "ADE", "round": 21}, "CD_M20260142105": {"home": "GCS", "away": "MEL", "round": 21}, "CD_M20260142106": {"home": "HAW", "away": "NTH", "round": 21}, "CD_M20260142108": {"home": "RIC", "away": "WCE", "round": 21}, "CD_M20260142109": {"home": "STK", "away": "SYD", "round": 21}, "CD_M20260142107": {"home": "PTA", "away": "GWS", "round": 21}, "CD_M20260142104": {"home": "FRE", "away": "WBD", "round": 21}, "CD_M20260142202": {"home": "BRL", "away": "HAW", "round": 22}, "CD_M20260142203": {"home": "GEE", "away": "ESS", "round": 22}, "CD_M20260142204": {"home": "GWS", "away": "GCS", "round": 22}, "CD_M20260142205": {"home": "MEL", "away": "FRE", "round": 22}, "CD_M20260142206": {"home": "STK", "away": "CAR", "round": 22}, "CD_M20260142207": {"home": "SYD", "away": "PTA", "round": 22}, "CD_M20260142209": {"home": "WBD", "away": "NTH", "round": 22}, "CD_M20260142201": {"home": "ADE", "away": "RIC", "round": 22}, "CD_M20260142208": {"home": "WCE", "away": "COL", "round": 22}, "CD_M20260142301": {"home": "BRL", "away": "GCS", "round": 23}, "CD_M20260142302": {"home": "ESS", "away": "SYD", "round": 23}, "CD_M20260142304": {"home": "GWS", "away": "WCE", "round": 23}, "CD_M20260142305": {"home": "HAW", "away": "COL", "round": 23}, "CD_M20260142306": {"home": "NTH", "away": "GEE", "round": 23}, "CD_M20260142308": {"home": "RIC", "away": "STK", "round": 23}, "CD_M20260142309": {"home": "WBD", "away": "CAR", "round": 23}, "CD_M20260142307": {"home": "PTA", "away": "MEL", "round": 23}, "CD_M20260142303": {"home": "FRE", "away": "ADE", "round": 23}, "CD_M20260142402": {"home": "COL", "away": "BRL", "round": 24}, "CD_M20260142403": {"home": "CAR", "away": "FRE", "round": 24}, "CD_M20260142404": {"home": "ESS", "away": "PTA", "round": 24}, "CD_M20260142405": {"home": "GEE", "away": "RIC", "round": 24}, "CD_M20260142406": {"home": "MEL", "away": "WBD", "round": 24}, "CD_M20260142407": {"home": "STK", "away": "GCS", "round": 24}, "CD_M20260142408": {"home": "SYD", "away": "NTH", "round": 24}, "CD_M20260142401": {"home": "ADE", "away": "GWS", "round": 24}, "CD_M20260142409": {"home": "WCE", "away": "HAW", "round": 24}};

// ============================================================
// SCOUT FEATURE — player stats, access control, flags
// ============================================================

// Scout access allowlist — backend-controlled so new emails
// can be added via SCOUT_EMAILS env var without a rebuild.
// Format: comma-separated emails e.g. "a@b.com,c@d.com"
function getScoutAllowList() {
  const envList = process.env.SCOUT_EMAILS ?? "wpenfold@bigpond.net.au,wayneliz7@outlook.com,paulfruin30@gmail.com";
  return envList.split(",").map(e => e.trim().toLowerCase()).filter(Boolean);
}

// GET /scoutAccess?email=...
// Returns {allowed: true/false}
app.get("/scoutAccess", (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  const email = (req.query.email ?? "").trim().toLowerCase();
  const allowed = getScoutAllowList().includes(email);
  res.json({ ok: true, allowed });
});

// GET /playerSeasonStats/:season
// Returns season averages for all players from match_stats table
app.get("/playerSeasonStats/:season", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const season = parseInt(req.params.season);
    const result = await pool.query(`
      WITH season_stats AS (
        SELECT
          player_id,
          (array_agg(player_name ORDER BY CASE WHEN player_name <> '' THEN 0 ELSE 1 END, player_name))[1] AS player_name,
          (array_agg(team        ORDER BY CASE WHEN team        <> '' THEN 0 ELSE 1 END, team       ))[1] AS team,
          COUNT(*)::int                             AS games,
          ROUND(AVG(fantasy_points))::int           AS af_avg,
          MAX(fantasy_points)                       AS af_best,
          ROUND(AVG(kicks))::int                    AS k_avg,
          ROUND(AVG(handballs))::int                AS hb_avg,
          ROUND(AVG(disposals))::int                AS d_avg,
          ROUND(AVG(marks))::int                    AS m_avg,
          ROUND(AVG(tackles))::int                  AS t_avg,
          ROUND(AVG(goals)::numeric, 1)::float      AS g_avg,
          ROUND(AVG(tog))::int                      AS tog_avg,
          -- Last game score (highest match_id = most recent)
          (array_agg(fantasy_points ORDER BY match_id DESC))[1] AS last_game,
          -- Last 3 games average
          ROUND(
            AVG(fantasy_points) FILTER (
              WHERE match_id IN (
                SELECT match_id FROM match_stats ms2
                WHERE ms2.player_id = match_stats.player_id
                  AND ms2.match_id LIKE $1
                  AND ms2.fantasy_points > 0
                ORDER BY match_id DESC
                LIMIT 3
              )
            )
          )::int AS last3_avg
        FROM match_stats
        WHERE match_id LIKE $1
          AND fantasy_points > 0
        GROUP BY player_id
      )
      SELECT * FROM season_stats
      ORDER BY af_avg DESC
    `, [`CD_M${season}%`]);
    res.json({ ok: true, players: result.rows });
  } catch (err) {
    console.error("playerSeasonStats error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// GET /namedSquad/:matchId
// Fetches named 22 from AFL.com.au for a given match.
// Returns {ok, named: [playerId, ...], available: true/false}
app.get("/namedSquad/:matchId", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  const matchId = req.params.matchId;
  try {
    // AFL website match data endpoint (unofficial but stable)
    const url = `https://www.afl.com.au/matches/${matchId}`;
    const apiUrl = `https://api.afl.com.au/cfs/afl/matchItem/${matchId}`;

    let named = [];
    let available = false;

    try {
      const response = await fetch(apiUrl, {
        headers: {
          "User-Agent": "Mozilla/5.0",
          "Accept": "application/json",
        },
        timeout: 8000,
      });

      if (response.ok) {
        const data = await response.json();
        // Extract player IDs from home and away lineups
        // AFL squads are now 23 players + emergencies (typically 2-3)
        const extractIds = (team) => {
          const lineup = team?.lineup ?? team?.players ?? [];
          return lineup
            .filter(p => p.position !== "SUB_22") // keep emergencies, exclude sub-22
            .map(p => p.player?.playerId ?? p.playerId ?? "")
            .filter(Boolean);
        };
        const homeIds = extractIds(data?.homeTeam ?? data?.home);
        const awayIds = extractIds(data?.awayTeam ?? data?.away);
        named = [...homeIds, ...awayIds];
        available = named.length > 0;
      }
    } catch (fetchErr) {
      console.warn("AFL lineup fetch failed:", fetchErr.message);
    }

    res.json({ ok: true, matchId, available, named });
  } catch (err) {
    console.error("namedSquad error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// GET /playerFlags/:season
// Returns all admin flags for a season
app.get("/playerFlags/:season", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const season = parseInt(req.params.season);
    // Create table if not exists (idempotent)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS player_flags (
        id SERIAL PRIMARY KEY,
        season INT NOT NULL,
        player_id TEXT NOT NULL,
        player_name TEXT,
        team TEXT,
        flag TEXT NOT NULL,  -- INJ, SUSP, REST, OUT
        note TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        UNIQUE(season, player_id)
      )
    `);
    const result = await pool.query(
      `SELECT player_id, player_name, team, flag, note FROM player_flags WHERE season = $1`,
      [season]
    );
    res.json({ ok: true, flags: result.rows });
  } catch (err) {
    console.error("playerFlags GET error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// POST /playerFlags
// Set or update a flag for a player
app.post("/playerFlags", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const { season, playerId, playerName, team, flag, note } = req.body;
    if (!season || !playerId || !flag) {
      return res.status(400).json({ error: "season, playerId, flag required" });
    }
    await pool.query(`
      CREATE TABLE IF NOT EXISTS player_flags (
        id SERIAL PRIMARY KEY,
        season INT NOT NULL,
        player_id TEXT NOT NULL,
        player_name TEXT,
        team TEXT,
        flag TEXT NOT NULL,
        note TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        UNIQUE(season, player_id)
      )
    `);
    await pool.query(`
      INSERT INTO player_flags (season, player_id, player_name, team, flag, note)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (season, player_id) DO UPDATE SET
        flag = EXCLUDED.flag,
        note = EXCLUDED.note,
        player_name = EXCLUDED.player_name,
        team = EXCLUDED.team
    `, [season, playerId, playerName ?? "", team ?? "", flag, note ?? ""]);
    res.json({ ok: true });
  } catch (err) {
    console.error("playerFlags POST error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// DELETE /playerFlags/:season/:playerId
// Remove a flag for a player
app.delete("/playerFlags/:season/:playerId", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const { season, playerId } = req.params;
    await pool.query(
      `DELETE FROM player_flags WHERE season = $1 AND player_id = $2`,
      [parseInt(season), playerId]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error("playerFlags DELETE error:", err);
    res.status(500).json({ error: "Failed" });
  }
});


// GET /draftedPlayers?season=&round=
// Returns all player IDs drafted across ALL game types for a round
app.get("/draftedPlayers", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const season = parseInt(req.query.season ?? 0);
    const round  = parseInt(req.query.round  ?? 0);

    const result = await pool.query(
      `SELECT picks FROM selections WHERE season = $1 AND round = $2`,
      [season, round]
    );

    const playerIds = new Set();
    for (const row of result.rows) {
      const picks = Array.isArray(row.picks) ? row.picks : [];
      for (const punterPicks of picks) {
        if (!Array.isArray(punterPicks)) continue;
        for (const pick of punterPicks) {
          const pid = pick?.playerId;
          if (pid && pid.trim()) playerIds.add(pid.trim());
        }
      }
    }

    res.json({ ok: true, playerIds: [...playerIds] });
  } catch (err) {
    console.error("draftedPlayers error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// GET /injuryList
// Scrapes the current AFL injury list article and returns structured player data
// The AFL publishes a weekly "Medical room" article with consistent formatting
app.get("/injuryList", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    // Fetch the injury list page which lists all current injuries
    const pageRes = await fetch(
      "https://www.afl.com.au/matches/injury-list",
      {
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "Accept": "text/html,application/xhtml+xml",
        },
        timeout: 10000,
      }
    );

    if (!pageRes.ok) {
      return res.json({ ok: true, players: [], source: "unavailable" });
    }

    const html = await pageRes.text();

    // The injury list page contains structured data in script tags
    // Extract the __NEXT_DATA__ or similar JSON payload
    const nextDataMatch = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);

    if (nextDataMatch) {
      try {
        const nextData = JSON.parse(nextDataMatch[1]);
        // Navigate to injury data in the Next.js page props
        const pageProps = nextData?.props?.pageProps;
        const injuries = pageProps?.injuryList ?? pageProps?.injuries ?? [];

        if (injuries.length > 0) {
          return res.json({ ok: true, players: injuries, source: "afl" });
        }
      } catch (_) {}
    }

    // Fallback: return empty — admin can manually flag players
    res.json({ ok: true, players: [], source: "unavailable" });

  } catch (err) {
    console.error("injuryList error:", err.message);
    res.json({ ok: true, players: [], source: "error", message: err.message });
  }
});


// GET /vsOpponentStats?season=&round=&gameType=
// Returns each player's average score vs their upcoming opponent
// Uses selections table to find matchups for this round/gameType
// then queries historical_scores for career averages
app.get("/vsOpponentStats", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const season   = parseInt(req.query.season   ?? 2026);
    const round    = parseInt(req.query.round    ?? 1);
    const gameType = req.query.gameType ?? "weekend_quads";

    // Check table exists
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'historical_scores'
      ) as exists
    `);
    if (!tableCheck.rows[0].exists) {
      return res.json({ ok: true, stats: [] });
    }

    // Build opponent map from FIXTURES_2026 for the requested round
    const teamOpponentMap = {}; // { "CAR": "COL", "COL": "CAR", ... }

    for (const [matchId, fixture] of Object.entries(FIXTURES_2026)) {
      if (fixture.round !== round) continue;
      teamOpponentMap[fixture.home] = fixture.away;
      teamOpponentMap[fixture.away] = fixture.home;
    }

    console.log(`vsOpponentStats round=${round}: teams=${Object.keys(teamOpponentMap).join(",")}`);

    if (Object.keys(teamOpponentMap).length === 0) {
      return res.json({ ok: true, stats: [], noData: true });
    }

    // Now calculate historical averages for each player vs their upcoming opponent
    const result = await pool.query(`
      SELECT
        hs.player_name,
        hs.team,
        $1::jsonb->hs.team AS upcoming_opponent,
        COUNT(*) AS games_vs,
        ROUND(AVG(hs.score))::int AS avg_vs_opponent
      FROM historical_scores hs
      WHERE hs.opponent = ($1::jsonb->>hs.team)
        AND hs.score > 0
        AND ($1::jsonb->>hs.team) IS NOT NULL
      GROUP BY hs.player_name, hs.team
      HAVING COUNT(*) >= 1
      ORDER BY avg_vs_opponent DESC
    `, [JSON.stringify(teamOpponentMap)]);

    res.json({ ok: true, stats: result.rows });
  } catch (err) {
    console.error("vsOpponentStats error:", err);
    res.status(500).json({ error: "Failed" });
  }
});


// GET /playerGameLog/:season/:playerName
// Returns all game scores for a player in a given season
app.get("/playerGameLog/:season/:playerName", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const season     = parseInt(req.params.season);
    const playerName = decodeURIComponent(req.params.playerName);

    const result = await pool.query(`
      SELECT
        match_id,
        fantasy_points AS score,
        kicks, handballs, disposals, marks, tackles, goals, behinds, tog
      FROM match_stats
      WHERE match_id LIKE $1
        AND player_name = $2
        AND fantasy_points > 0
      ORDER BY match_id ASC
    `, [`CD_M${season}%`, playerName]);

    // Map match_id to round number and opponent using FIXTURES_2026
    const rows = result.rows.map(r => {
      const m = r.match_id.match(/CD_M\d{4}014(\d{2})\d{2}/);
      const round = m ? parseInt(m[1]) : 0;
      // Find opponent from fixture map
      const fixture = FIXTURES_2026[r.match_id];
      // We need the player's team to know which side is the opponent
      // Use match_stats team column — query it separately or look up fixture
      const opponent = fixture
        ? null  // will resolve below with team info
        : null;
      return { ...r, round, fixture: fixture ?? null };
    });

    // Get player team from match_stats for opponent lookup
    const teamResult = await pool.query(
      `SELECT DISTINCT team FROM match_stats WHERE player_name = $1 AND team != '' LIMIT 1`,
      [playerName]
    );
    const playerTeam = teamResult.rows[0]?.team ?? '';

    const rowsWithOpponent = rows.map(r => {
      const fixture = r.fixture;
      let opponent = '';
      if (fixture && playerTeam) {
        opponent = fixture.home === playerTeam ? fixture.away : fixture.home;
      }
      const { fixture: _f, ...rest } = r;
      return { ...rest, opponent };
    });

    res.json({ ok: true, games: rowsWithOpponent });
  } catch (err) {
    console.error("playerGameLog error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// Selection timestamp — lightweight poll for live sync
// Returns just the updated_at timestamp for a game
// Used by non-editing admins to detect changes
// ------------------------------------------------------
app.get("/selectionTimestamp", async (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  try {
    const { gameType, season, round } = req.query;
    if (!gameType || !season || !round) {
      return res.status(400).json({ error: "gameType, season, round required" });
    }
    const normalizedGameType = normalizeGameType(gameType);
    const result = await pool.query(
      `SELECT updated_at FROM selections
       WHERE season = $1 AND game_type = $2 AND round = $3
       LIMIT 1`,
      [Number(season), normalizedGameType, Number(round)]
    );
    const ts = result.rows[0]?.updated_at
      ? new Date(result.rows[0].updated_at).getTime()
      : 0;
    res.json({ ok: true, lastUpdated: ts });
  } catch (err) {
    console.error("selectionTimestamp error:", err);
    res.status(500).json({ error: "Failed" });
  }
});

// Fantasy endpoint — LIVE DFS ONLY
// ------------------------------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const cdMatchId = req.params.matchId;
  const dfsId = dfsMap[cdMatchId];
  const squiggleGameId = squiggleMap[cdMatchId];

  if (!dfsId) {
    return res.status(404).json({
      ok: false,
      error: "No DFS mapping for matchId",
      matchId: cdMatchId,
    });
  }

  try {
    // 1. Live DFS feed
    let dfsPlayers = await scrapeDFS(dfsId);

    // 2. Always fetch Squiggle metadata (works for live, completed, and future games)
    let meta = {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "",
    };

    if (squiggleGameId) {
      try {
        const squiggleMeta = await fetchSquiggleMeta(squiggleGameId);
        meta = { ...meta, ...squiggleMeta };
      } catch (err) {
        console.error("Squiggle metadata error:", err);
      }
    }

    // 3. No DFS data → return Squiggle scores with empty player list
    // This handles historical rounds where the live DFS feed has expired
    if (!dfsPlayers || dfsPlayers.length === 0) {
      return res.json({
        ok: true,
        matchId: cdMatchId,
        homeScore: meta.homeScore,
        awayScore: meta.awayScore,
        quarter: meta.quarter,
        clock: meta.clock,
        status: meta.status || "No Data",
        players: [],
      });
    }

    // 4. Apply fantasy scoring to live DFS players
    const players = dfsPlayers.map((p) => ({
      ...p,
      af: calculateFantasyPoints(p),
    }));

    // 5. Final response
    return res.json({
      ok: true,
      matchId: cdMatchId,
      homeScore: meta.homeScore,
      awayScore: meta.awayScore,
      quarter: meta.quarter,
      clock: meta.clock,
      status: meta.status,
      players,
    });

  } catch (err) {
    console.error("💥 /fantasy error:", err);
    return res.status(500).json({
      ok: false,
      error: "Failed to load fantasy stats",
    });
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
  } catch {
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
// Start server
// ------------------------------------------------------
app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 DFS + Squiggle backend running on port ${port}`);
  startRoundCompletionScheduler(pool);
});