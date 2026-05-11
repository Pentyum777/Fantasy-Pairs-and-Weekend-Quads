/**
 * fix_undefined_names.js
 * Fixes player names that got corrupted to "undefined undefined" or empty
 * by the live DFS caching bug. Uses players_2026.json as the source of truth.
 *
 * Usage:
 *   $env:DATABASE_URL="postgresql://postgres:eelkdWXpRAhaYOBAmzQgXzprYksdFFXY@maglev.proxy.rlwy.net:13592/railway"
 *   node fix_undefined_names.js
 */
import pg from "pg";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  const playersData = JSON.parse(fs.readFileSync(path.join(__dirname, "players_2026.json"), "utf8"));
  const players = playersData.players || playersData;
  
  let fixed = 0;
  for (const p of players) {
    if (!p.id || !p.name) continue;
    const name = p.name.replace(/\u00a0/g, " ");
    const result = await pool.query(
      `UPDATE match_stats SET player_name = $1 WHERE player_id = $2 AND (player_name = '' OR player_name LIKE '%undefined%' OR player_name != $1)`,
      [name, p.id]
    );
    if (result.rowCount > 0) {
      fixed += result.rowCount;
      console.log(`  Fixed ${result.rowCount} rows: ${p.id} → "${name}"`);
    }
  }
  console.log(`\n✅ Done! ${fixed} rows fixed`);
  await pool.end();
}
run().catch(err => { console.error(err); process.exit(1); });
