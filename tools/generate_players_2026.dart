import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

void main() {
  final lines = File('tools/afl_players_2026.csv').readAsLinesSync();

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
    final raw = lines[i].trim();
    if (raw.isEmpty) continue;

    final parts = const CsvToListConverter()
        .convert(raw, shouldParseNumbers: false)
        .first
        .map((e) => e.toString().trim())
        .toList();

    if (parts.length < 5) continue;

    final name = parts[0];
    final clubFull = parts[1];
    final guernsey = int.tryParse(parts[2]) ?? 0;
    final season = int.tryParse(parts[3]) ?? 2026;
    final cdid = parts[4];

    final clubCode = clubCodeMap[clubFull] ?? "";

    if (name.isEmpty || cdid.isEmpty) continue;

    players.add({
      "id": cdid,
      "name": name,
      "club": clubCode,
      "guernseyNumber": guernsey,
      "season": season,
    });
  }

  players.sort((a, b) => a["name"].compareTo(b["name"]));

  File('assets/data/players_2026.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({"players": players}),
  );

  print("✅ Generated players_2026.json with ${players.length} players");
}