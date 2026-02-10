import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

const clubCodeMap = {
  "Adelaide Crows": "ADE",
  "Brisbane Lions": "BRI",
  "Carlton": "CARL",
  "Collingwood": "COLL",
  "Essendon": "ESS",
  "Fremantle": "FRE",
  "Geelong Cats": "GEE",
  "Gold Coast Suns": "GCS",
  "GWS Giants": "GWS",
  "Hawthorn": "HAW",
  "Melbourne": "MELB",
  "North Melbourne": "NTH",
  "Port Adelaide": "PTA",
  "Richmond": "RICH",
  "St Kilda": "STK",
  "Sydney Swans": "SYD",
  "West Coast Eagles": "WCE",
  "Western Bulldogs": "WB",
};

Future<void> generateSeason(int season) async {
  final input = File('tools/afl_players_$season.csv');
  final csv = const CsvToListConverter().convert(await input.readAsString());

  final players = <Map<String, dynamic>>[];

  for (var i = 1; i < csv.length; i++) {
    final row = csv[i];

    final id = row[0].toString().trim();
    final name = row[1].toString().trim();
    final clubFull = row[2].toString().trim();
    final guernsey = int.tryParse(row[3].toString()) ?? 0;
    final seasonValue = int.tryParse(row[4].toString()) ?? season;

    final clubCode = clubCodeMap[clubFull] ?? "";

    players.add({
      "id": id,
      "name": name,
      "club": clubCode,
      "guernseyNumber": guernsey,
      "season": seasonValue,
    });
  }

  players.sort((a, b) => a["name"].compareTo(b["name"]));

  final output = File('assets/data/players_$season.json');
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({"players": players}),
  );

  print("✅ Generated players_$season.json with ${players.length} players");
}

Future<void> main() async {
  await generateSeason(2025);
  await generateSeason(2026);
  print("🎉 All player files generated.");
}