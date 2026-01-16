import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/afl_player.dart';

class PlayerRepository {
  final List<AflPlayer> _players = [];
  List<AflPlayer> get players => _players;

  // Base mapping: JSON full names → AFL club codes
  static const Map<String, String> _clubCodeMap = {
    "Adelaide Crows": "ADE",
    "Brisbane Lions": "BRL",
    "Brisbane": "BRL",
    "Carlton": "CAR",
    "Collingwood": "COL",
    "Essendon": "ESS",
    "Fremantle": "FRE",
    "Geelong Cats": "GEE",
    "Geelong": "GEE",
    "Gold Coast Suns": "GCS",
    "GWS Giants": "GWS",
    "Hawthorn": "HAW",
    "Melbourne": "MEL",
    "North Melbourne": "NTH",
    "Port Adelaide": "PTA",
    "Richmond": "RIC",
    "St Kilda": "STK",
    "Sydney Swans": "SYD",
    "West Coast Eagles": "WCE",
    "Western Bulldogs": "WBD",
  };

  // ------------------------------------------------------------
  // STATIC NORMALIZER (used by FixtureRepository)
  // ------------------------------------------------------------
  static String normalizeClubStatic(String raw) {
    final cleaned = raw.trim();

    if (_clubCodeMap.containsKey(cleaned)) {
      return _clubCodeMap[cleaned]!;
    }

    final noSpace = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_clubCodeMap.containsKey(noSpace)) {
      return _clubCodeMap[noSpace]!;
    }

    final stripped = cleaned
        .replaceAll(RegExp(r'Football Club', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bFC\b', caseSensitive: false), '')
        .trim();
    if (_clubCodeMap.containsKey(stripped)) {
      return _clubCodeMap[stripped]!;
    }

    final noParens = cleaned.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (_clubCodeMap.containsKey(noParens)) {
      return _clubCodeMap[noParens]!;
    }

    print("❗ UNMAPPED FIXTURE CLUB: '$cleaned'");
    return cleaned;
  }

  // ------------------------------------------------------------
  // INSTANCE NORMALIZER (used when loading players)
  // ------------------------------------------------------------
  String normalizeClub(String raw) {
    final cleaned = raw.trim();

    if (_clubCodeMap.containsKey(cleaned)) {
      return _clubCodeMap[cleaned]!;
    }

    final noSpace = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_clubCodeMap.containsKey(noSpace)) {
      return _clubCodeMap[noSpace]!;
    }

    final stripped = cleaned
        .replaceAll(RegExp(r'Football Club', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bFC\b', caseSensitive: false), '')
        .trim();
    if (_clubCodeMap.containsKey(stripped)) {
      return _clubCodeMap[stripped]!;
    }

    final noParens = cleaned.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (_clubCodeMap.containsKey(noParens)) {
      return _clubCodeMap[noParens]!;
    }

    print("❗ UNMAPPED CLUB (after normalization): '$cleaned'");
    return cleaned;
  }

  // ------------------------------------------------------------
  // LOAD PLAYERS FROM JSON
  // ------------------------------------------------------------
  Future<void> loadPlayers() async {
    print("LOADING JSON...");
    _players.clear();
    print("PLAYER REPO INSTANCE (loadPlayers): $this");

    final jsonString =
        await rootBundle.loadString('assets/afl_players_2026.json');

    print("JSON STRING LENGTH: ${jsonString.length}");

    final List<dynamic> data = json.decode(jsonString);

    print("RAW JSON ENTRY: ${data.isNotEmpty ? data.first : 'EMPTY'}");

    // AUTO-DETECT RAW CLUB NAMES
    final Set<String> rawClubNames = {};
    for (final p in data) {
      final raw = (p['club'] ?? '').toString().trim();
      rawClubNames.add(raw);
    }

    print("🔎 RAW CLUB NAMES FOUND IN JSON:");
    for (final c in rawClubNames) {
      print(" - '$c'");
    }

    // MAP PLAYERS
    _players.addAll(
      data.map((p) {
        final fullClubName = p['club'] ?? "";
        final clubCode = normalizeClub(fullClubName);

        return AflPlayer(
          id: p['id'],
          name: p['id'], // JSON has no "name", so use id
          club: clubCode,
          guernseyNumber: p['number'],
          season: p['season'],
        );
      }),
    );

    print("✔ Loaded ${_players.length} players");
  }
}