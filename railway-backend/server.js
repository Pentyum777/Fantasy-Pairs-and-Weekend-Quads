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

// Enable CORS for Flutter Web
app.use(cors({ origin: "*" }));
app.use(express.json());

// Root route
app.get("/", (req, res) => {
  res.send("DFS backend is running");
});

// ------------------------------------------------------
// REAL FootyInfo HTML parser
// ------------------------------------------------------
async function fetchFootyInfoMeta(footyInfoId) {
  const url = `https://www.footyinfo.com/match/${footyInfoId}`;

  const response = await fetch(url);
  const html = await response.text();

  const $ = load(html);

  // Scoreboard
  const homeScore = parseInt(
    $(".scoreboard .team.home .score").text().trim()
  ) || 0;

  const awayScore = parseInt(
    $(".scoreboard .team.away .score").text().trim()
  ) || 0;

  // Quarter + clock
  const quarter = $(".match-status .quarter").text().trim();
  const clock = $(".match-status .clock").text().trim();

  // Status (Final, Live, Upcoming)
  const status = $(".match-status .status").text().trim();

  return {
    homeScore,
    awayScore,
    quarter,
    clock,
    status,
  };
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
      awayScore: fiMeta.awayScore ?? 0,
      quarter: fiMeta.quarter ?? "",
      clock: fiMeta.clock ?? "",
      status: fiMeta.status ?? "",
      players: dfsData.players,
    });
  } catch (err) {
    console.error("❌ Combined DFS + FootyInfo error:", err);
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
    console.error("❌ FootyInfo meta error:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`DFS backend running on port ${port}`);
});