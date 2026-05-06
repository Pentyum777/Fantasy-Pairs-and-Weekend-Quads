/**
 * list_punters.js
 * Lists all punters who have played Pairs and Quads in 2026 (from Round 0).
 *
 * Usage:
 *   $env:DATABASE_URL="postgresql://postgres:eelkdWXpRAhaYOBAmzQgXzprYksdFFXY@maglev.proxy.rlwy.net:13592/railway"
 *   node list_punters.js
 */
import pg from "pg";
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  // Pairs punters
  const pairsResult = await pool.query(`
    SELECT round, punter_names
    FROM selections
    WHERE season = 2026 AND game_type = 'sunday_pairs'
    ORDER BY round ASC
  `);

  const pairsPunters = new Map();
  for (const row of pairsResult.rows) {
    const names = Array.isArray(row.punter_names) ? row.punter_names.filter(n => n && n.trim()) : [];
    for (const name of names) {
      if (!pairsPunters.has(name)) pairsPunters.set(name, []);
      pairsPunters.get(name).push(row.round);
    }
  }

  console.log(`\n=== SUNDAY PAIRS (2026) — ${pairsPunters.size} punters ===`);
  for (const [name, rounds] of [...pairsPunters.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    console.log(`  ${name.padEnd(25)} Rounds: ${rounds.join(', ')}  (${rounds.length} games)`);
  }

  // Quads punters
  const quadsResult = await pool.query(`
    SELECT round, punter_names
    FROM selections
    WHERE season = 2026 AND game_type = 'weekend_quads'
    ORDER BY round ASC
  `);

  const quadsPunters = new Map();
  for (const row of quadsResult.rows) {
    const names = Array.isArray(row.punter_names) ? row.punter_names.filter(n => n && n.trim()) : [];
    for (const name of names) {
      if (!quadsPunters.has(name)) quadsPunters.set(name, []);
      quadsPunters.get(name).push(row.round);
    }
  }

  console.log(`\n=== WEEKEND QUADS (2026) — ${quadsPunters.size} punters ===`);
  for (const [name, rounds] of [...quadsPunters.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    console.log(`  ${name.padEnd(25)} Rounds: ${rounds.join(', ')}  (${rounds.length} games)`);
  }

  await pool.end();
}

run().catch(err => { console.error(err); process.exit(1); });
