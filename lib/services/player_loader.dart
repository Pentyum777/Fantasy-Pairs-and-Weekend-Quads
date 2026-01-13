import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/afl_player.dart';

class PlayerLoader {
  static const Map<String, String> _clubCodeMap = {
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

  static Future<List<AflPlayer>> loadPlayers2026() async {
    final raw = await rootBundle.loadString('assets/afl_players_2026.json');

    // The file is actually TSV, not JSON.
    final lines = const LineSplitter().convert(raw);

    final List<AflPlayer> players = [];

    // Skip header row
    for (final line in lines.skip(1)) {
      final row = line.split('\t');
      if (row.length < 4) continue;

      final fullName = row[0].trim();
      final clubFull = row[1].trim();
      final numberStr = row[2].trim();
      final seasonStr = row[3].trim();

      final clubCode = _clubCodeMap[clubFull] ?? "";
      final guernsey = int.tryParse(numberStr) ?? 0;
      final season = int.tryParse(seasonStr) ?? 2026;

      players.add(
        AflPlayer(
          id: fullName,
          name: fullName,
          club: clubCode,
          guernseyNumber: guernsey,
          season: season,
        ),
      );
    }

    // Sort by shortName (first + last)
    players.sort(
      (a, b) => a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
    );

    return players;
  }
}