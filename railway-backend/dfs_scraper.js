// dfs_scraper.js
import fetch from "node-fetch";

// ------------------------------------------------------------
// INTERNAL CACHE (last known good DFS data)
// ------------------------------------------------------------
let lastGoodJson = null;
let lastGoodTimestamp = null;
let lastError = null;

// ------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function updateCache(json) {
  lastGoodJson = json;
  lastGoodTimestamp = new Date();
  lastError = null;
}

function recordError(err) {
  lastError = {
    message: err.message,
    time: new Date(),
  };
}

// ------------------------------------------------------------
// LOW‑LEVEL FETCH (read body ONCE)
// ------------------------------------------------------------
async function fetchRawDfs() {
  const url =
    "https://dfsaustralia-apps.com/shiny/afl-live-scoring/liveScoring2026.json";

  const res = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
      Accept: "application/json,text/plain,*/*",
    },
    timeout: 10000,
  });

  if (!res.ok) {
    throw new Error(`DFS feed returned error: ${res.status}`);
  }

  const raw = await res.text(); // ⭐ read ONCE
  return raw;
}

// ------------------------------------------------------------
// PARSE + SHINY QUIRK DETECTION
// ------------------------------------------------------------
function parseDfsJson(raw) {
  // Shiny sometimes returns HTML error pages
  if (raw.trim().startsWith("<!DOCTYPE") || raw.includes("<html")) {
    throw new Error("DFS returned HTML instead of JSON (Shiny error page)");
  }

  let json;
  try {
    json = JSON.parse(raw);
  } catch (err) {
    throw new Error("DFS JSON parse failed: " + err.message);
  }

  if (!json.playerStats || !Array.isArray(json.playerStats)) {
    throw new Error("DFS JSON missing playerStats array");
  }

  return json;
}

// ------------------------------------------------------------
// RETRY WRAPPER (handles 502, HTML, Shiny resets)
// ------------------------------------------------------------
async function fetchDfsWithRetry() {
  const MAX_RETRIES = 4;

  let lastErr;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const raw = await fetchRawDfs();
      const json = parseDfsJson(raw);
      return json;
    } catch (err) {
      lastErr = err;
      console.error(
        `DFS attempt ${attempt}/${MAX_RETRIES} failed: ${err.message}`
      );

      if (attempt < MAX_RETRIES) {
        await sleep(1000 * attempt); // backoff
      }
    }
  }

  throw lastErr;
}

// ------------------------------------------------------------
// PUBLIC API — your original scrapeDFS(dfsId)
// ------------------------------------------------------------
export async function scrapeDFS(dfsId) {
  try {
    const json = await fetchDfsWithRetry();

    // ⭐ Update cache on success
    updateCache(json);

    const matchId = Number(dfsId);
    return json.playerStats.filter((p) => {
  const pid = Number(p.id ?? p.matchId ?? p.match_id);
  return pid === matchId;
});
  } catch (err) {
    console.error("❌ DFS scraper failed:", err.message);

    // ⭐ Record error
    recordError(err);

    // ⭐ Fallback to cache if available
    if (lastGoodJson) {
      console.warn("⚠ Using cached DFS data");
      const matchId = Number(dfsId);
      return lastGoodJson.playerStats.filter((p) => p.id === matchId);
    }

    // No cache → return empty
    return [];
  }
}

// ------------------------------------------------------------
// OPTIONAL: HEALTH CHECK EXPORT
// ------------------------------------------------------------
export function dfsHealth() {
  return {
    lastGoodTimestamp,
    lastError,
    cacheAvailable: !!lastGoodJson,
  };
}