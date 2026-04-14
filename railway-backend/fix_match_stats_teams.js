/**
 * fix_match_stats_teams.js
 * Updates the team column in match_stats table using correct club data.
 * Run once after seed_match_stats.js.
 */
import pg from "pg";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);

const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

const gameStats  = JSON.parse(readFileSync(join(__dirname, "all_game_stats.json"), "utf8"));
const dfsMap     = JSON.parse(readFileSync(join(__dirname, "dfs_map.json"),         "utf8"));
const playersRaw = JSON.parse(readFileSync(join(__dirname, "players_2026.json"),    "utf8"));

const playersList = Array.isArray(playersRaw) ? playersRaw : (playersRaw.players ?? []);

// Build id -> club from roster
const idToClub = {};
const nameToClub = {};
for (const p of playersList) {
  const pid  = p.id ?? p.playerId;
  const name = (p.name ?? p.fullName ?? "").trim().toLowerCase();
  const club = p.club ?? p.team ?? "";
  if (pid  && club) idToClub[pid]   = club;
  if (name && club) nameToClub[name] = club;
}

// Manual overrides for players with mismatched DFS IDs
const overrides = {
  "CD_I993903":  "GWS",  // Jacob Hopper
  "CD_I1036104": "WBD",  // Will Lewis
  "CD_I1040573": "COL",  // Christopher Scerri
  "CD_I1034305": "ESS",  // Jacob Farrow
  "CD_I1029603": "ADE",  // Mitch Zadow
  "CD_I1020887": "MELB", // Paddy Cross
  "CD_I1011771": "HAW",  // Flynn Perez
  "CD_I1012862": "CAR",  // Elijah Hollands (was mapped to Zane Peucker/RIC)
};

async function run() {
  const client = await pool.connect();
  let updated = 0;
  let missing = 0;

  try {
    for (const [cdMatchId, dfsId] of Object.entries(dfsMap)) {
      const players = gameStats[String(dfsId)] ?? [];
      for (const p of players) {
        const pid   = p.playerId ?? "";
        const pname = (p.playerName ?? "").trim().toLowerCase();

        // Priority: override > roster ID > roster name
        const club = overrides[pid] ?? idToClub[pid] ?? nameToClub[pname] ?? null;

        if (!club) { missing++; continue; }

        await client.query(
          `UPDATE match_stats SET team = $1 WHERE match_id = $2 AND player_id = $3`,
          [club, cdMatchId, pid]
        );
        updated++;
      }
    }

    console.log(`✅ Updated: ${updated}, Missing: ${missing}`);

    // Verify Elijah Hollands
    const check = await client.query(
      `SELECT player_name, team FROM match_stats WHERE player_id = 'CD_I1012862' LIMIT 3`
    );
    console.log("Elijah Hollands rows:", check.rows);

  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(err => { console.error(err); process.exit(1); });
