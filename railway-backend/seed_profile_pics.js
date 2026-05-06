/**
 * seed_profile_pics.js
 *
 * Creates the profile_pics table and uploads all images from the
 * "Punter Profile Pics" folder into the database.
 *
 * Image filenames should match punter names, e.g.:
 *   "John Smith.jpg" → punterName = "John Smith", safeName = "John_Smith"
 *
 * Usage:
 *   $env:DATABASE_URL="postgresql://postgres:eelkdWXpRAhaYOBAmzQgXzprYksdFFXY@maglev.proxy.rlwy.net:13592/railway"
 *   node seed_profile_pics.js
 */

import pg from "pg";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function run() {
  const client = await pool.connect();
  try {
    // Create table
    await client.query(`
      CREATE TABLE IF NOT EXISTS profile_pics (
        id SERIAL PRIMARY KEY,
        safe_name TEXT NOT NULL UNIQUE,
        punter_name TEXT NOT NULL,
        image_data TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log("✅ profile_pics table ready");

    // Find the pics folder — try a few common names
    const possibleDirs = [
      path.join(__dirname, "Punter Profile Pics"),
      path.join(__dirname, "Punter_Profile_Pics"),
      path.join(__dirname, "profile_pics"),
      path.join(__dirname, "punter_profile_pics"),
    ];

    let picsDir = null;
    for (const dir of possibleDirs) {
      if (fs.existsSync(dir)) {
        picsDir = dir;
        break;
      }
    }

    if (!picsDir) {
      console.log("⚠️  No profile pics folder found. Tried:", possibleDirs.map(d => path.basename(d)).join(", "));
      console.log("   Place your images in one of these folders and re-run.");
      return;
    }

    console.log(`📁 Reading from: ${picsDir}`);

    const files = fs.readdirSync(picsDir).filter(f =>
      /\.(jpg|jpeg|png|webp)$/i.test(f)
    );

    console.log(`📸 Found ${files.length} images`);

    let uploaded = 0;
    for (const file of files) {
      const ext = path.extname(file);
      const punterName = path.basename(file, ext); // "John Smith"
      const safeName = punterName
        .replace(/[^a-zA-Z0-9_\- ]/g, "")
        .replace(/\s+/g, "_");

      const filePath = path.join(picsDir, file);
      const imageBuffer = fs.readFileSync(filePath);
      const base64Data = imageBuffer.toString("base64");

      await client.query(
        `INSERT INTO profile_pics (safe_name, punter_name, image_data)
         VALUES ($1, $2, $3)
         ON CONFLICT (safe_name)
         DO UPDATE SET image_data = EXCLUDED.image_data, punter_name = EXCLUDED.punter_name, updated_at = NOW()`,
        [safeName, punterName, base64Data]
      );

      uploaded++;
      console.log(`  ✅ ${punterName} → ${safeName}`);
    }

    console.log(`\n✅ Done! ${uploaded} profile pics uploaded to database`);

    // Verify
    const check = await client.query(`SELECT COUNT(*) as cnt FROM profile_pics`);
    console.log(`  DB check: ${check.rows[0].cnt} pics stored`);

  } catch (err) {
    console.error("Error:", err.message);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(err => { console.error(err); process.exit(1); });
