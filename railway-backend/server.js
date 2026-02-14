import express from "express";
import fs from "fs";
import cors from "cors";
import { load } from "cheerio";

import { scrapeDFS } from "./dfs_scraper.js";

// Load FootyInfo map (Node 24-safe)
const footyInfoMap = JSON.parse(
  fs.readFileSync("./footyinfo_map.json", "utf8")
);

// Load DFS mapping
const dfsMap = JSON.parse(
  fs.readFileSync("./dfs_map.json", "utf8")
);

console.log("CORS-enabled DFS + FootyInfo backend starting...");

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
  res.send("DFS backend is running");
});

// ------------------------------------------------------
// CACHING LAYER (5-minute TTL)
// ------------------------------------------------------
const metaCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000;

function getCachedMeta(id) {
  const entry = metaCache.get(id);
  if (!entry) return null;

  const isExpired = Date.now() - entry.timestamp > CACHE_TTL_MS;
  if (isExpired) {
    metaCache.delete(id);
    return null;
  }
  return entry.data;
}

function setCachedMeta(id, data) {
  metaCache.set(id, {
    timestamp: Date.now(),
    data,
  });
}

// ------------------------------------------------------
// FootyInfo metadata scraper (with fallback + error tolerance)
// ------------------------------------------------------
async function fetchFootyInfoMeta(footyInfoId) {
  // Check cache first
  const cached = getCachedMeta(footyInfoId);
  if (cached) return cached;

  const url = `https://www.footyinfo.com/match/${footyInfoId}`;

  let html = "";
  try {
    const response = await fetch(url, { timeout: 8000 });
    html = await response.text();
  } catch (err) {
    console.error("FootyInfo fetch failed:", err);
    return {
      homeScore: 0,
      awayScore: 0,
      quarter: "",
      clock: "",
      status: "",
    };
  }

  const $ = load(html);

  // -------------------------------
  // PRIMARY PARSING (structured HTML)
  // -------------------------------
  let homeScore =
    parseInt($(".scoreboard .team.home .score").text().trim()) || 0;

  let awayScore =
    parseInt($(".scoreboard .team.away .score").text().trim()) || 0;

  let quarter = $(".match-status .quarter").text().trim();
  let clock = $(".match-status .clock").text().trim();
  let status = $(".match-status .status").text().trim();

  // -------------------------------
  // FALLBACK PARSING (regex)
  // -------------------------------
  const bodyText = $("body").text();

  if (homeScore === 0 && awayScore === 0) {
    const nums = [...bodyText.matchAll(/\b(\d{1,3})\b/g)].map(m =>
      parseInt(m[1], 10)
    );
    if (nums.length >= 2) {
      awayScore = nums[nums.length - 1];
      homeScore = nums[nums.length - 2];
    }
  }

  if (!quarter) {
    const lower = bodyText.toLowerCase();
    if (lower.includes("full time")) {
      quarter = "Final";
      status = "Full Time";
      clock = "FT";
    } else if (lower.includes("three quarter time") || lower.includes("3qt")) {
      quarter = "Q4";
      status = "3QT";
    } else if (lower.includes("half time")) {
      quarter = "Q3";
      status = "Half Time";
    } else if (lower.includes("quarter time")) {
      quarter = "Q2";
      status = "Quarter Time";
    }
  }

  if (!clock) {
    const clockMatch = bodyText.match(/\b(\d{1,2}:\d{2})\b/);
    if (clockMatch) clock = clockMatch[1];
  }

  const meta = {
    homeScore,
    awayScore,
    quarter,
    clock,
    status,
  };

  // Cache result
  setCachedMeta(footyInfoId, meta);

  return meta;
}

// ------------------------------------------------------
// Fantasy stats endpoint (DFS + FootyInfo)
// ------------------------------------------------------
app.get("/fantasy/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const dfsId = dfsMap[matchId];
  const footyInfoId = footyInfoMap[matchId];

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  if (!footyInfoId) {
    return res.status(404).json({ error: "No FootyInfo mapping for matchId" });
  }

  try {
    const dfsData = await scrapeDFS(dfsId);

    if (!dfsData || !dfsData.players) {
      return res.status(500).json({ error: "DFS returned no player data" });
    }

    const fiMeta = await fetchFootyInfoMeta(footyInfoId);

    res.json({
      matchId,
      homeScore: fiMeta.homeScore ?? 0,
      awayScore: fiMeta.awreScore ?? 0,
      quarter: fiMeta.quarter ?? "",
      clock: fiMeta.clock ?? "",
      status: fiMeta.status ?? "",
      players: dfsData.players,
    });
  } catch (err) {
    console.error("Combined DFS + FootyInfo error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// ------------------------------------------------------
// Metadata-only endpoint
// ------------------------------------------------------
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const footyInfoId = footyInfoMap[matchId];
  if (!footyInfoId) {
    return res.status(404).json({ error: "No FootyInfo mapping for matchId" });
  }

  try {
    const meta = await fetchFootyInfoMeta(footyInfoId);

    res.json({
      matchId,
      match: meta,
    });
  } catch (err) {
    console.error("FootyInfo meta error:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`DFS backend running on port ${port}`);
});