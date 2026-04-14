/**
 * fix_updated_at_column.js
 * 
 * Fixes the updated_at column type from DATE to TIMESTAMP WITH TIME ZONE
 * so that sync polling can detect changes within the same day.
 * 
 * Run once:
 *   DATABASE_URL=postgres://... node fix_updated_at_column.js
 */

import pg from "pg";
const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function fix() {
  const client = await pool.connect();
  try {
    // Check current column type
    const check = await client.query(`
      SELECT column_name, data_type, udt_name
      FROM information_schema.columns
      WHERE table_name = 'selections' AND column_name = 'updated_at'
    `);
    
    console.log("Current updated_at column:", check.rows[0]);
    
    const currentType = check.rows[0]?.data_type;
    
    if (currentType === 'date') {
      console.log("⚠️  Column is DATE type — converting to TIMESTAMP WITH TIME ZONE...");
      
      await client.query(`
        ALTER TABLE selections 
        ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE
        USING updated_at::TIMESTAMP WITH TIME ZONE
      `);
      
      // Also set a default so it auto-updates
      await client.query(`
        ALTER TABLE selections 
        ALTER COLUMN updated_at SET DEFAULT NOW()
      `);
      
      // Update all existing rows to have a real timestamp (use noon today)
      await client.query(`
        UPDATE selections 
        SET updated_at = NOW() 
        WHERE updated_at IS NOT NULL
      `);
      
      console.log("✅ Column converted successfully");
    } else if (currentType?.includes('timestamp')) {
      console.log("✅ Column is already TIMESTAMP type — no change needed");
      console.log("   The issue may be elsewhere");
    } else {
      console.log(`❓ Unexpected column type: ${currentType}`);
      
      // Try the alter anyway
      console.log("Attempting conversion...");
      await client.query(`
        ALTER TABLE selections 
        ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE
        USING NOW()
      `);
      await client.query(`
        UPDATE selections SET updated_at = NOW()
      `);
      console.log("✅ Done");
    }
    
    // Verify
    const verify = await client.query(`
      SELECT column_name, data_type FROM information_schema.columns
      WHERE table_name = 'selections' AND column_name = 'updated_at'
    `);
    console.log("\nVerified column type:", verify.rows[0]);
    
    // Show sample timestamps
    const sample = await client.query(`
      SELECT season, game_type, round, updated_at FROM selections LIMIT 5
    `);
    console.log("\nSample rows:");
    sample.rows.forEach(r => {
      console.log(`  ${r.season} ${r.game_type} R${r.round}: ${r.updated_at}`);
    });
    
  } finally {
    client.release();
    await pool.end();
  }
}

fix().catch(err => { console.error(err); process.exit(1); });
