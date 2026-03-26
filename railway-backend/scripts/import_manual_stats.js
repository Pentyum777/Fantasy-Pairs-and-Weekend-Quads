// scripts/import_manual_stats.js

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import pkg from "pg";

dotenv.config(); // ⭐ Load .env automatically

const { Pool } = pkg;

// -----------------------------
// Validate DATABASE_URL
// -----------------------------
if (!process.env.DATABASE_URL) {
  console.error("❌ ERROR: DATABASE_URL is not set in .env");
  console.error("   Create a .env file with:");
  console.error("   DATABASE_URL=postgresql://user:pass@host:port/db?sslmode=require");
  process.exit(1);
}

// -----------------------------
// Connect to Postgres
// -----------------------------
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

// -----------------------------
// Paths
// -----------------------------
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const manualDir = path.join(__dirname, "..", "manual_stats");

// -----------------------------
// Convert DFS JSON → backend payload
// -----------------------------
function convertToPayload(json) {
  const home = json.home || [];
  const away = json.away || [];

  const players = [...home, ...away].map((p) => ({
    playerId: p.playerId,
    playerName: p.playerName,
    teamAbbr: p.teamAbbr || p.team || "",
    kicks: Number(p.kicks ?? 0),
    handballs: Number(p.handballs ?? 0),
    disposals: Number(p.kicks ?? 0) + Number(p.handballs ?? 0),
    marks: Number(p.marks ?? 0),
    tackles: Number(p.tackles ?? 0),
    goals: Number(p.goals ?? 0),
    behinds: Number(p.behinds ?? 0),
    hitouts: Number(p.hitouts ?? 0),
    freesFor: Number(p.freesFor ?? 0),
    freesAgainst: Number(p.freesAgainst ?? 0),
    fantasyPoints: Number(p.dreamTeamPoints ?? p.fantasyPoints ?? 0),
    af: Number(p.dreamTeamPoints ?? p.fantasyPoints ?? 0),
  }));

  return {
    homeScore: Number(json.homeTeam?.[0]?.teamScore ?? 0),
    awayScore: Number(json.awayTeam?.[0]?.teamScore ?? 0),
    quarter: "Final",
    clock: "FT",
    status: "Full Time",
    players,
  };
}

// -----------------------------
// Save to Postgres
// -----------------------------
async function saveCachedStats(matchId, payload) {
  await pool.query(
    `
    INSERT INTO stats_cache (match_id, payload, updated_at)
    VALUES ($1, $2, NOW())
    ON CONFLICT (match_id)
    DO UPDATE SET payload = EXCLUDED.payload, updated_at = NOW()
    `,
    [matchId, payload]
  );
}

// -----------------------------
// Main importer
// -----------------------------
async function run() {
  console.log("🔌 Testing Postgres connection...");

  try {
    await pool.query("SELECT NOW()");
    console.log("✅ Connected to Postgres");
  } catch (err) {
    console.error("❌ Failed to connect to Postgres:", err.message);
    process.exit(1);
  }

  console.log("📁 Reading manual_stats folder...");

  if (!fs.existsSync(manualDir)) {
    console.error(`❌ Folder not found: ${manualDir}`);
    process.exit(1);
  }

  const files = fs.readdirSync(manualDir).filter((f) => f.endsWith(".json"));

  if (files.length === 0) {
    console.error("❌ No JSON files found in manual_stats/");
    process.exit(1);
  }

  for (const file of files) {
    const fullPath = path.join(manualDir, file);
    const raw = JSON.parse(fs.readFileSync(fullPath, "utf8"));

    const matchId = raw.homeTeam?.[0]?.matchId;
    if (!matchId) {
      console.log(`⚠️ Skipping ${file} — no matchId found`);
      continue;
    }

    const payload = convertToPayload(raw);

    if (!payload.players || payload.players.length === 0) {
      console.log(`⚠️ ${matchId}: No players found — skipping`);
      continue;
    }

    await saveCachedStats(matchId, payload);
    console.log(`✅ Imported ${matchId} (${payload.players.length} players)`);
  }

  console.log("🎉 Import complete");
  process.exit(0);
}

run().catch((err) => {
  console.error("💥 Import failed:", err);
  process.exit(1);
});