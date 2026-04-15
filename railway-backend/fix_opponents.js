/**
 * fix_opponents.js
 * Fetches historical fixtures from Squiggle API (2013-2025)
 * and updates the opponent column in historical_scores table.
 * 
 * Run: DATABASE_URL=postgres://... node fix_opponents.js
 */

import pg from "pg";
import fetch from "node-fetch";

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const SEASONS = [2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024,2025];

// DFS team abbr -> Squiggle team name mapping
const SQUIGGLE_TO_DFS = {
  "Adelaide":           "ADE",
  "Brisbane Lions":     "BRL",
  "Carlton":            "CAR",
  "Collingwood":        "COL",
  "Essendon":           "ESS",
  "Fremantle":          "FRE",
  "Gold Coast":         "GCS",
  "Geelong":            "GEE",
  "Greater Western Sydney": "GWS",
  "GWS":                "GWS",
  "Hawthorn":           "HAW",
  "Melbourne":          "MEL",
  "North Melbourne":    "NTH",
  "Port Adelaide":      "PTA",
  "Richmond":           "RIC",
  "St Kilda":           "STK",
  "Sydney":             "SYD",
  "West Coast":         "WCE",
  "Western Bulldogs":   "WBD",
};

function toAbbr(name) {
  if (SQUIGGLE_TO_DFS[name]) return SQUIGGLE_TO_DFS[name];
  for (const [key, val] of Object.entries(SQUIGGLE_TO_DFS)) {
    if (name.includes(key) || key.includes(name)) return val;
  }
  return name.substring(0,3).toUpperCase();
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function fetchSeasonFixtures(season) {
  // Build fixture map: {season: {team: {round: opponent}}}
  const map = {};
  
  try {
    const url = `https://api.squiggle.com.au/?q=games;year=${season};complete=100`;
    const res = await fetch(url, {
      headers: { "User-Agent": "fantasy-pairs-app/1.0" },
      timeout: 15000,
    });
    if (!res.ok) return map;
    
    const data = await res.json();
    const games = data.games ?? [];
    
    for (const game of games) {
      const round = game.round;
      if (!round) continue;
      
      const home = toAbbr(game.hteam ?? "");
      const away = toAbbr(game.ateam ?? "");
      if (!home || !away) continue;
      
      if (!map[home]) map[home] = {};
      if (!map[away]) map[away] = {};
      map[home][round] = away;
      map[away][round] = home;
    }
    
    console.log(`  ${season}: ${games.length} games loaded`);
  } catch (err) {
    console.warn(`  ${season}: ${err.message}`);
  }
  
  return map;
}

async function run() {
  const client = await pool.connect();
  try {
    let totalUpdated = 0;
    
    for (const season of SEASONS) {
      process.stdout.write(`Fetching ${season} fixtures... `);
      const fixtureMap = await fetchSeasonFixtures(season);
      
      if (Object.keys(fixtureMap).length === 0) {
        console.log("no data");
        continue;
      }
      
      // Build update cases for this season
      let updated = 0;
      for (const [team, rounds] of Object.entries(fixtureMap)) {
        for (const [round, opponent] of Object.entries(rounds)) {
          const result = await client.query(`
            UPDATE historical_scores
            SET opponent = $1
            WHERE season = $2 AND team = $3 AND round = $4
              AND (opponent IS NULL OR opponent = '')
          `, [opponent, season, team, parseInt(round)]);
          updated += result.rowCount ?? 0;
        }
      }
      
      console.log(`updated ${updated} rows`);
      totalUpdated += updated;
      
      // Polite delay between API calls
      await sleep(500);
    }
    
    console.log(`\n✅ Done! Total rows updated: ${totalUpdated}`);
    
    // Verify Dangerfield
    const check = await client.query(`
      SELECT opponent, COUNT(*) games, ROUND(AVG(score)) avg
      FROM historical_scores
      WHERE player_name = 'Patrick Dangerfield'
        AND opponent IS NOT NULL
      GROUP BY opponent
      ORDER BY avg DESC
      LIMIT 8
    `);
    console.log("\nDangerfield vs opponents (top 8 by avg):");
    check.rows.forEach(r => console.log(`  vs ${r.opponent}: ${r.games} games, avg ${r.avg}`));
    
    // Count nulls remaining
    const nullCount = await client.query(`
      SELECT COUNT(*) FROM historical_scores WHERE opponent IS NULL
    `);
    console.log(`\nRows still without opponent: ${nullCount.rows[0].count}`);
    
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(err => { console.error(err); process.exit(1); });
