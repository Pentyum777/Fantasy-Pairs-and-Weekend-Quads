// dfs_service.js
import { fetchDfsWithRetry } from "./dfs_retry.js";
import { updateDfsCache, recordDfsError, getDfsCache } from "./dfs_cache.js";

export async function getDfsPlayerStats() {
  try {
    const { json, raw } = await fetchDfsWithRetry();
    updateDfsCache({ json, raw });

    // You can adapt this to your matchId / mapping logic
    return json.playerStats;
  } catch (err) {
    console.error("❌ DFS scraper failed, using cache if available:", err.message);
    recordDfsError(err);

    const cache = getDfsCache();
    if (cache.json && cache.json.playerStats) {
      console.warn("⚠ Using cached DFS data");
      return cache.json.playerStats;
    }

    // No cache → return empty, caller decides what to do
    return [];
  }
}