import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_player.dart';
import '../utils/afl_club_codes.dart';

class PlayerRepository {
  final Map<int, List<AflPlayer>> _playersBySeason = {};
  final Map<String, AflPlayer> _playersById = {};

  // ------------------------------------------------------------
  // LOAD SEASON (ONLY loads the requested season)
  // ------------------------------------------------------------
  Future<List<AflPlayer>> loadSeason(int season) async {
    // Already loaded
    if (_playersBySeason.containsKey(season)) {
      return _playersBySeason[season]!;
    }

    return _fetchSeason(season);
  }

  // ------------------------------------------------------------
  // FORCE RELOAD (bypasses the in-memory cache, re-reads the asset)
  // ------------------------------------------------------------
  Future<List<AflPlayer>> reloadSeason(int season) async {
    return _fetchSeason(season);
  }

  Future<List<AflPlayer>> _fetchSeason(int season) async {
    final path = 'assets/data/players_$season.json';
    print("🔥 Loading $path");

    String jsonString;

    try {
      jsonString = await rootBundle.loadString(path);
      print("✅ Loaded $path");
    } catch (e) {
      print("❌ FAILED to load $path → $e");
      _playersBySeason[season] = <AflPlayer>[]; // prevent null map entries
      return <AflPlayer>[];
    }

    // Safe JSON decode
    dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } catch (e) {
      print("❌ JSON decode failed for $path → $e");
      _playersBySeason[season] = <AflPlayer>[];
      return <AflPlayer>[];
    }

    if (decoded is! Map<String, dynamic>) {
      print("❌ Invalid JSON structure in $path");
      _playersBySeason[season] = <AflPlayer>[];
      return <AflPlayer>[];
    }

    final rawPlayers = decoded['players'];
    if (rawPlayers is! List) {
      print("❌ 'players' field missing or invalid in $path");
      _playersBySeason[season] = <AflPlayer>[];
      return <AflPlayer>[];
    }

    final List<AflPlayer> players = [];

    for (final raw in rawPlayers) {
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);

      final seasonValue = _asInt(map['season']);
      final rawClub = (map['club'] ?? '').toString();
      final normalizedClub = AflClubCodes.normalize(rawClub);

      final id = (map['id'] ?? '').toString().trim();
      final name = (map['name'] ?? '').toString().trim();

      if (id.isEmpty || name.isEmpty) {
        // Skip corrupted entries
        continue;
      }

      players.add(
        AflPlayer(
          id: id,
          name: name,
          club: normalizedClub,
          guernseyNumber: _asInt(map['guernseyNumber'] ?? map['number']),
          season: seasonValue == 0 ? season : seasonValue,
        ),
      );
    }

    // Store ONLY for this season
    _playersBySeason[season] = players;

    // Build ID map ONLY for this season
    for (final p in players) {
      _playersById[p.id] = p;
    }

    return players;
  }

  // ------------------------------------------------------------
  // LOAD ALL PLAYERS (2025 + 2026)
  // ------------------------------------------------------------
  Future<void> loadAllPlayers() async {
    await loadSeason(2025);
    await loadSeason(2026);
  }

  // ------------------------------------------------------------
  // GETTERS — NO MERGING
  // ------------------------------------------------------------
  Future<List<AflPlayer>> playersForSeason(int season) async {
    return await loadSeason(season);
  }

  AflPlayer? getById(String id, int season) {
    final seasonPlayers = _playersBySeason[season];
    if (seasonPlayers == null) return null;

    for (final p in seasonPlayers) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ------------------------------------------------------------
  // UTIL
  // ------------------------------------------------------------
  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }
}