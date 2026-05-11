import pg from "pg";
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  const r = await pool.query(
    `SELECT match_id, player_name, player_id, team FROM match_stats WHERE player_name = '' OR player_name IS NULL LIMIT 20`
  );
  console.log("Empty name rows:", r.rows.length);
  r.rows.forEach(r => console.log(r.match_id, r.player_id, r.team));

  const r2 = await pool.query(
    `SELECT match_id, COUNT(*) as cnt FROM match_stats WHERE player_name = '' OR player_name IS NULL GROUP BY match_id`
  );
  r2.rows.forEach(r => console.log("Match", r.match_id, ":", r.cnt, "empty names"));

  const total = await pool.query(`SELECT COUNT(*) as cnt FROM match_stats WHERE player_name = '' OR player_name IS NULL`);
  console.log("\nTotal rows with empty names:", total.rows[0].cnt);

  await pool.end();
}
run().catch(err => { console.error(err); process.exit(1); });
