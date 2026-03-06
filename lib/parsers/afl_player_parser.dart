import '../models/afl_player.dart';

class AflPlayerParser {
  static const Map<String, String> _clubMap = {
    // ADELAIDE
    "ADELAIDE": "ADE",
    "ADELAIDE CROWS": "ADE",

    // BRISBANE
    "BRISBANE": "BRL",
    "BRISBANE LIONS": "BRL",

    // CARLTON
    "CARLTON": "CAR",
    "CARLTON BLUES": "CAR",

    // COLLINGWOOD
    "COLLINGWOOD": "COL",
    "COLLINGWOOD MAGPIES": "COL",

    // ESSENDON
    "ESSENDON": "ESS",
    "ESSENDON BOMBERS": "ESS",

    // FREMANTLE
    "FREMANTLE": "FRE",
    "FREMANTLE DOCKERS": "FRE",

    // GEELONG
    "GEELONG": "GEE",
    "GEELONG CATS": "GEE",

    // GOLD COAST
    "GOLD COAST": "GCS",
    "GOLD COAST SUNS": "GCS",

    // GWS
    "GWS": "GWS",
    "GWS GIANTS": "GWS",
    "GREATER WESTERN SYDNEY": "GWS",
    "GREATER WESTERN SYDNEY GIANTS": "GWS",

    // HAWTHORN
    "HAWTHORN": "HAW",
    "HAWTHORN HAWKS": "HAW",

    // MELBOURNE
    "MELBOURNE": "MELB",
    "MELBOURNE DEMONS": "MELB",

    // NORTH MELBOURNE
    "NORTH MELBOURNE": "NTH",
    "NORTH MELBOURNE KANGAROOS": "NTH",

    // PORT ADELAIDE
    "PORT ADELAIDE": "PTA",
    "PORT ADELAIDE POWER": "PTA",

    // RICHMOND
    "RICHMOND": "RIC",
    "RICHMOND TIGERS": "RIC",

    // ST KILDA
    "ST KILDA": "STK",
    "ST KILDA SAINTS": "STK",

    // SYDNEY
    "SYDNEY": "SYD",
    "SYDNEY SWANS": "SYD",

    // WEST COAST
    "WEST COAST": "WCE",
    "WEST COAST EAGLES": "WCE",

    // WESTERN BULLDOGS
    "WESTERN BULLDOGS": "WBD",
    "BULLDOGS": "WBD",
  };

  static List<AflPlayer> parse(dynamic json) {
    if (json is! List) return [];

    return json.map<AflPlayer>((raw) {
      final map = raw as Map<String, dynamic>;

      // DFS: teamAbbr, static: club
      final rawClub = (map['club'] ?? map['teamAbbr'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final normalizedClub = _clubMap[rawClub] ?? rawClub;

      // DFS: playerId, static: id
      final id = (map['playerId'] ?? map['id'] ?? '')
          .toString()
          .trim();

      // DFS: playerName, static: name, AFL.com: fullName
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