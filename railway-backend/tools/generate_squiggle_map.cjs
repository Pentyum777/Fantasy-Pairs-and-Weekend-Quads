const fs = require("fs");
const path = require("path");

const inputFile = path.join(__dirname, "afl_fixtures_2026.csv");
const outputFile = path.join(__dirname, "squiggle_map.json");

// Read file and split lines safely (handles CRLF and LF)
const csv = fs.readFileSync(inputFile, "utf8").split(/\r?\n/);

// DEBUG: Show raw header exactly as Node sees it
console.log("RAW HEADER:", JSON.stringify(csv[0]));

// Clean + normalize header
const rawHeader = csv[0].replace(/^\uFEFF/, "");
const header = rawHeader
  .split(",")
  .map(h => h.replace(/\r/g, "").trim().toLowerCase());

// DEBUG: Show parsed header array
console.log("PARSED HEADER:", header);

// Find columns by normalized name
const matchIdIndex = header.indexOf("match id");
const squiggleIdIndex = header.indexOf("squiggle match id");

// Debug if missing
if (matchIdIndex === -1 || squiggleIdIndex === -1) {
  console.error("CSV missing required columns.");
  console.error("Header parsed as:", header);
  process.exit(1);
}

const map = {};

for (let i = 1; i < csv.length; i++) {
  if (!csv[i].trim()) continue;

  const row = csv[i].replace(/\r/g, "").split(",");

  const cdId = row[matchIdIndex]?.trim();
  const squiggleId = row[squiggleIdIndex]?.trim();

  if (!cdId || !squiggleId || squiggleId === "n/a") continue;

  map[cdId] = Number(squiggleId);
}

fs.writeFileSync(outputFile, JSON.stringify(map, null, 2));
console.log("Generated squiggle_map.json with", Object.keys(map).length, "entries.");