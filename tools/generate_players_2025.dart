import 'dart:convert';
import 'dart:io';

void main() {
  final lines = File('tools/afl_players_2025.csv').readAsLinesSync();

  const clubCodeMap = {
    "Adelaide Crows": "ADE",
    "Brisbane Lions": "BRL",
    "Carlton": "CAR",
    "Collingwood": "COL",
    "Essendon": "ESS",
    "Fremantle": "FRE",
    "Geelong Cats": "GEE",
    "Gold Coast Suns": "GCS",
    "GWS Giants": "GWS",
    "Hawthorn": "HAW",
    "Melbourne": "MELB",
    "North Melbourne": "NTH",
    "Port Adelaide": "PTA",
    "Richmond": "RIC",
    "St Kilda": "STK",
    "Sydney Swans": "SYD",
    "West Coast Eagles": "WCE",
    "Western Bulldogs": "WBD",
  };

  final players = <Map<String, dynamic>>[];

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final parts = line.split(',');

    if (parts.length < 5) continue;

    final name = parts[0].trim();
    final clubFull = parts[1].trim();
    final guernsey = int.tryParse(parts[2].trim()) ?? 0;
    final season = int.tryParse(parts[3].trim()) ?? 2025;
    final cdid = parts[4].trim();

    if (name.isEmpty || cdid.isEmpty) continue;

    final clubCode = clubCodeMap[clubFull] ?? "";

    players.add({
      "id": cdid,
      "name": name,
      "club": clubCode,          // ✔ canonical code
      "guernseyNumber": guernsey,
      "season": season,
    });
  }

  players.sort((a, b) => a["name"].compareTo(b["name"]));

  File('assets/data/players_2025.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({"players": players}),
  );

  print("✅ Generated players_2025.json with ${players.length} players");
}