// scripts/migrate_2026_completed.js

import fs from "fs";
import path from "path";
import fetch from "node-fetch";
import xlsx from "xlsx";

const BACKEND = "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";
const CACHE_FILE = path.resolve("data/stats_cache.json");

// ------------------------------------------------------------
// Load existing cache
// ------------------------------------------------------------
function loadCache() {
  try {
    return JSON.parse(fs.readFileSync(CACHE_FILE, "utf8"));
  } catch {
    return {};
  }
}

function saveCache(cache) {
  fs.writeFileSync(CACHE_FILE, JSON.stringify(cache, null, 2), "utf8");
}

// ------------------------------------------------------------
// Load matchIds from 2026 fixtures (Rounds 0, 1, 2 only)
// ------------------------------------------------------------
function loadCompletedMatchIds() {
  const workbook = xlsx.readFile("assets/afl_fixtures_2026.xlsx");
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = xlsx.utils.sheet_to_json(sheet);

  const matchIds = [];

  for (const row of rows) {
    const round = Number(row.round ?? row.Round ?? -1);
    const complete = Boolean(row.complete ?? row.Complete ?? false);
    const matchId = row.matchId ?? row.MatchId ?? null;

    if (!matchId) continue;
    if (!complete) continue;
    if (![0, 1, 2].includes(round)) continue;

    matchIds.push(String(matchId).trim());
  }

  return matchIds;
}

// ------------------------------------------------------------
// Fetch stats from backend
// ------------------------------------------------------------
async function fetchStats(matchId) {
  const url = `${BACKEND}/fantasy/${matchId}`;
  const res = await fetch(url);

  if (!res.ok) {
    console.error(`❌ Failed for matchId=${matchId}: ${res.status}`);
    return null;
  }

  const json = await res.json();
  if (!json || !json.players) {
    console.error(`❌ Invalid response for matchId=${matchId}`);
    return null;
  }

  return json;
}

// ------------------------------------------------------------
// MAIN MIGRATION
// ------------------------------------------------------------
async function run() {
  console.log("📘 Loading existing cache...");
  const cache = loadCache();

  console.log("📗 Loading completed matchIds for 2026 Rounds 0–2...");
  const matchIds = loadCompletedMatchIds();

  console.log(`📌 Found ${matchIds.length} completed matches.`);

  let added = 0;

  for (const matchId of matchIds) {
    if (cache[matchId]) {
      console.log(`⏩ Already cached: ${matchId}`);
      continue;
    }

    console.log(`➡ Fetching stats for matchId=${matchId}...`);
    const stats = await fetchStats(matchId);

    if (!stats) {
      console.log(`❌ Skipped (no stats): ${matchId}`);
      continue;
    }

    cache[matchId] = stats;
    added++;
    console.log(`✅ Cached: ${matchId}`);
  }

  console.log("💾 Saving updated cache...");
  saveCache(cache);

  console.log(`🎉 Migration complete. Added ${added} new entries.`);
}

run();