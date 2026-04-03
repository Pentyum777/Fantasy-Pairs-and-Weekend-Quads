// dfs_scraper.js
import fetch from "node-fetch";
import * as cheerio from "cheerio";

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
// COMPLETED GAME SCRAPER — DFS MySQL JSON
// ------------------------------------------------------------
export async function scrapeCompletedDFS(dfsId, cdMatchId) {
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
      throw new Error(`Completed DFS MySQL returned ${res.status}`);
    }

    const json = await res.json();

    const homePlayers = (json.home ?? []).map((p) => ({
      ...p,
      teamAbbr: p.teamAbbr ?? p.team ?? "",
    }));

    const awayPlayers = (json.away ?? []).map((p) => ({
      ...p,
      teamAbbr: p.teamAbbr ?? p.team ?? "",
    }));

    const players = [...homePlayers, ...awayPlayers];

    if (players.length === 0) {
      throw new Error("Completed DFS MySQL returned no players");
    }

    return players.map(normalizePlayer);
  } catch (err) {
    console.error("❌ scrapeCompletedDFS (MySQL) failed:", err.message);
    return [];
  }
}

// ------------------------------------------------------------
// COMPLETED GAME SCRAPER — DFS HTML FALLBACK
// ------------------------------------------------------------
async function scrapeCompletedDFSHtml(dfsId) {
  const url = `https://dfsaustralia.com/afl-game-stats/?gameId=${dfsId}`;

  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0",
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
      timeout: 10000,
    });

    if (!res.ok) {
      throw new Error(`HTML completed DFS returned ${res.status}`);
    }

    const html = await res.text();
    const $ = cheerio.load(html);

    const players = [];

    $("table").each((_, table) => {
      $(table)
        .find("tr")
        .each((__, row) => {
          const cells = $(row).find("td");
          if (cells.length === 0) return;

          const playerName = $(cells[0]).text().trim();
          if (!playerName) return;

          const toNumber = (el) => {
            const v = $(el).text().trim();
            const n = Number(v);
            return Number.isNaN(n) ? 0 : n;
          };

          const kicks = toNumber(cells[1]);
          const handballs = toNumber(cells[2]);
          const marks = toNumber(cells[3]);
          const hitouts = toNumber(cells[4]);
          const freesFor = toNumber(cells[5]);
          const freesAgainst = toNumber(cells[6]);

          players.push({
            id: `${dfsId}-${playerName}`,
            playerId: `${dfsId}-${playerName}`,
            playerName,
            kicks,
            handballs,
            disposals: kicks + handballs,
            marks,
            tackles: 0,
            goals: 0,
            behinds: 0,
            hitouts,
            freesFor,
            freesAgainst,
          });
        });
    });

    if (players.length === 0) {
      throw new Error("HTML completed DFS returned no players");
    }

    return players.map(normalizePlayer);
  } catch (err) {
    console.error("❌ scrapeCompletedDFSHtml failed:", err.message);
    return [];
  }
}

// ------------------------------------------------------------
// AFL MATCHCENTRE FALLBACK (Champion Data)
// ------------------------------------------------------------
export async function scrapeAflMatchCentre(cdMatchId) {
  const url = `https://www.afl.com.au/api/cfs/afl/matchStats/match/${cdMatchId}`;

  try {
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
        Accept: "application/json, text/plain, */*",
        "Accept-Language": "en-US,en;q=0.9",
        Referer: "https://www.afl.com.au/",
        Origin: "https://www.afl.com.au",
      },
      timeout: 10000,
    });

    if (!res.ok) {
      throw new Error(`AFL MatchCentre returned ${res.status}`);
    }

    const json = await res.json();

    if (!json || !json.match || !json.match.playerStats) {
      throw new Error("AFL MatchCentre missing playerStats");
    }

    const players = json.match.playerStats;

    return players.map((p) => {
      const stats = p.stats ?? {};
      const kicks = Number(stats.kicks ?? 0);
      const handballs = Number(stats.handballs ?? 0);
      const marks = Number(stats.marks ?? 0);
      const tackles = Number(stats.tackles ?? 0);
      const freesFor = Number(stats.freesFor ?? 0);
      const freesAgainst = Number(stats.freesAgainst ?? 0);
      const hitouts = Number(stats.hitouts ?? 0);
      const goals = Number(stats.goals ?? 0);
      const behinds = Number(stats.behinds ?? 0);

      return normalizePlayer({
        id: p.player?.playerId,
        playerId: p.player?.playerId,
        playerName: p.player?.name,
        teamAbbr: p.team?.teamAbbr ?? "",
        kicks,
        handballs,
        disposals: kicks + handballs,
        marks,
        tackles,
        goals,
        behinds,
        hitouts,
        freesFor,
        freesAgainst,
      });
    });
  } catch (err) {
    console.error("❌ scrapeAflMatchCentre failed:", err.message);
    return [];
  }
}

// ------------------------------------------------------------
// PUBLIC API — scrapeDFS(dfsId, cdMatchId)
// ------------------------------------------------------------
export async function scrapeDFS(dfsId, cdMatchId) {
  const matchId = Number(dfsId);

  try {
    // 1) Live DFS JSON
    const json = await fetchDfsWithRetry();
    updateCache(json);

    // ⭐ Correct filter — NO fixtureId
    const playersRaw = json.playerStats.filter(
      (p) => Number(p.id) === Number(dfsId)
    );

    if (playersRaw.length > 0) {
      return playersRaw.map(normalizePlayer);
    }

    // 2) Completed DFS JSON (MySQL)
    let completedPlayers = await scrapeCompletedDFS(dfsId, cdMatchId);
    if (completedPlayers.length > 0) {
      return completedPlayers;
    }

    // 3) Completed DFS HTML fallback
    completedPlayers = await scrapeCompletedDFSHtml(dfsId);
    if (completedPlayers.length > 0) {
      return completedPlayers;
    }

    // 4) AFL MatchCentre fallback
    if (cdMatchId) {
      completedPlayers = await scrapeAflMatchCentre(cdMatchId);
      if (completedPlayers.length > 0) {
        return completedPlayers;
      }
    }

    return [];
  } catch (err) {
    console.error("❌ DFS scraper failed:", err.message);
    recordError(err);

    // Try cached live JSON if available
    if (lastGoodJson) {
      console.warn("⚠ Using cached DFS live data");
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
// HEALTH CHECK
// ------------------------------------------------------------
export function dfsHealth() {
  return {
    lastGoodTimestamp,
    lastError,
    cacheAvailable: !!lastGoodJson,
  };
}