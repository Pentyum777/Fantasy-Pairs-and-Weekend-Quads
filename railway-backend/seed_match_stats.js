/**
 * seed_match_stats.js
 * Creates a match_stats table and populates it with full player stats
 * for all historical games. Run once.
 * 
 * Usage:
 *   DATABASE_URL=postgres://... node seed_match_stats.js
 */

import pg from "pg";
import { readFileSync } from "fs";
const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);

const gameStats   = JSON.parse(readFileSync(join(__dirname, "all_game_stats.json"),  "utf8"));
const dfsMap      = JSON.parse(readFileSync(join(__dirname, "dfs_map.json"),         "utf8"));
const playersRaw  = JSON.parse(readFileSync(join(__dirname, "players_2026.json"),    "utf8"));

// Build playerId -> {name, club} lookup
const playerLookup = {};
const players = Array.isArray(playersRaw) ? playersRaw : (playersRaw.players ?? []);
for (const p of players) {
  const id = p.id ?? p.playerId;
  if (id) playerLookup[id] = { name: p.name ?? p.fullName ?? "", club: p.club ?? p.team ?? "" };
}

async function run() {
  const client = await pool.connect();
  try {
    // Create table
    await client.query(`
      CREATE TABLE IF NOT EXISTS match_stats (
        id SERIAL PRIMARY KEY,
        match_id TEXT NOT NULL,
        player_id TEXT NOT NULL,
        player_name TEXT,
        team TEXT,
        kicks INT DEFAULT 0,
        handballs INT DEFAULT 0,
        disposals INT DEFAULT 0,
        marks INT DEFAULT 0,
        tackles INT DEFAULT 0,
        hitouts INT DEFAULT 0,
        frees_for INT DEFAULT 0,
        frees_against INT DEFAULT 0,
        goals INT DEFAULT 0,
        behinds INT DEFAULT 0,
        tog INT DEFAULT 0,
        fantasy_points INT DEFAULT 0,
        UNIQUE(match_id, player_id)
      )
    `);
    console.log("✅ Table created/verified");

    let inserted = 0;
    let skipped = 0;

    console.log(`📊 Games in dfsMap: ${Object.keys(dfsMap).length}`);
    console.log(`📊 Games in gameStats: ${Object.keys(gameStats).length}`);
    console.log(`📊 Players loaded: ${Object.keys(playerLookup).length}`);

    for (const [cdMatchId, dfsId] of Object.entries(dfsMap)) {
      const players = gameStats[String(dfsId)];
      if (!players || players.length === 0) { skipped++; continue; }

      for (const p of players) {
        const pid = p.playerId ?? p.id ?? "";
        if (!pid) continue;

        const lookup = playerLookup[pid] ?? {};
        const name = p.playerName ?? lookup.name ?? "";
        const team = p.teamAbbr ?? lookup.club ?? "";

        await client.query(`
          INSERT INTO match_stats
            (match_id, player_id, player_name, team,
             kicks, handballs, disposals, marks, tackles,
             hitouts, frees_for, frees_against, goals, behinds, tog, fantasy_points)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
          ON CONFLICT (match_id, player_id) DO UPDATE SET
            player_name = EXCLUDED.player_name,
            team = EXCLUDED.team,
            kicks = EXCLUDED.kicks,
            handballs = EXCLUDED.handballs,
            disposals = EXCLUDED.disposals,
            marks = EXCLUDED.marks,
            tackles = EXCLUDED.tackles,
            hitouts = EXCLUDED.hitouts,
            frees_for = EXCLUDED.frees_for,
            frees_against = EXCLUDED.frees_against,
            goals = EXCLUDED.goals,
            behinds = EXCLUDED.behinds,
            tog = EXCLUDED.tog,
            fantasy_points = EXCLUDED.fantasy_points
        `, [
          cdMatchId, pid, name, team,
          p.stats?.K ?? p.kicks ?? 0,
          p.stats?.HB ?? p.handballs ?? 0,
          p.stats?.D ?? p.disposals ?? 0,
          p.stats?.M ?? p.marks ?? 0,
          p.stats?.T ?? p.tackles ?? 0,
          p.stats?.HO ?? p.hitouts ?? 0,
          p.stats?.FF ?? p.freesFor ?? 0,
          p.stats?.FA ?? p.freesAgainst ?? 0,
          p.stats?.G ?? p.goals ?? 0,
          p.stats?.B ?? p.behinds ?? 0,
          p.stats?.TOG ?? p.timeOnGroundPercentage ?? 0,
          p.stats?.AF ?? p.fantasyPoints ?? 0,
        ]);
        inserted++;
      }
      console.log(`  ✅ ${cdMatchId} -> ${players.length} players`);
    }

    console.log(`\n✅ Done! Inserted/updated: ${inserted}, skipped (no data): ${skipped}`);

    // Verify
    const count = await client.query("SELECT COUNT(*) FROM match_stats");
    console.log(`Total rows in match_stats: ${count.rows[0].count}`);

  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(err => { console.error(err); process.exit(1); });
