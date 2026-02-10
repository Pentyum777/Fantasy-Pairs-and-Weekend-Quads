import '../models/afl_player.dart';

class AflPlayerParser {
  /// Normalises ALL known club name variants (CSV, JSON, AFL.com, marketing names)
  /// into the EXACT codes used by your fixture files.
  static const Map<String, String> _clubMap = {
    // ADELAIDE
    "Adelaide Crows": "ADE",
    "Adelaide": "ADE",

    // BRISBANE
    "Brisbane Lions": "BRI",
    "Brisbane": "BRI",

    // CARLTON
    "Carlton Blues": "CARL",
    "Carlton": "CARL",

    // COLLINGWOOD
    "Collingwood Magpies": "COLL",
    "Collingwood": "COLL",

    // ESSENDON
    "Essendon Bombers": "ESS",
    "Essendon": "ESS",

    // FREMANTLE
    "Fremantle Dockers": "FRE",
    "Fremantle": "FRE",

    // GEELONG
    "Geelong Cats": "GEE",
    "Geelong": "GEE",

    // GOLD COAST
    "Gold Coast Suns": "GCS",
    "Gold Coast": "GCS",

    // GWS
    "Greater Western Sydney Giants": "GWS GIANTS",
    "GWS Giants": "GWS GIANTS",
    "GWS": "GWS GIANTS",

    // HAWTHORN
    "Hawthorn Hawks": "HAW",
    "Hawthorn": "HAW",

    // MELBOURNE
    "Melbourne Demons": "MELB",
    "Melbourne": "MELB",

    // NORTH MELBOURNE
    "North Melbourne Kangaroos": "NTH",
    "North Melbourne": "NTH",

    // PORT ADELAIDE
    "Port Adelaide Power": "PTA",
    "Port Adelaide": "PTA",

    // RICHMOND
    "Richmond Tigers": "RICH",
    "Richmond": "RICH",

    // ST KILDA
    "St Kilda Saints": "STK",
    "St Kilda": "STK",

    // SYDNEY
    "Sydney Swans": "SYD",
    "Sydney": "SYD",

    // WEST COAST
    "West Coast Eagles": "WCE",
    "West Coast": "WCE",

    // WESTERN BULLDOGS
    "Western Bulldogs": "WB",
    "Bulldogs": "WB",
  };

  static List<AflPlayer> parse(dynamic json) {
    if (json is! List) return [];

    return json.map<AflPlayer>((raw) {
      final map = raw as Map<String, dynamic>;

      final rawClub = (map['club'] ?? '').toString().trim();
      final normalizedClub = _clubMap[rawClub] ?? rawClub;

      return AflPlayer(
  id: (map['id'] ?? '').toString(),

  name: (map['name'] ?? map['fullName'])?.toString() ?? '',

  club: normalizedClub,

  guernseyNumber: map['number'] is int
      ? map['number'] as int
      : int.tryParse((map['number'] ?? '').toString()) ?? 0,

  season: map['season'] is int
      ? map['season'] as int
      : int.tryParse((map['season'] ?? '').toString()) ?? 2026,

  fantasyScore: 0,
);
    }).toList();
  }
}