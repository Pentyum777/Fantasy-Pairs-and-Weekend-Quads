import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Maps AFL.com team names → your fixture club codes.
const clubMap = {
  "Carlton": "CARL",
  "Collingwood": "COLL",
  "Melbourne": "MELB",
  "Western Bulldogs": "WB",
  "GWS Giants": "GWS GIANTS",
  "Brisbane Lions": "BRI",
  "Richmond": "RICH",
  "Geelong Cats": "GEE",
  "Gold Coast Suns": "GCS",
  "Adelaide Crows": "ADE",
  "Essendon": "ESS",
  "Fremantle": "FRE",
  "Hawthorn": "HAW",
  "North Melbourne": "NTH",
  "Port Adelaide": "PTA",
  "St Kilda": "STK",
  "Sydney Swans": "SYD",
  "West Coast Eagles": "WCE",
};

/// All 18 AFL clubs as used by the team-lists API.
const aflTeams = [
  "ADE",
  "BRI",
  "CARL",
  "COLL",
  "ESS",
  "FRE",
  "GEE",
  "GCS",
  "GWS",
  "HAW",
  "MELB",
  "NTH",
  "PTA",
  "RICH",
  "STK",
  "SYD",
  "WB",
  "WCE",
];

Future<void> main() async {
  print("Fetching AFL team lists for 2026…");

  final players = <String, Map<String, dynamic>>{};

  for (final team in aflTeams) {
    final url = "https://api.afl.com.au/cfs/afl/clubTeamLists/$team";

    print("Fetching team list for $team");

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print("Failed to fetch $team (HTTP ${response.statusCode})");
      continue;
    }

    final data = jsonDecode(response.body);

    if (data["teamLists"] == null) {
      print("No teamLists found for $team");
      continue;
    }

    final lists = data["teamLists"] as List;

    for (final entry in lists) {
      final playersList = entry["players"] as List;

      for (final p in playersList) {
        final id = p["playerId"]?.toString() ?? "";
        final name = p["playerName"]?.toString() ?? "";
        final clubRaw = p["teamName"]?.toString() ?? "";
        final number = _asInt(p["jumperNumber"]);

        final club = clubMap[clubRaw] ?? clubRaw;

        players[id] = {
          "id": id,
          "name": name,
          "club": club,
          "number": number,
          "season": 2026,
        };
      }
    }
  }

  final outputList = players.values.toList();

  final outFile = File('assets/afl_players_2026.json');
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(outputList),
  );

  print("Done! Extracted ${outputList.length} unique players.");
}

int _asInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? "") ?? 0;
}