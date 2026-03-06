import '../models/afl_player.dart';

class AflPlayerParser {
  static const Map<String, String> _clubMap = {
    "Adelaide Crows": "ADE",
    "Adelaide": "ADE",
    "Brisbane Lions": "BRI",
    "Brisbane": "BRI",
    "Carlton Blues": "CARL",
    "Carlton": "CARL",
    "Collingwood Magpies": "COLL",
    "Collingwood": "COLL",
    "Essendon Bombers": "ESS",
    "Essendon": "ESS",
    "Fremantle Dockers": "FRE",
    "Fremantle": "FRE",
    "Geelong Cats": "GEE",
    "Geelong": "GEE",
    "Gold Coast Suns": "GCS",
    "Gold Coast": "GCS",
    "Greater Western Sydney Giants": "GWS GIANTS",
    "GWS Giants": "GWS GIANTS",
    "GWS": "GWS GIANTS",
    "Hawthorn Hawks": "HAW",
    "Hawthorn": "HAW",
    "Melbourne Demons": "MELB",
    "Melbourne": "MELB",
    "North Melbourne Kangaroos": "NTH",
    "North Melbourne": "NTH",
    "Port Adelaide Power": "PTA",
    "Port Adelaide": "PTA",
    "Richmond Tigers": "RICH",
    "Richmond": "RICH",
    "St Kilda Saints": "STK",
    "St Kilda": "STK",
    "Sydney Swans": "SYD",
    "Sydney": "SYD",
    "West Coast Eagles": "WCE",
    "West Coast": "WCE",
    "Western Bulldogs": "WB",
    "Bulldogs": "WB",
  };

  static List<AflPlayer> parse(dynamic json) {
    if (json is! List) return [];

    return json.map<AflPlayer>((raw) {
      final map = raw as Map<String, dynamic>;

      // Support DFS + CSV + AFL.com
      final rawClub = (map['club'] ?? map['teamAbbr'] ?? '').toString().trim();
      final normalizedClub = _clubMap[rawClub] ?? rawClub;

      final id = (map['playerId'] ?? map['id'] ?? '').toString().trim();

      final name = (map['playerName'] ??
              map['name'] ??
              map['fullName'] ??
              '')
          .toString()
          .trim();

      final guernsey = map['number'] is int
          ? map['number'] as int
          : int.tryParse((map['number'] ?? '').toString()) ?? 0;

      final season = map['season'] is int
          ? map['season'] as int
          : int.tryParse((map['season'] ?? '').toString()) ?? 2026;

      return AflPlayer(
        id: id,
        name: name,
        club: normalizedClub,
        guernseyNumber: guernsey,
        season: season,
        fantasyScore: 0,
      );
    }).toList();
  }
}