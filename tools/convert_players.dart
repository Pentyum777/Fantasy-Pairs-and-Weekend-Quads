import 'dart:convert';
import 'dart:io';

/// Converts afl_players_2026.csv (full club names) into afl_players_2026.json
/// with club codes and normalised fields.
void main() async {
  final input = File('afl_players_2026.csv');
  final lines = await input.readAsLines();

  if (lines.isEmpty) {
    print("ERROR: CSV file is empty.");
    return;
  }

  // Full club name → AFL club code
  const clubCodeMap = {
    "Adelaide Crows": "ADE",
    "Brisbane": "BRI",
    "Carlton": "CARL",
    "Collingwood": "COLL",
    "Essendon": "ESS",
    "Fremantle": "FRE",
    "Geelong": "GEE",
    "Gold Coast Suns": "GC",
    "Greater Western Sydney": "GWS",
    "Hawthorn": "HAW",
    "Melbourne": "MELB",
    "North Melbourne": "NM",
    "Port Adelaide": "PORT",
    "Richmond": "RICH",
    "St Kilda": "STK",
    "Sydney Swans": "SYD",
    "West Coast Eagles": "WCE",
    "Western Bulldogs": "WB",
  };

  // Skip header row
  final List<Map<String, dynamic>> players = [];

  for (var i = 1; i < lines.length; i++) {
    final row = lines[i].split(',');

    if (row.length < 4) {
      print("Skipping malformed row $i: ${lines[i]}");
      continue;
    }

    final fullName = row[0].trim();
    final clubFull = row[1].trim();
    final numberStr = row[2].trim();
    final seasonStr = row[3].trim();

    final clubCode = clubCodeMap[clubFull] ?? "";
    final guernsey = int.tryParse(numberStr) ?? 0;
    final season = int.tryParse(seasonStr) ?? 2026;

    players.add({
      "id": fullName,
      "name": fullName,
      "club": clubCode,
      "guernseyNumber": guernsey,
      "season": season,
    });
  }

  final output = File('afl_players_2026.json');
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(players),
  );

  print("Done! Created afl_players_2026.json with ${players.length} players.");
}