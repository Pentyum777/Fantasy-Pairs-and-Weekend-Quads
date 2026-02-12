import fs from "fs";
import csv from "csv-parser";

function extractFootyId(url) {
  if (!url) return null;
  const match = url.match(/(\d+)$/);
  return match ? match[1] : null;
}

async function processCsv(file, output) {
  return new Promise((resolve) => {
    fs.createReadStream(file)
      .pipe(csv())
      .on("data", (row) => {
        const matchId = row["Match ID"];
        const url = row["Footy Info"];

        if (!matchId || !url) return;

        const id = extractFootyId(url);
        if (id) {
          output[matchId] = id;
          console.log(`✔ ${matchId} → ${id}`);
        } else {
          console.log(`❌ No ID found in URL for ${matchId}`);
        }
      })
      .on("end", resolve);
  });
}

async function run() {
  const output = {};

  console.log("Processing 2025 Round 24...");
  await processCsv("./afl_fixtures_2025_round_24.csv", output);

  console.log("Processing 2026 season...");
  await processCsv("./afl_fixtures_2026.csv", output);

  fs.writeFileSync("./footyinfo_map.json", JSON.stringify(output, null, 2));
  console.log("\n🎉 DONE — Generated", Object.keys(output).length, "entries");
}

run();