import 'dart:convert';
import 'dart:io';

void main() async {
  final input = File('afl_players_2025.csv');
  final lines = await input.readAsLines();

  if (lines.isEmpty) {
    print("ERROR: CSV file is empty.");
    return;
  }

  // Full club names only — PlayerRepository normalizes these later
  const validClubNames = {
    "Adelaide Crows",
    "Brisbane Lions",
    "Carlton",
    "Collingwood",
    "Essendon",
    "Fremantle",
    "Geelong Cats",
    "Gold Coast Suns",
    "GWS Giants",
    "Hawthorn",
    "Melbourne",
    "North Melbourne",
    "Port Adelaide",
    "Richmond",
    "St Kilda",
    "Sydney Swans",
    "West Coast Eagles",
    "Western Bulldogs",
  };

  final List<Map<String, dynamic>> players = [];

  for (var i = 1; i < lines.length; i++) {
    final row = lines[i].split(',');

    if (row.length < 3) {
      print("Skipping malformed row $i: ${lines[i]}");
      continue;
    }

    final fullName = row[0].trim();
    final clubFull = row[1].trim();
    final numberStr = row[2].trim();

    if (!validClubNames.contains(clubFull)) {
      print("WARNING: Unknown club '$clubFull' for player '$fullName'");
    }

    final guernsey = int.tryParse(numberStr) ?? 0;

    players.add({
      "id": fullName,
      "name": fullName,
      "club": clubFull,          // full club name (required)
      "guernseyNumber": guernsey,
      "season": 2025,
    });
  }

  final wrapped = {"players": players};

  final output = File('assets/data/players_2025.json');
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(wrapped),
  );

  print("Done! Created players_2025.json with ${players.length} players.");
}