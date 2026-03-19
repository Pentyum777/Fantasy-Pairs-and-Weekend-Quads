// dfs_scraper.js
import fetch from "node-fetch";
import * as cheerio from "cheerio";

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
// ⭐ FANTASY POINTS CALCULATION
// ------------------------------------------------------------
function calculateFantasyPoints(p) {
  return (
    (p.kicks ?? 0) * 3 +
    (p.handballs ?? 0) * 2 +
    (p.marks ?? 0) * 3 +
    (p.tackles ?? 0) * 4 +
    (p.goals ?? 0) * 6 +
    (p.behinds ?? 0) * 1
  );
}

// ------------------------------------------------------------
// ⭐ NORMALIZATION LAYER
// ------------------------------------------------------------
function normalizePlayer(p) {
  const normalized = {
    id: p.id ?? p.matchId ?? p.match_id ?? 0,
    playerId: p.playerId ?? p.player_id ?? "",
    playerName: p.playerName ?? p.name ?? "",
    kicks: p.kicks ?? p.k ?? 0,
    handballs: p.handballs ?? p.hb ?? 0,
    disposals:
      p.disposals ??
      p.d ??
      ((p.kicks ?? 0) + (p.handballs ?? 0)),
    marks: p.marks ?? p.m ?? 0,
    tackles: p.tackles ?? p.t ?? 0,
    goals: p.goals ?? p.g ?? 0,
    behinds: p.behinds ?? p.b ?? 0,
  };

  normalized.fantasyPoints = calculateFantasyPoints(normalized);
  return normalized;
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

  return await res.text();
}

// ------------------------------------------------------------
// PARSE + SHINY QUIRK DETECTION
// ------------------------------------------------------------
function parseDfsJson(raw) {
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
// RETRY WRAPPER
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
        await sleep(1000 * attempt);
      }
    }
  }

  throw lastErr;
}

// ------------------------------------------------------------
// COMPLETED GAME SCRAPER (HTML → normalized stats)
// ------------------------------------------------------------
export async function scrapeCompletedDFS(dfsId) {
  const url = `https://dfsaustralia.com/afl-game-stats/?gameId=${dfsId}`;

  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0",
        Accept: "text/html,*/*",
      },
      timeout: 10000,
    });

    if (!res.ok) {
      throw new Error(`Completed DFS page returned ${res.status}`);
    }

    const html = await res.text();
    const $ = cheerio.load(html);

    const players = [];

    $("table tbody tr").each((_, row) => {
      const cells = $(row).find("td");
      if (cells.length < 10) return;

      const playerName = $(cells[0]).text().trim();
      const kicks = parseInt($(cells[1]).text().trim()) || 0;
      const handballs = parseInt($(cells[2]).text().trim()) || 0;
      const disposals = kicks + handballs;
      const marks = parseInt($(cells[3]).text().trim()) || 0;
      const tackles = parseInt($(cells[4]).text().trim()) || 0;
      const goals = parseInt($(cells[5]).text().trim()) || 0;
      const behinds = parseInt($(cells[6]).text().trim()) || 0;
      const fantasyPoints = parseInt($(cells[9]).text().trim()) || 0;

      players.push({
        id: `${dfsId}-${playerName}`,
        playerId: `${dfsId}-${playerName}`,
        playerName,
        kicks,
        handballs,
        disposals,
        marks,
        tackles,
        goals,
        behinds,
        fantasyPoints,
      });
    });

    return players.map(normalizePlayer);
  } catch (err) {
    console.error("❌ scrapeCompletedDFS failed:", err.message);
    return [];
  }
}

// ------------------------------------------------------------
// PUBLIC API — scrapeDFS(dfsId)
// ------------------------------------------------------------
export async function scrapeDFS(dfsId) {
  try {
    const json = await fetchDfsWithRetry();
    updateCache(json);

    const matchId = Number(dfsId);

    const playersRaw = json.playerStats.filter((p) => {
      const pid = Number(p.id ?? p.matchId ?? p.match_id);
      return pid === matchId;
    });

    return playersRaw.map(normalizePlayer);
  } catch (err) {
    console.error("❌ DFS scraper failed:", err.message);
    recordError(err);

    if (lastGoodJson) {
      console.warn("⚠ Using cached DFS data");
      const matchId = Number(dfsId);

      return lastGoodJson.playerStats
        .filter((p) => {
          const pid = Number(p.id ?? p.matchId ?? p.match_id);
          return pid === matchId;
        })
        .map(normalizePlayer);
    }

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