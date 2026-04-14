/**
 * fix_match_stats_names.js
 * Updates player_name and team in match_stats using players_2026.json
 * as the authoritative source. Fixes abbreviated names like "I Heeney" -> "Isaac Heeney"
 * Run once.
 */
import pg from "pg";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const playersRaw = JSON.parse(readFileSync(join(__dirname, "players_2026.json"), "utf8"));
const playersList = Array.isArray(playersRaw) ? playersRaw : (playersRaw.players ?? []);

// Manual DFS ID overrides for mismatched IDs
const overrides = {
  "CD_I993903":  { name: "Jacob Hopper",        club: "GWS" },
  "CD_I1036104": { name: "Will Lewis",           club: "WBD" },
  "CD_I1040573": { name: "Christopher Scerri",   club: "COL" },
  "CD_I1034305": { name: "Jacob Farrow",         club: "ESS" },
  "CD_I1029603": { name: "Mitch Zadow",          club: "ADE" },
  "CD_I1020887": { name: "Paddy Cross",          club: "MELB" },
  "CD_I1011771": { name: "Flynn Perez",          club: "HAW" },
  "CD_I1012862": { name: "Elijah Hollands",      club: "CAR" },
};

async function run() {
  const client = await pool.connect();
  try {
    // Build lookup from roster
    const idToPlayer = {};
    for (const p of playersList) {
      const pid  = p.id ?? p.playerId;
      const name = (p.name ?? p.fullName ?? "").replace(/\u00a0/g, " ").trim();
      const club = p.club ?? p.team ?? "";
      if (pid && name) idToPlayer[pid] = { name, club };
    }

    // Apply overrides
    for (const [pid, data] of Object.entries(overrides)) {
      idToPlayer[pid] = data;
    }

    console.log(`Loaded ${Object.keys(idToPlayer).length} players from roster`);

    // Get all unique player_ids from match_stats
    const result = await client.query(
      `SELECT DISTINCT player_id FROM match_stats`
    );

    let updated = 0;
    let notFound = 0;

    for (const row of result.rows) {
      const pid = row.player_id;
      const player = idToPlayer[pid];

      if (!player) {
        notFound++;
        continue;
      }

      await client.query(
        `UPDATE match_stats SET player_name = $1, team = $2 WHERE player_id = $3`,
        [player.name, player.club, pid]
      );
      updated++;
    }

    console.log(`✅ Updated: ${updated}, Not found: ${notFound}`);

    // Verify Heeney fix
    const check = await client.query(
      `SELECT DISTINCT player_id, player_name, team, COUNT(*) as games
       FROM match_stats
       WHERE player_name ILIKE '%heeney%'
       GROUP BY player_id, player_name, team`
    );
    console.log("\nHeeney check:", check.rows);

  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(err => { console.error(err); process.exit(1); });
