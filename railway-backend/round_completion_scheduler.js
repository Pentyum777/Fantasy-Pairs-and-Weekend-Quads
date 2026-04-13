/**
 * round_completion_scheduler.js
 *
 * Runs on the Railway server 24/7. Every 2 minutes it checks whether
 * any AFL round has just completed (all fixtures finished). When it
 * detects a completed round, it:
 *
 *   1. Fetches final DFS stats for every match in that round
 *   2. Loads all selections rows for that season/round from Postgres
 *   3. Patches each pick's stats with the real fantasy scores
 *   4. Saves back to Postgres
 *
 * This means stats are always saved automatically — no Flutter client
 * needs to be open when a round finishes.
 *
 * Usage: imported and started from server.js
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { scrapeDFS } from "./dfs_scraper.js";
import { getSquiggleStatusForMatch } from "./squiggle_service.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dfsMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "dfs_map.json"), "utf8")
);
const squiggleMap = JSON.parse(
  fs.readFileSync(path.join(__dirname, "squiggle_map.json"), "utf8")
);

// Track which rounds we've already saved so we don't double-save
const savedRounds = new Set(); // "season-round" keys

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
// Uses dfs_map keys which follow CD_M{season}{round}{game} pattern
// ---------------------------------------------------------------------------
function getMatchesByRound() {
  const byRound = {};

  for (const [cdMatchId] of Object.entries(dfsMap)) {
    // CD_M20260140401 → season=2026, competition=014, round=04, game=01
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
// Check if all matches in a round are complete via Squiggle
// Returns: "all_complete" | "some_live" | "none_started"
// ---------------------------------------------------------------------------
async function getRoundStatus(matchIds) {
  let completedCount = 0;
  let liveCount = 0;
  let upcomingCount = 0;

  for (const matchId of matchIds) {
    const status = await getSquiggleStatusForMatch(matchId);
    if (status === "Final") completedCount++;
    else if (status === "In Progress") liveCount++;
    else upcomingCount++;
  }

  if (liveCount > 0) return "some_live";
  if (completedCount === matchIds.length) return "all_complete";
  if (completedCount > 0 && upcomingCount > 0) return "some_live"; // mid-round
  return "none_started";
}

// ---------------------------------------------------------------------------
// Fetch DFS stats for all matches in a round
// Returns: Map of playerId -> stats object
// ---------------------------------------------------------------------------
async function fetchRoundStats(matchIds) {
  const statsByPlayerId = {};

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

        statsByPlayerId[pid] = {
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
      }
    } catch (err) {
      console.error(
        `❌ RoundCompletion: DFS fetch failed for ${cdMatchId}:`,
        err.message
      );
    }
  }

  return statsByPlayerId;
}

// ---------------------------------------------------------------------------
// Patch all selections rows for a given season/round with real stats
// ---------------------------------------------------------------------------
async function patchSelectionsForRound(pool, season, round, statsByPlayerId) {
  if (Object.keys(statsByPlayerId).length === 0) {
    console.log(
      `⚠️  RoundCompletion: No stats fetched for season=${season} round=${round} — skipping patch`
    );
    return;
  }

  const client = await pool.connect();

  try {
    const result = await client.query(
      `SELECT id, game_type, picks
       FROM selections
       WHERE season = $1 AND round = $2`,
      [season, round]
    );

    if (result.rows.length === 0) {
      console.log(
        `ℹ️  RoundCompletion: No selections found for season=${season} round=${round}`
      );
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
        console.log(
          `  ✅ Patched: season=${season} round=${round} game_type=${row.game_type} | ${pickCount} picks`
        );
      }
    }

    console.log(
      `✅ RoundCompletion: season=${season} round=${round} | ${totalRows} rows updated, ${totalPatched} picks patched`
    );
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// Main check — runs every 2 minutes
// ---------------------------------------------------------------------------
async function checkForCompletedRounds(pool) {
  const matchesByRound = getMatchesByRound();

  for (const [roundStr, matchIds] of Object.entries(matchesByRound)) {
    const round = parseInt(roundStr);
    const key = `${CURRENT_SEASON}-${round}`;

    // Skip rounds we've already saved this server session
    if (savedRounds.has(key)) continue;

    const status = await getRoundStatus(matchIds);

    if (status !== "all_complete") continue;

    console.log(
      `🏁 RoundCompletion: Round ${round} is complete — fetching stats...`
    );

    const statsByPlayerId = await fetchRoundStats(matchIds);

    console.log(
      `📊 RoundCompletion: ${Object.keys(statsByPlayerId).length} players' stats fetched`
    );

    await patchSelectionsForRound(pool, CURRENT_SEASON, round, statsByPlayerId);

    // Mark as saved so we don't re-run until server restarts
    // (On next restart it will re-check, but the UPDATE is idempotent)
    savedRounds.add(key);
  }
}

// ---------------------------------------------------------------------------
// Public API — call this from server.js
// ---------------------------------------------------------------------------
export function startRoundCompletionScheduler(pool) {
  console.log(
    "🔄 Round completion scheduler started (checks every 2 minutes)"
  );

  // Run once immediately on startup to catch any rounds completed while
  // the server was down
  checkForCompletedRounds(pool).catch((err) =>
    console.error("❌ RoundCompletion startup check failed:", err)
  );

  setInterval(() => {
    checkForCompletedRounds(pool).catch((err) =>
      console.error("❌ RoundCompletion check failed:", err)
    );
  }, CHECK_INTERVAL_MS);
}