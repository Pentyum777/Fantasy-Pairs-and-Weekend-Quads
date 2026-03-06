import '../models/afl_player.dart';

class AflPlayerParser {
  static const Map<String, String> _clubMap = {
    "ADELAIDE": "ADE",
    "ADELAIDE CROWS": "ADE",

    "BRISBANE": "BRL",
    "BRISBANE LIONS": "BRL",

    "CARLTON": "CAR",
    "CARLTON BLUES": "CAR",

    "COLLINGWOOD": "COL",
    "COLLINGWOOD MAGPIES": "COL",

    "ESSENDON": "ESS",
    "ESSENDON BOMBERS": "ESS",

    "FREMANTLE": "FRE",
    "FREMANTLE DOCKERS": "FRE",

    "GEELONG": "GEE",
    "GEELONG CATS": "GEE",

    "GOLD COAST": "GCS",
    "GOLD COAST SUNS": "GCS",

    "GWS": "GWS",
    "GWS GIANTS": "GWS",
    "GREATER WESTERN SYDNEY": "GWS",
    "GREATER WESTERN SYDNEY GIANTS": "GWS",

    "HAWTHORN": "HAW",
    "HAWTHORN HAWKS": "HAW",

    "MELBOURNE": "MELB",
    "MELBOURNE DEMONS": "MELB",

    "NORTH MELBOURNE": "NTH",
    "NORTH MELBOURNE KANGAROOS": "NTH",

    "PORT ADELAIDE": "PTA",
    "PORT ADELAIDE POWER": "PTA",

    "RICHMOND": "RIC",
    "RICHMOND TIGERS": "RIC",

    "ST KILDA": "STK",
    "ST KILDA SAINTS": "STK",

    "SYDNEY": "SYD",
    "SYDNEY SWANS": "SYD",

    "WEST COAST": "WCE",
    "WEST COAST EAGLES": "WCE",

    "WESTERN BULLDOGS": "WBD",
    "BULLDOGS": "WBD",
  };

  static List<AflPlayer> parse(dynamic json) {
    if (json is! List) return [];

    return json.map<AflPlayer>((raw) {
      final map = raw as Map<String, dynamic>;

      // DFS uses teamAbbr, CSV uses club
      final rawClub = (map['club'] ?? map['teamAbbr'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      final normalizedClub = _clubMap[rawClub] ?? rawClub;

      // DFS uses playerId, CSV uses id
      final id = (map['playerId'] ?? map['id'] ?? '')
          .toString()
          .trim();

      // DFS uses playerName, CSV uses name, AFL.com uses fullName
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