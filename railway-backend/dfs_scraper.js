// dfs_scraper.js
import fetch from "node-fetch";

// ------------------------------------------------------------
// INTERNAL CACHE (last known good DFS live JSON)
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
// FANTASY POINTS CALCULATION
// ------------------------------------------------------------
function calculateFantasyPoints(p) {
  return (
    (p.kicks ?? 0) * 3 +
    (p.handballs ?? 0) * 2 +
    (p.marks ?? 0) * 3 +
    (p.tackles ?? 0) * 4 +
    (p.freesFor ?? 0) * 1 +
    (p.freesAgainst ?? 0) * -3 +
    (p.hitouts ?? 0) * 1 +
    (p.goals ?? 0) * 6 +
    (p.behinds ?? 0) * 1
  );
}

// ------------------------------------------------------------
// NORMALIZATION LAYER
// ------------------------------------------------------------
function normalizePlayer(p) {
  const kicks = Number(p.kicks ?? p.k ?? 0);
  const handballs = Number(p.handballs ?? p.hb ?? 0);
  const marks = Number(p.marks ?? p.m ?? 0);
  const tackles = Number(p.tackles ?? p.t ?? 0);
  const freesFor = Number(p.freesFor ?? p.ff ?? 0);
  const freesAgainst = Number(p.freesAgainst ?? p.fa ?? 0);
  const hitouts = Number(p.hitouts ?? p.ho ?? 0);
  const goals = Number(p.goals ?? p.g ?? 0);
  const behinds = Number(p.behinds ?? p.b ?? 0);

  const normalized = {
    id: p.id ?? "",
    playerId: p.playerId ?? "",
    playerName: p.playerName ?? p.name ?? "",
    teamAbbr: p.teamAbbr ?? p.team ?? "",

    kicks,
    handballs,
    disposals: Number(p.disposals ?? p.d ?? kicks + handballs),
    marks,
    tackles,

    freesFor,
    freesAgainst,
    hitouts,

    goals,
    behinds,
  };

  normalized.fantasyPoints = calculateFantasyPoints(normalized);
  return normalized;
}

// ------------------------------------------------------------
// LIVE DFS JSON (Shiny endpoint)
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
    throw new Error(`DFS live feed returned error: ${res.status}`);
  }

  return await res.text();
}

function parseDfsJson(raw) {
  if (raw.trim().startsWith("<!DOCTYPE") || raw.includes("<html")) {
    throw new Error("DFS live feed returned HTML instead of JSON");
  }

  let json;
  try {
    json = JSON.parse(raw);
  } catch (err) {
    throw new Error("DFS live JSON parse failed: " + err.message);
  }

  if (!json.playerStats || !Array.isArray(json.playerStats)) {
    throw new Error("DFS live JSON missing playerStats array");
  }

  return json;
}

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
        `DFS live attempt ${attempt}/${MAX_RETRIES} failed: ${err.message}`
      );
      if (attempt < MAX_RETRIES) {
        await sleep(1000 * attempt);
      }
    }
  }

  throw lastErr;
}

// ------------------------------------------------------------
// PUBLIC API — LIVE DFS ONLY
// ------------------------------------------------------------
export async function scrapeDFS(dfsId) {
  const matchId = Number(dfsId);

  try {
    // 1) Live DFS JSON
    const json = await fetchDfsWithRetry();
    updateCache(json);

    // Filter by DFS gameId
    const playersRaw = json.playerStats.filter(
      (p) => Number(p.id) === Number(dfsId)
    );

    if (playersRaw.length > 0) {
      return playersRaw.map(normalizePlayer);
    }

    // No live data → future game
    return [];
  } catch (err) {
    console.error("❌ DFS scraper failed:", err.message);
    recordError(err);

    // Try cached live JSON if available
    if (lastGoodJson) {
      console.warn("⚠ Using cached DFS live data");
      const cachedPlayers = lastGoodJson.playerStats.filter(
        (p) => Number(p.id) === matchId
      );

      if (cachedPlayers.length > 0) {
        return cachedPlayers.map(normalizePlayer);
      }
    }

    return [];
  }
}

// ------------------------------------------------------------
// HEALTH CHECK
// ------------------------------------------------------------
export function dfsHealth() {
  return {
    lastGoodTimestamp,
    lastError,
    cacheAvailable: !!lastGoodJson,
  };
}