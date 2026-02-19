import fs from "fs";
import path from "path";
import { scrapeDFS } from "./dfs_scraper.js";
import { getSquiggleStatusForMatch } from "./squiggle_service.js";

// Load JSON maps manually (Railway-safe)
const squiggleMap = JSON.parse(
  fs.readFileSync(path.resolve("squiggle_map.json"), "utf8")
);

const dfsMap = JSON.parse(
  fs.readFileSync(path.resolve("dfs_map.json"), "utf8")
);

const CACHE_FILE = path.resolve("dfs_cache.json");

function loadCache() {
  try {
    if (fs.existsSync(CACHE_FILE)) {
      console.log("📦 DFS cache loaded");
      return JSON.parse(fs.readFileSync(CACHE_FILE, "utf8"));
    }
  } catch (err) {
    console.error("Error loading DFS cache:", err);
  }
  console.log("📦 No existing DFS cache found");
  return {};
}

function saveCache(cache) {
  try {
    fs.writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2));
    console.log("💾 DFS cache saved");
  } catch (err) {
    console.error("Error saving DFS cache:", err);
  }
}

const cache = loadCache();

export async function getDFSStatsForMatch(matchId) {
  const dfsId = dfsMap[matchId];

  if (!dfsId) {
    console.warn(`⚠ No DFS ID found for match ${matchId}`);
    return { players: [], meta: {} };
  }

  console.log(`\n==============================`);
  console.log(`🎯 DFS pipeline start → matchId ${matchId}, dfsId ${dfsId}`);

  // If cached as FINAL, return immediately
  if (cache[matchId]?.status === "final") {
    console.log(`📦 Cache hit (FINAL) → matchId ${matchId}`);
    return cache[matchId].payload;
  }

  // Check Squiggle status
  const status = await getSquiggleStatusForMatch(matchId);
  console.log(`🟦 Squiggle status → matchId ${matchId}: ${status}`);

  // If upcoming, return cached (if any) or empty
  if (status === "Upcoming") {
    console.log(`⏳ Match is Upcoming → skipping DFS scrape for ${matchId}`);
    return cache[matchId]?.payload || { players: [], meta: {} };
  }

  // Scrape DFS Australia
  console.log(`🟧 Scraping DFS → dfsId ${dfsId}`);
  const scraped = await scrapeDFS(dfsId);

  console.log(
    `🟨 DFS scrape result → matchId ${matchId}, players=${scraped.players.length}`
  );

  // If scraper returned valid data, update cache
  if (scraped.players.length > 0) {
    cache[matchId] = {
      payload: scraped,
      status: status === "Final" ? "final" : "live",
      lastUpdated: Date.now(),
    };

    console.log(
      `💾 Cache updated → matchId ${matchId}, status=${cache[matchId].status}`
    );

    saveCache(cache);
  } else {
    console.log(`⚠ DFS scrape returned 0 players for matchId ${matchId}`);
  }

  // Return scraped or fallback to cached
  const finalPayload =
    scraped.players.length > 0
      ? scraped
      : cache[matchId]?.payload || { players: [], meta: {} };

  console.log(
    `✅ DFS pipeline complete → matchId ${matchId}, returning players=${finalPayload.players.length}`
  );

  return finalPayload;
}