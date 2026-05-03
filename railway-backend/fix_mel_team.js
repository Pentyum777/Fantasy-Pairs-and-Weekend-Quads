/**
 * fix_mel_team.js
 * Normalises "MEL" to "MELB" in match_stats table.
 *
 * Usage:
 *   $env:DATABASE_URL="postgresql://postgres:eelkdWXpRAhaYOBAmzQgXzprYksdFFXY@maglev.proxy.rlwy.net:13592/railway"
 *   node fix_mel_team.js
 */
import pg from "pg";
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  const result = await pool.query(`UPDATE match_stats SET team = 'MELB' WHERE team = 'MEL'`);
  console.log(`✅ Updated ${result.rowCount} rows: MEL → MELB`);
  await pool.end();
}
run().catch(err => { console.error(err); process.exit(1); });
