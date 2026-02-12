import express from "express";
import fs from "fs";

import { scrapeDFS } from "./dfs_scraper.js";
import footyInfoMap from "./footyinfo_map.json" assert { type: "json" };
import { matchIdToFootyInfoId } from "./footyinfo_map.js";

console.log("CORS-enabled server starting...");

const port = process.env.PORT || 8080;

// Load DFS mapping
const dfsMap = JSON.parse(fs.readFileSync("./dfs_map.json", "utf8"));

const app = express();

// CORS middleware — MUST be here, before all routes
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

// Root route so the Railway domain shows a response
app.get("/", (req, res) => {
  res.send("DFS backend is running");
});

// ⭐ UPDATED: Fantasy stats endpoint now merges DFS + FootyInfo
app.get("/fantasy/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const dfsId = dfsMap[matchId];
  const footyInfoId = matchIdToFootyInfoId[matchId];

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  if (!footyInfoId) {
    return res.status(404).json({ error: "No FootyInfo mapping for matchId" });
  }

  try {
    // DFS fantasy stats
    const dfsData = await scrapeDFS(dfsId);

    if (!dfsData || !dfsData.players) {
      return res.status(500).json({ error: "DFS returned no player data" });
    }

    // FootyInfo metadata
    const fiMeta = await scrapeFootyInfoMeta(footyInfoId);

    const payload = {
      matchId,
      homeScore: fiMeta.homeScore ?? 0,
      awayScore: fiMeta.awayScore ?? 0,
      quarter: fiMeta.quarter ?? "",
      clock: fiMeta.clock ?? "",
      status: fiMeta.status ?? "",
      players: dfsData.players,
    };

    res.json(payload);
  } catch (err) {
    console.error("❌ Combined DFS + FootyInfo scrape error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// ⭐ Metadata-only endpoint (FootyInfo only)
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;

  const footyInfoId = matchIdToFootyInfoId[matchId];
  if (!footyInfoId) {
    return res.status(404).json({ error: "No FootyInfo mapping for matchId" });
  }

  try {
    const meta = await scrapeFootyInfoMeta(footyInfoId);

    res.json({
      matchId,
      match: meta,
    });
  } catch (err) {
    console.error("❌ FootyInfo meta scrape error:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`DFS backend running on port ${port}`);
});