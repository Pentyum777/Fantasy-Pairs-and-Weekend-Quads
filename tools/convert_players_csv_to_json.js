const fs = require('fs');
const path = require('path');

// Use absolute paths for clarity
const baseDir = __dirname;
const input = path.join(baseDir, 'afl_players_2025.csv');
const output = path.join(baseDir, 'afl_players_2025.json');

function parseCSVLine(line) {
  // Split on tabs or commas
  return line.split(/\t|,/).map(p => p.trim());
}

const csv = fs.readFileSync(input, 'utf8').trim().split('\n');

// Extract header columns
const header = parseCSVLine(csv[0]);

// Expected columns:
// ID | Club | Number | Season | Champion Data ID
const idxName = header.indexOf('ID');
const idxClub = header.indexOf('Club');
const idxNumber = header.indexOf('Number');
const idxSeason = header.indexOf('Season');
const idxCDID = header.indexOf('Champion Data ID');

if (idxName === -1 || idxClub === -1 || idxNumber === -1 || idxSeason === -1 || idxCDID === -1) {
  throw new Error('❌ CSV header is missing one or more required columns.');
}

const json = {};

for (let i = 1; i < csv.length; i++) {
  const row = parseCSVLine(csv[i]);

  const name = row[idxName];
  const club = row[idxClub];
  const number = parseInt(row[idxNumber], 10);
  const season = parseInt(row[idxSeason], 10);
  const cdid = row[idxCDID];

  if (!cdid || !name) continue;

  json[cdid] = {
    name,
    club,
    number,
    season
  };
}

fs.writeFileSync(output, JSON.stringify(json, null, 2));

console.log(`🎯 Wrote ${output}`);