import express from "express";
import fs from "fs";
import { scrapeDFS } from "./dfs_scraper.js";

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

// Fantasy stats endpoint
app.get("/fantasy/:matchId", async (req, res) => {
  const matchId = req.params.matchId;
  const dfsId = dfsMap[matchId];

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  try {
    const data = await scrapeDFS(dfsId);

    if (!data || !data.players) {
      return res.status(500).json({ error: "DFS returned no player data" });
    }

    res.json({
      matchId,
      players: data.players,
    });
  } catch (err) {
    console.error("❌ DFS scrape error:", err);
    res.status(500).json({ error: String(err) });
  }
});

// Match metadata endpoint
app.get("/meta/:matchId", async (req, res) => {
  const matchId = req.params.matchId;
  const dfsId = dfsMap[matchId];

  if (!dfsId) {
    return res.status(404).json({ error: "No DFS mapping for matchId" });
  }

  try {
    const data = await scrapeDFS(dfsId);

    if (!data || !data.meta) {
      return res.status(500).json({ error: "DFS returned no metadata" });
    }

    res.json({
      matchId,
      match: data.meta,
    });
  } catch (err) {
    console.error("❌ DFS meta scrape error:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`DFS backend running on port ${port}`);
});