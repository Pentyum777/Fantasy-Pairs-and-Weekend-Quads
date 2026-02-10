import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_player.dart';
import '../utils/afl_club_codes.dart'; // <-- ensure this exists

class PlayerRepository {
  final Map<int, List<AflPlayer>> _playersBySeason = {};
  final Map<String, AflPlayer> _playersById = {};

  bool _loaded = false;

  Future<List<AflPlayer>> _loadSeason(int season) async {
    if (_playersBySeason.containsKey(season)) {
      return _playersBySeason[season]!;
    }

    final path = 'assets/data/players_$season.json';
    final jsonString = await rootBundle.loadString(path);
    final data = json.decode(jsonString);

    if (data is! Map<String, dynamic>) return [];
    if (data['players'] is! List) return [];

    final rawPlayers = data['players'] as List<dynamic>;

    final players = rawPlayers.map((p) {
      final map = Map<String, dynamic>.from(p as Map);

      final seasonValue = _asInt(map['season']);

      // NORMALIZE CLUB NAME HERE
      final rawClub = (map['club'] ?? '').toString();
      final normalizedClub = AflClubCodes.normalize(rawClub);

      return AflPlayer(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        club: normalizedClub, // <-- FIXED
        guernseyNumber: _asInt(map['guernseyNumber']),
        season: seasonValue == 0 ? season : seasonValue,
      );
    }).toList();

    _playersBySeason[season] = players;

    for (final p in players) {
      _playersById[p.id] = p;
    }

    return players;
  }

  Future<void> loadAllPlayers() async {
    if (_loaded) return;

    await _loadSeason(2025);
    await _loadSeason(2026);

    _loaded = true;
  }

  List<AflPlayer> get players {
    return _playersBySeason.values.expand((x) => x).toList();
  }

  Future<List<AflPlayer>> playersForSeason(int season) async {
    await loadAllPlayers();
    return _playersBySeason[season] ?? [];
  }

  AflPlayer? getById(String id) {
    return _playersById[id];
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }
}