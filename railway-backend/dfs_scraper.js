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
// ⭐ FANTASY POINTS CALCULATION
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
// ⭐ NORMALIZATION LAYER (FULL + CORRECT)
// ------------------------------------------------------------
function normalizePlayer(p) {
  const normalized = {
    id: p.id ?? p.matchId ?? p.match_id ?? 0,
    playerId: p.playerId ?? p.player_id ?? "",
    playerName: p.playerName ?? p.name ?? "",

    kicks: Number(p.kicks ?? p.k ?? 0),
    handballs: Number(p.handballs ?? p.hb ?? 0),
    disposals:
      Number(p.disposals ?? p.d ?? ((p.kicks ?? 0) + (p.handballs ?? 0))),
    marks: Number(p.marks ?? p.m ?? 0),
    tackles: Number(p.tackles ?? p.t ?? 0),

    freesFor: Number(p.freesFor ?? p.ff ?? 0),
    freesAgainst: Number(p.freesAgainst ?? p.fa ?? 0),
    hitouts: Number(p.hitouts ?? p.ho ?? 0),

    goals: Number(p.goals ?? p.g ?? 0),
    behinds: Number(p.behinds ?? p.b ?? 0),
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
// ⭐ COMPLETED GAME SCRAPER (with match‑integrity validation)
// ------------------------------------------------------------
export async function scrapeCompletedDFS(dfsId) {
  const url = `https://dfsaustralia.com/wp-admin/admin-ajax.php?action=afl_game_stats_call_mysql&gameId=${dfsId}`;

  try {
    const res = await fetch(url, {
      method: "GET",
      headers: {
        "User-Agent": "Mozilla/5.0",
        Accept: "application/json",
      },
      timeout: 10000,
    });

    if (!res.ok) {
      throw new Error(`Completed DFS returned ${res.status}`);
    }

    const json = await res.json();

    const players = [...json.home, ...json.away];

    // ❗ Reject empty responses
    if (players.length === 0) {
      throw new Error("Completed DFS returned no players");
    }

    // ❗ Reject wrong-game responses (DFS bug)
    if (!players.every((p) => Number(p.gameId) === Number(dfsId))) {
      throw new Error("Completed DFS returned wrong game data");
    }

    return players.map((p) => ({
      id: p.playerId,
      playerId: p.playerId,
      playerName: p.playerName,
      teamAbbr: p.teamAbbr ?? "",

      kicks: Number(p.kicks ?? 0),
      handballs: Number(p.handballs ?? 0),
      disposals: Number(p.kicks ?? 0) + Number(p.handballs ?? 0),
      marks: Number(p.marks ?? 0),
      tackles: Number(p.tackles ?? 0),
      goals: Number(p.goals ?? 0),
      behinds: Number(p.behinds ?? 0),
      hitouts: Number(p.hitouts ?? 0),
      freesFor: Number(p.freesFor ?? 0),
      freesAgainst: Number(p.freesAgainst ?? 0),
      timeOnGroundPercentage: Number(p.timeOnGroundPercentage ?? 0),

      fantasyPoints: Number(p.dreamTeamPoints ?? 0),
    }));
  } catch (err) {
    console.error("❌ scrapeCompletedDFS failed:", err.message);
    return [];
  }
}

// ------------------------------------------------------------
// ⭐ PUBLIC API — scrapeDFS(dfsId)
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

    // ⭐ Only use cache if it contains players for THIS match
    if (lastGoodJson) {
      console.warn("⚠ Using cached DFS data");

      const matchId = Number(dfsId);

      const cachedPlayers = lastGoodJson.playerStats.filter((p) => {
        const pid = Number(p.id ?? p.matchId ?? p.match_id);
        return pid === matchId;
      });

      if (cachedPlayers.length > 0) {
        return cachedPlayers.map(normalizePlayer);
      }
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
