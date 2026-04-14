import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class PlayerSeasonStats {
  final String playerId;
  final String playerName;
  final String team;
  final int games;
  final int afAvg;
  final int afBest;
  final int kAvg;
  final int hbAvg;
  final int dAvg;
  final int mAvg;
  final int tAvg;
  final double gAvg;
  final int togAvg;

  const PlayerSeasonStats({
    required this.playerId,
    required this.playerName,
    required this.team,
    required this.games,
    required this.afAvg,
    required this.afBest,
    required this.kAvg,
    required this.hbAvg,
    required this.dAvg,
    required this.mAvg,
    required this.tAvg,
    required this.gAvg,
    required this.togAvg,
  });

  factory PlayerSeasonStats.fromJson(Map<String, dynamic> j) {
    return PlayerSeasonStats(
      playerId:   j['player_id']   as String? ?? '',
      playerName: j['player_name'] as String? ?? '',
      team:       j['team']        as String? ?? '',
      games:      (j['games']   as num?)?.toInt() ?? 0,
      afAvg:      (j['af_avg']  as num?)?.toInt() ?? 0,
      afBest:     (j['af_best'] as num?)?.toInt() ?? 0,
      kAvg:       (j['k_avg']   as num?)?.toInt() ?? 0,
      hbAvg:      (j['hb_avg']  as num?)?.toInt() ?? 0,
      dAvg:       (j['d_avg']   as num?)?.toInt() ?? 0,
      mAvg:       (j['m_avg']   as num?)?.toInt() ?? 0,
      tAvg:       (j['t_avg']   as num?)?.toInt() ?? 0,
      gAvg:       (j['g_avg']   as num?)?.toDouble() ?? 0.0,
      togAvg:     (j['tog_avg'] as num?)?.toInt() ?? 0,
    );
  }
}

enum PlayerFlag { inj, susp, rest, out }

extension PlayerFlagExt on PlayerFlag {
  String get label {
    switch (this) {
      case PlayerFlag.inj:  return 'INJ';
      case PlayerFlag.susp: return 'SUSP';
      case PlayerFlag.rest: return 'REST';
      case PlayerFlag.out:  return 'OUT';
    }
  }

  Color get colour {
    switch (this) {
      case PlayerFlag.inj:  return const Color(0xFFE53935); // red
      case PlayerFlag.susp: return const Color(0xFFFB8C00); // orange
      case PlayerFlag.rest: return const Color(0xFF1E88E5); // blue
      case PlayerFlag.out:  return const Color(0xFF757575); // grey
    }
  }

  static PlayerFlag? fromString(String s) {
    switch (s.toUpperCase()) {
      case 'INJ':  return PlayerFlag.inj;
      case 'SUSP': return PlayerFlag.susp;
      case 'REST': return PlayerFlag.rest;
      case 'OUT':  return PlayerFlag.out;
    }
    return null;
  }
}

class PlayerFlagEntry {
  final String playerId;
  final PlayerFlag flag;
  final String note;

  const PlayerFlagEntry({
    required this.playerId,
    required this.flag,
    this.note = '',
  });
}

// ---------------------------------------------------------------------------
// ScoutService
// ---------------------------------------------------------------------------

class ScoutService {
  // ── Access control ────────────────────────────────────────────────────────

  /// Checks the backend allowlist to see if [email] can access Scout.
  Future<bool> checkAccess(String email) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/scoutAccess',
        {'email': email},
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body);
      return json['allowed'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Season stats ──────────────────────────────────────────────────────────

  Future<List<PlayerSeasonStats>> fetchSeasonStats(int season) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/playerSeasonStats/$season',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final list = json['players'] as List<dynamic>? ?? [];
      return list
          .map((e) => PlayerSeasonStats.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('fetchSeasonStats error: $e');
      return [];
    }
  }

  // ── Named squad ───────────────────────────────────────────────────────────

  /// Returns the set of named player IDs for a match.
  /// Empty set means teams haven't been announced yet.
  Future<Set<String>> fetchNamedSquad(String matchId) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/namedSquad/$matchId',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return {};
      final json = jsonDecode(res.body);
      if (json['available'] != true) return {};
      final named = json['named'] as List<dynamic>? ?? [];
      return named.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Player flags ──────────────────────────────────────────────────────────

  Future<Map<String, PlayerFlagEntry>> fetchFlags(int season) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/playerFlags/$season',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return {};
      final json = jsonDecode(res.body);
      final flags = json['flags'] as List<dynamic>? ?? [];
      final map = <String, PlayerFlagEntry>{};
      for (final f in flags) {
        final pid  = f['player_id'] as String? ?? '';
        final flag = PlayerFlagExt.fromString(f['flag'] as String? ?? '');
        if (pid.isNotEmpty && flag != null) {
          map[pid] = PlayerFlagEntry(
            playerId: pid,
            flag: flag,
            note: f['note'] as String? ?? '',
          );
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> setFlag({
    required int season,
    required String playerId,
    required String playerName,
    required String team,
    required PlayerFlag flag,
    String note = '',
  }) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/playerFlags',
      );
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'season':     season,
          'playerId':   playerId,
          'playerName': playerName,
          'team':       team,
          'flag':       flag.label,
          'note':       note,
        }),
      );
    } catch (_) {}
  }

  Future<void> clearFlag({
    required int season,
    required String playerId,
  }) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/playerFlags/$season/$playerId',
      );
      await http.delete(url);
    } catch (_) {}
  }
}