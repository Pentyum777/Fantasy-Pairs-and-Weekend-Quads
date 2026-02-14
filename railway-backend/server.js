import express from "express";
import fs from "fs";
import cors from "cors";

import { scrapeDFS } from "./dfs_scraper.js";
import { scrapeFootyInfoMeta } from "./footyinfo_scraper.js";

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
// CACHING LAYER FOR FOOTYINFO META (5-minute TTL)
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

async function getFootyInfoMetaCached(footyInfoId) {
  const cached = getCachedMeta(footyInfoId);
  if (cached) return cached;

  try {
    const meta = await scrapeFootyInfoMeta(footyInfoId);
    setCachedMeta(footyInfoId, meta);
    return meta;
  } catch (err) {
    console.error("FootyInfo Playwright scrape failed:", err);
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
// Fantasy stats endpoint (DFS + FootyInfo via Playwright)
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

    const fiMeta = await getFootyInfoMetaCached(footyInfoId);

    res.json({
      matchId,
      homeScore: fiMeta.homeScore ?? 0,
      awayScore: fiMeta.awayScore ?? 0,
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
    const meta = await getFootyInfoMetaCached(footyInfoId);

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
