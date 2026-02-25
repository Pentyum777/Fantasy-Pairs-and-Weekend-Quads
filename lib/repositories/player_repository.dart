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
    if (_playersBySeason.containsKey(season)) {
      return _playersBySeason[season]!;
    }

    final path = 'assets/data/players_$season.json';
    print("🔥 Loading $path");

    String jsonString;
    try {
      jsonString = await rootBundle.loadString(path);
      print("✅ Loaded $path");
    } catch (e) {
      print("❌ FAILED to load $path → $e");
      return [];
    }

    final data = json.decode(jsonString);
    if (data is! Map<String, dynamic>) return [];
    if (data['players'] is! List) return [];

    final rawPlayers = data['players'] as List<dynamic>;

    final players = rawPlayers.map((p) {
      final map = Map<String, dynamic>.from(p as Map);

      final seasonValue = _asInt(map['season']);
      final rawClub = (map['club'] ?? '').toString();
      final normalizedClub = AflClubCodes.normalize(rawClub);

      return AflPlayer(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        club: normalizedClub,
        guernseyNumber: _asInt(map['guernseyNumber']),
        season: seasonValue == 0 ? season : seasonValue,
      );
    }).toList();

    // Store ONLY for this season
    _playersBySeason[season] = players;

    // Build ID map ONLY for this season
    for (final p in players) {
      _playersById[p.id] = p;
    }

    return players;
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

    // ⭐ FIXED: firstWhere cannot return null — replaced with safe loop
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