/**
 * scrape_dfs_history.js - PARALLEL VERSION
 * Runs 4 browser pages concurrently for ~4x speed improvement
 * Expected time: ~4 minutes instead of 15
 */

import pg from "pg";
import puppeteer from "puppeteer";
import { readFileSync, existsSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);

const CONCURRENCY = 6; // number of parallel browser pages

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const TEAMS   = ["ADE","BRL","CAR","COL","ESS","FRE","GCS","GEE","GWS","HAW","MEL","NTH","PTA","RIC","STK","SYD","WBD","WCE"];
const SEASONS = [2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024,2025,2026];

function loadFixtureMap() {
  const map = {};
  const ABBR = {
    "Adelaide Crows":"ADE","Adelaide":"ADE","Brisbane Lions":"BRL","Brisbane":"BRL",
    "Carlton":"CAR","Collingwood":"COL","Essendon":"ESS","Fremantle":"FRE",
    "Gold Coast Suns":"GCS","Gold Coast":"GCS","GWS Giants":"GWS","Greater Western Sydney":"GWS",
    "Geelong Cats":"GEE","Geelong":"GEE","Hawthorn":"HAW","Melbourne":"MEL",
    "North Melbourne":"NTH","Port Adelaide":"PTA","Richmond":"RIC","St Kilda":"STK",
    "Sydney Swans":"SYD","Sydney":"SYD","West Coast Eagles":"WCE","West Coast":"WCE",
    "Western Bulldogs":"WBD",
  };
  function toAbbr(name) {
    const n = name.trim();
    if (ABBR[n]) return ABBR[n];
    for (const [key, val] of Object.entries(ABBR)) {
      if (n.includes(key) || key.includes(n)) return val;
    }
    return n.substring(0,3).toUpperCase();
  }
  const csvPaths = [
    join(__dirname, "../assets/afl_fixtures_2026.csv"),
    join(__dirname, "afl_fixtures_2026.csv"),
  ];
  for (const csvPath of csvPaths) {
    if (!existsSync(csvPath)) continue;
    const lines = readFileSync(csvPath, "utf8").split("\n");
    const headers = lines[0].split(",").map(h => h.trim().replace(/^"|"$/g, ""));
    const roundIdx  = headers.findIndex(h => h === "ROUND");
    const homeIdx   = headers.findIndex(h => h === "HOME TEAM");
    const awayIdx   = headers.findIndex(h => h === "AWAY TEAM");
    const seasonIdx = headers.findIndex(h => h === "SEASON");
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(",").map(c => c.trim().replace(/^"|"$/g, ""));
      if (cols.length < 3) continue;
      const m = (cols[roundIdx] ?? "").match(/(\d+)/);
      if (!m) continue;
      const round  = parseInt(m[1]);
      const season = parseInt(cols[seasonIdx] ?? "2026");
      const home   = toAbbr(cols[homeIdx] ?? "");
      const away   = toAbbr(cols[awayIdx] ?? "");
      if (!home || !away) continue;
      if (!map[season]) map[season] = {};
      if (!map[season][home]) map[season][home] = {};
      if (!map[season][away]) map[season][away] = {};
      map[season][home][round] = away;
      map[season][away][round] = home;
    }
    break;
  }
  return map;
}

async function newPage(browser) {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });
  await page.setRequestInterception(true);
  page.on("request", req => {
    const url = req.url();
    const type = req.resourceType();
    // Block images, fonts, media, ads, analytics - keep only page HTML and dfsaustralia scripts
    if (["image","font","media"].includes(type)) {
      req.abort();
    } else if (type === "script" && !url.includes("dfsaustralia") && !url.includes("jquery") && !url.includes("datatables")) {
      req.abort();
    } else if (type === "stylesheet" && !url.includes("dfsaustralia") && !url.includes("datatables")) {
      req.abort();
    } else if (url.includes("google") || url.includes("facebook") || url.includes("adsby") || url.includes("analytics") || url.includes("fundingchoices")) {
      req.abort();
    } else {
      req.continue();
    }
  });
  return page;
}

async function scrapePage(page, team, season) {
  const url = `https://dfsaustralia.com/afl-fantasy-points/?team=${team}&season=${season}`;
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 15000 });
    await page.waitForFunction(() => {
      const t = [...document.querySelectorAll("table")].find(t =>
        t.rows.length > 2 && t.textContent.includes("AVG"));
      return !!t;
    }, { timeout: 6000 }).catch(() => {});

    return await page.evaluate(() => {
      const table = [...document.querySelectorAll("table")].find(t =>
        t.rows.length > 2 && t.textContent.includes("PLAYER") && t.textContent.includes("AVG"));
      if (!table) return [];
      const rows = [...table.querySelectorAll("tr")];
      const headerCells = [...rows[0].querySelectorAll("th,td")].map(c => c.textContent.trim());
      const roundIndices = {};
      headerCells.forEach((h, i) => {
        const m = h.match(/^R(\d+)$/);
        if (m) roundIndices[parseInt(m[1])] = i;
      });
      return rows.slice(1).map(row => {
        const cells = [...row.querySelectorAll("td,th")].map(c => c.textContent.trim());
        if (!cells[0] || cells[0] === "PLAYER") return null;
        const roundScores = {};
        for (const [round, idx] of Object.entries(roundIndices)) {
          const val = cells[idx];
          if (val && !isNaN(parseInt(val))) roundScores[parseInt(round)] = parseInt(val);
        }
        return Object.keys(roundScores).length > 0
          ? { playerName: cells[0], roundScores }
          : null;
      }).filter(Boolean);
    });
  } catch (err) {
    return [];
  }
}

async function processJob(page, job, fixtureMap, client, counter, total) {
  const { team, season } = job;
  process.stdout.write(`  Loading ${team} ${season}... `);
  const players = await scrapePage(page, team, season);
  counter.done++;
  const pct = Math.round(counter.done / total * 100);

  if (players.length === 0) {
    console.log(`  [${pct}%] ${team} ${season}: no data`);
    return;
  }

  // Batch all inserts into one query
  const values = [];
  const params = [];
  let p = 1;
  for (const { playerName, roundScores } of players) {
    for (const [round, score] of Object.entries(roundScores)) {
      const rnd      = parseInt(round);
      const opponent = fixtureMap[season]?.[team]?.[rnd] ?? null;
      values.push(`($${p},$${p+1},$${p+2},$${p+3},$${p+4},$${p+5})`);
      params.push(playerName, team, season, rnd, score, opponent);
      p += 6;
    }
  }
  let inserted = 0;
  if (values.length > 0) {
    try {
      const result = await client.query(`
        INSERT INTO historical_scores (player_name, team, season, round, score, opponent)
        VALUES ${values.join(",")}
        ON CONFLICT (player_name, team, season, round)
        DO UPDATE SET score=EXCLUDED.score, opponent=EXCLUDED.opponent
      `, params);
      inserted = result.rowCount ?? values.length / 6;
    } catch (err) {
      // Fall back to row-by-row if batch fails
      for (let i = 0; i < params.length; i += 6) {
        try {
          await client.query(`
            INSERT INTO historical_scores (player_name, team, season, round, score, opponent)
            VALUES ($1,$2,$3,$4,$5,$6)
            ON CONFLICT (player_name, team, season, round)
            DO UPDATE SET score=EXCLUDED.score, opponent=EXCLUDED.opponent
          `, params.slice(i, i+6));
          inserted++;
        } catch (_) {}
      }
    }
  }
  console.log(`  [${pct}%] ${team} ${season}: ${players.length} players, ${inserted} scores`);
}

async function run() {
  const client = await pool.connect();
  let browser;
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS historical_scores (
        id SERIAL PRIMARY KEY,
        player_name TEXT NOT NULL,
        team TEXT NOT NULL,
        season INT NOT NULL,
        round INT NOT NULL,
        score INT NOT NULL,
        opponent TEXT,
        UNIQUE(player_name, team, season, round)
      )
    `);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_hist_player_opponent ON historical_scores(player_name, opponent)`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_hist_team_season ON historical_scores(team, season)`);
    console.log("✅ DB table ready");

    const fixtureMap = loadFixtureMap();

    // Build job list - skip already completed team/season combos
    const done = await client.query(`
      SELECT DISTINCT team, season FROM historical_scores
    `);
    const doneSet = new Set(done.rows.map(r => `${r.team}_${r.season}`));

    const jobs = [];
    for (const season of SEASONS) {
      for (const team of TEAMS) {
        if (!doneSet.has(`${team}_${season}`)) {
          jobs.push({ team, season });
        }
      }
    }

    const skipped = TEAMS.length * SEASONS.length - jobs.length;
    console.log(`📋 ${jobs.length} jobs to process, ${skipped} already done`);

    if (jobs.length === 0) {
      console.log("✅ All done already!");
      return;
    }

    console.log(`🚀 Launching browser with ${CONCURRENCY} parallel pages...`);
    browser = await puppeteer.launch({
      headless: "new",
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    // Create pool of pages
    const pages = await Promise.all(
      Array.from({ length: CONCURRENCY }, () => newPage(browser))
    );

    const counter = { done: 0 };
    const total   = jobs.length;

    // Process jobs using page pool
    let jobIndex = 0;
    async function worker(page) {
      const workerClient = await pool.connect();
      try {
        while (jobIndex < jobs.length) {
          const job = jobs[jobIndex++];
          await processJob(page, job, fixtureMap, workerClient, counter, total);
          await new Promise(r => setTimeout(r, 50));
        }
      } finally {
        workerClient.release();
      }
    }

    await Promise.all(pages.map(page => worker(page)));

    console.log(`\n✅ Complete!`);
    const count = await client.query("SELECT COUNT(*) FROM historical_scores");
    console.log(`Total rows in DB: ${count.rows[0].count}`);

    // Sample check
    const sample = await client.query(`
      SELECT opponent, COUNT(*) games, ROUND(AVG(score)) avg
      FROM historical_scores WHERE player_name = 'Patrick Dangerfield'
      GROUP BY opponent ORDER BY avg DESC LIMIT 5
    `);
    if (sample.rows.length > 0) {
      console.log("\nDangerfield top 5 opponents:");
      sample.rows.forEach(r => console.log(`  vs ${r.opponent}: ${r.games} games, avg ${r.avg}`));
    }

  } finally {
    if (browser) await browser.close();
    client.release();
    await pool.end();
  }
}

run().catch(err => { console.error(err); process.exit(1); });
