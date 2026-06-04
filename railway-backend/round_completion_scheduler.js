/**
 * round_completion_scheduler.js
 *
 * Runs on the Railway server 24/7. Every 2 minutes it checks for
 * AFL games that have completed and caches their stats immediately.
 *
 * KEY DESIGN: Stats are cached PER-GAME as soon as each game finishes,
 * NOT after the whole round completes. This is critical because DFS
 * only shows stats for the most recent game — older completed games
 * disappear from the feed once the next game starts.
 *
 * Once ALL games in a round are cached, it patches the selections table
 * with final fantasy scores.
 *
 * Usage: imported and started from server.js
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { scrapeDFS } from "./dfs_scraper.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dfsMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "dfs_map.json"), "utf8")
);

// Track which individual games we've already cached (match IDs)
const cachedGames = new Set();
// Track which rounds have been fully patched (selections table)
const patchedRounds = new Set();

const CHECK_INTERVAL_MS = 2 * 60 * 1000; // every 2 minutes
const CURRENT_SEASON = 2026;

// ---------------------------------------------------------------------------
// Fantasy points formula (matches the Flutter app exactly)
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Get all match IDs grouped by round for the current season
// ---------------------------------------------------------------------------
function getMatchesByRound() {
  const byRound = {};

  for (const [cdMatchId] of Object.entries(dfsMap)) {
    const m = cdMatchId.match(/^CD_M(\d{4})(\d{3})(\d{2})(\d{2})$/);
    if (!m) continue;

    const season = parseInt(m[1]);
    const round = parseInt(m[3]);

    if (season !== CURRENT_SEASON) continue;
    if (round === 0) continue; // skip pre-season

    if (!byRound[round]) byRound[round] = [];
    byRound[round].push(cdMatchId);
  }

  return byRound;
}

// ---------------------------------------------------------------------------
// DFS team-code normalisation
// ---------------------------------------------------------------------------
const normAbbr = (abbr) => {
  const map = {
    "MEL": "MELB", "WB": "WBD", "BRI": "BRL",
    "RICH": "RIC", "CARL": "CAR", "COLL": "COL",
    "GCFC": "GCS", "NMFC": "NTH", "PORT": "PTA",
  };
  return map[abbr] || abbr;
};

// ---------------------------------------------------------------------------
// Fetch and cache stats for a SINGLE game into match_stats.
// Returns the records array (empty if DFS had no data).
// ---------------------------------------------------------------------------
async function fetchAndCacheGame(pool, cdMatchId) {
  const dfsId = dfsMap[cdMatchId];
  if (!dfsId) return [];

  let players;
  try {
    players = await scrapeDFS(String(dfsId));
  } catch (err) {
    return [];
  }

  if (!players || players.length === 0) return [];

  // Check if any player has non-zero fantasy points (game actually started)
  const hasStats = players.some((p) => (p.fantasyPoints ?? 0) > 0);
  if (!hasStats) return [];

  const records = [];
  for (const p of players) {
    const pid = p.playerId;
    if (!pid || !pid.startsWith("CD_I")) continue;

    const kicks = p.kicks ?? 0;
    const handballs = p.handballs ?? 0;

    const stats = {
      K: kicks,
      HB: handballs,
      D: kicks + handballs,
      M: p.marks ?? 0,
      T: p.tackles ?? 0,
      HO: p.hitouts ?? 0,
      FF: p.freesFor ?? 0,
      FA: p.freesAgainst ?? 0,
      G: p.goals ?? 0,
      B: p.behinds ?? 0,
      TOG: p.timeOnGroundPercentage ?? 0,
      AF: p.fantasyPoints ?? calculateFantasyPoints(p),
    };

    records.push({
      matchId: cdMatchId,
      playerId: pid,
      playerName: p.playerName || "",
      team: normAbbr(p.teamAbbr || p.team || ""),
      stats,
    });
  }

  if (records.length < 10) return []; // not enough data, skip

  // Upsert into match_stats immediately
  let upserted = 0;
  for (const r of records) {
    try {
      await pool.query(
        `INSERT INTO match_stats
           (match_id, player_id, player_name, team,
            kicks, handballs, disposals, marks, tackles, hitouts,
            frees_for, frees_against, goals, behinds, tog, fantasy_points)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
         ON CONFLICT (match_id, player_id)
         DO UPDATE SET
           player_name    = EXCLUDED.player_name,
           team           = EXCLUDED.team,
           kicks          = EXCLUDED.kicks,
           handballs      = EXCLUDED.handballs,
           disposals      = EXCLUDED.disposals,
           marks          = EXCLUDED.marks,
           tackles        = EXCLUDED.tackles,
           hitouts        = EXCLUDED.hitouts,
           frees_for      = EXCLUDED.frees_for,
           frees_against  = EXCLUDED.frees_against,
           goals          = EXCLUDED.goals,
           behinds        = EXCLUDED.behinds,
           tog            = EXCLUDED.tog,
           fantasy_points = EXCLUDED.fantasy_points`,
        [
          r.matchId, r.playerId, r.playerName, r.team,
          r.stats.K, r.stats.HB, r.stats.D, r.stats.M, r.stats.T, r.stats.HO,
          r.stats.FF, r.stats.FA, r.stats.G, r.stats.B, r.stats.TOG, r.stats.AF,
        ]
      );
      upserted++;
    } catch (err) {
      // skip individual failures
    }
  }

  console.log(
    `📥 Cached game ${cdMatchId}: ${upserted} players saved to match_stats`
  );

  return records;
}

// ---------------------------------------------------------------------------
// Check DB for which games already have stats cached
// ---------------------------------------------------------------------------
async function getAlreadyCachedGames(pool) {
  try {
    const result = await pool.query(
      `SELECT match_id, COUNT(*) as cnt
       FROM match_stats
       WHERE match_id LIKE 'CD_M${CURRENT_SEASON}%'
       GROUP BY match_id
       HAVING COUNT(*) >= 20`
    );
    return new Set(result.rows.map((r) => r.match_id));
  } catch (err) {
    console.error("❌ getAlreadyCachedGames failed:", err.message);
    return new Set();
  }
}

// ---------------------------------------------------------------------------
// Patch selections for a completed round
// ---------------------------------------------------------------------------
async function patchSelectionsForRound(pool, season, round, statsByPlayerId) {
  if (Object.keys(statsByPlayerId).length === 0) return;

  const client = await pool.connect();
  try {
    const result = await client.query(
      `SELECT id, game_type, picks
       FROM selections
       WHERE season = $1 AND round = $2`,
      [season, round]
    );

    if (result.rows.length === 0) {
      console.log(`ℹ️  No selections for season=${season} round=${round}`);
      return;
    }

    let totalRows = 0;
    let totalPatched = 0;

    for (const row of result.rows) {
      const picks = Array.isArray(row.picks) ? row.picks : [];
      let rowPatched = false;
      let pickCount = 0;

      const patchedPicks = picks.map((punterRow) => {
        if (!Array.isArray(punterRow)) return punterRow;
        return punterRow.map((pick) => {
          const pid = pick?.playerId;
          if (!pid) return pick;
          const stats = statsByPlayerId[pid];
          if (stats) {
            rowPatched = true;
            pickCount++;
            return { ...pick, stats };
          }
          return pick;
        });
      });

      if (rowPatched) {
        await client.query(
          `UPDATE selections
           SET picks = $1::jsonb, updated_at = NOW()
           WHERE id = $2`,
          [JSON.stringify(patchedPicks), row.id]
        );
        totalRows++;
        totalPatched += pickCount;
      }
    }

    console.log(
      `✅ Patched selections: season=${season} round=${round} | ${totalRows} rows, ${totalPatched} picks`
    );
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// Build statsByPlayerId from match_stats DB for a set of match IDs
// (used when patching selections from cached data, not from DFS)
// ---------------------------------------------------------------------------
async function loadStatsFromDB(pool, matchIds) {
  const statsByPlayerId = {};
  try {
    const result = await pool.query(
      `SELECT player_id, kicks, handballs, disposals, marks, tackles,
              hitouts, frees_for, frees_against, goals, behinds, tog, fantasy_points
       FROM match_stats
       WHERE match_id = ANY($1)`,
      [matchIds]
    );
    for (const r of result.rows) {
      statsByPlayerId[r.player_id] = {
        K: r.kicks, HB: r.handballs, D: r.disposals,
        M: r.marks, T: r.tackles, HO: r.hitouts,
        FF: r.frees_for, FA: r.frees_against,
        G: r.goals, B: r.behinds, TOG: r.tog, AF: r.fantasy_points,
      };
    }
  } catch (err) {
    console.error("❌ loadStatsFromDB failed:", err.message);
  }
  return statsByPlayerId;
}

// ---------------------------------------------------------------------------
// Main check — runs every 2 minutes
// ---------------------------------------------------------------------------
async function checkForCompletedRounds(pool) {
  const matchesByRound = getMatchesByRound();

  // Load which games are already in the DB so we don't re-fetch
  const dbCached = await getAlreadyCachedGames(pool);
  for (const mid of dbCached) cachedGames.add(mid);

  // 1. For each round, try to cache any completed games we haven't cached yet
  for (const [roundStr, matchIds] of Object.entries(matchesByRound)) {
    const round = parseInt(roundStr);
    const key = `${CURRENT_SEASON}-${round}`;

    // If round is fully patched, skip entirely
    if (patchedRounds.has(key)) continue;

    // Check each game individually
    const uncachedIds = matchIds.filter((mid) => !cachedGames.has(mid));

    if (uncachedIds.length > 0) {
      for (const mid of uncachedIds) {
        const records = await fetchAndCacheGame(pool, mid);
        if (records.length >= 10) {
          cachedGames.add(mid);
        }
      }
    }

    // 2. If ALL games in this round are now cached, patch selections
    const allCached = matchIds.every((mid) => cachedGames.has(mid));
    if (allCached) {
      console.log(`🏁 Round ${round}: all ${matchIds.length} games cached — patching selections`);

      const statsByPlayerId = await loadStatsFromDB(pool, matchIds);
      await patchSelectionsForRound(pool, CURRENT_SEASON, round, statsByPlayerId);
      patchedRounds.add(key);
    }
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
export function startRoundCompletionScheduler(pool) {
  console.log("🔄 Round completion scheduler started (checks every 2 minutes)");

  checkForCompletedRounds(pool).catch((err) =>
    console.error("❌ RoundCompletion startup check failed:", err)
  );

  setInterval(() => {
    checkForCompletedRounds(pool).catch((err) =>
      console.error("❌ RoundCompletion check failed:", err)
    );
  }, CHECK_INTERVAL_MS);
}

// ---------------------------------------------------------------------------
// Exported for manual /ingestRoundStats endpoint and backfill
// ---------------------------------------------------------------------------

async function fetchRoundStats(matchIds) {
  const statsByPlayerId = {};
  const records = [];

  for (const cdMatchId of matchIds) {
    const dfsId = dfsMap[cdMatchId];
    if (!dfsId) continue;

    try {
      const players = await scrapeDFS(String(dfsId));
      if (!players || players.length === 0) continue;

      for (const p of players) {
        const pid = p.playerId;
        if (!pid) continue;

        const kicks = p.kicks ?? 0;
        const handballs = p.handballs ?? 0;
        const stats = {
          K: kicks, HB: handballs, D: kicks + handballs,
          M: p.marks ?? 0, T: p.tackles ?? 0, HO: p.hitouts ?? 0,
          FF: p.freesFor ?? 0, FA: p.freesAgainst ?? 0,
          G: p.goals ?? 0, B: p.behinds ?? 0,
          TOG: p.timeOnGroundPercentage ?? 0,
          AF: p.fantasyPoints ?? calculateFantasyPoints(p),
        };
        statsByPlayerId[pid] = stats;
        records.push({
          matchId: cdMatchId, playerId: pid,
          playerName: p.playerName || "",
          team: normAbbr(p.teamAbbr || p.team || ""),
          stats,
        });
      }
    } catch (err) {
      console.error(`❌ DFS fetch failed for ${cdMatchId}:`, err.message);
    }
  }

  return { statsByPlayerId, records };
}

async function upsertMatchStatsForRound(pool, season, round, records) {
  if (!records || records.length === 0) return 0;

  let upserted = 0;
  for (const r of records) {
    if (!r.playerId || !r.playerId.startsWith("CD_I") || !r.matchId) continue;
    try {
      await pool.query(
        `INSERT INTO match_stats
           (match_id, player_id, player_name, team,
            kicks, handballs, disposals, marks, tackles, hitouts,
            frees_for, frees_against, goals, behinds, tog, fantasy_points)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
         ON CONFLICT (match_id, player_id)
         DO UPDATE SET
           player_name = EXCLUDED.player_name, team = EXCLUDED.team,
           kicks = EXCLUDED.kicks, handballs = EXCLUDED.handballs,
           disposals = EXCLUDED.disposals, marks = EXCLUDED.marks,
           tackles = EXCLUDED.tackles, hitouts = EXCLUDED.hitouts,
           frees_for = EXCLUDED.frees_for, frees_against = EXCLUDED.frees_against,
           goals = EXCLUDED.goals, behinds = EXCLUDED.behinds,
           tog = EXCLUDED.tog, fantasy_points = EXCLUDED.fantasy_points`,
        [
          r.matchId, r.playerId, r.playerName, r.team,
          r.stats.K, r.stats.HB, r.stats.D, r.stats.M, r.stats.T, r.stats.HO,
          r.stats.FF, r.stats.FA, r.stats.G, r.stats.B, r.stats.TOG, r.stats.AF,
        ]
      );
      upserted++;
    } catch (err) { /* skip */ }
  }
  return upserted;
}

export { fetchRoundStats, upsertMatchStatsForRound };