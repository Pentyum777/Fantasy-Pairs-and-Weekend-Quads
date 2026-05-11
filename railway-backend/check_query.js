import pg from "pg";
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function run() {
  const result = await pool.query(`
    SELECT
      player_id,
      (array_agg(player_name ORDER BY CASE WHEN player_name <> '' THEN 0 ELSE 1 END, match_id DESC))[1] AS player_name,
      (array_agg(team ORDER BY CASE WHEN team <> '' THEN 0 ELSE 1 END, match_id DESC))[1] AS team
    FROM match_stats
    WHERE match_id LIKE 'CD_M2026%'
      AND fantasy_points > 0
    GROUP BY player_id
    ORDER BY player_name
    LIMIT 10
  `);

  console.log("Sample rows:");
  result.rows.forEach(r => console.log(`  ${r.player_id}  name="${r.player_name}"  team="${r.team}"`));

  await pool.end();
}
run().catch(err => { console.error(err); process.exit(1); });
