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
      return JSON.parse(fs.readFileSync(CACHE_FILE, "utf8"));
    }
  } catch (err) {
    console.error("Error loading DFS cache:", err);
  }
  return {};
}

function saveCache(cache) {
  try {
    fs.writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2));
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

  // If cached as FINAL, return immediately
  if (cache[matchId]?.status === "final") {
    return cache[matchId].payload;
  }

  // Check Squiggle status
  const status = await getSquiggleStatusForMatch(matchId);

  // If upcoming, return cached (if any) or empty
  if (status === "Upcoming") {
    return cache[matchId]?.payload || { players: [], meta: {} };
  }

  // Scrape DFS Australia
  const scraped = await scrapeDFS(dfsId);

  // If scraper returned valid data, update cache
  if (scraped.players.length > 0) {
    cache[matchId] = {
      payload: scraped,
      status: status === "Final" ? "final" : "live",
      lastUpdated: Date.now(),
    };
    saveCache(cache);
  }

  // Return scraped or fallback to cached
  return scraped.players.length > 0
    ? scraped
    : cache[matchId]?.payload || { players: [], meta: {} };
}