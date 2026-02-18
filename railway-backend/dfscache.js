import fs from "fs";
import path from "path";
import { scrapeDFS } from "./dfs_scraper.js";
import dfsMap from "./dfs_map.json" assert { type: "json" };
import { getSquiggleStatusForMatch } from "./squiggle_service.js";

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

  if (cache[matchId]?.status === "final") {
    return cache[matchId].payload;
  }

  const status = await getSquiggleStatusForMatch(matchId);

  if (status === "Upcoming") {
    return cache[matchId]?.payload || { players: [], meta: {} };
  }

  const scraped = await scrapeDFS(dfsId);

  if (scraped.players.length > 0) {
    cache[matchId] = {
      payload: scraped,
      status: status === "Final" ? "final" : "live",
      lastUpdated: Date.now(),
    };
    saveCache(cache);
  }

  return scraped.players.length > 0
    ? scraped
    : cache[matchId]?.payload || { players: [], meta: {} };
}