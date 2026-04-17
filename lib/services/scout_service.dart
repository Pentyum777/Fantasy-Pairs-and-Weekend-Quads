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
  final int lastGame;
  final int last3Avg;

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
    this.lastGame = 0,
    this.last3Avg = 0,
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
      lastGame:   (j['last_game'] as num?)?.toInt() ?? 0,
      last3Avg:   (j['last3_avg'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Game log entry ────────────────────────────────────────────────────────────
class PlayerGameLogEntry {
  final int round;
  final int score;
  final int kicks;
  final int handballs;
  final int disposals;
  final int marks;
  final int tackles;
  final double goals;
  final int tog;
  final String opponent;

  const PlayerGameLogEntry({
    required this.round,
    required this.score,
    required this.kicks,
    required this.handballs,
    required this.disposals,
    required this.marks,
    required this.tackles,
    required this.goals,
    required this.tog,
    this.opponent = '',
  });

  factory PlayerGameLogEntry.fromJson(Map<String, dynamic> j) => PlayerGameLogEntry(
    round:     (j['round']     as num?)?.toInt()    ?? 0,
    score:     (j['score']     as num?)?.toInt()    ?? 0,
    kicks:     (j['kicks']     as num?)?.toInt()    ?? 0,
    handballs: (j['handballs'] as num?)?.toInt()    ?? 0,
    disposals: (j['disposals'] as num?)?.toInt()    ?? 0,
    marks:     (j['marks']     as num?)?.toInt()    ?? 0,
    tackles:   (j['tackles']   as num?)?.toInt()    ?? 0,
    goals:     (j['goals']     as num?)?.toDouble() ?? 0.0,
    tog:       (j['tog']       as num?)?.toInt()    ?? 0,
    opponent:   j['opponent']   as String?          ?? '',
  );
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
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['playerSeasonStats', season.toString()],
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

  // ── Drafted players ──────────────────────────────────────────────────────────

  /// Fetches all player IDs drafted across all game types for a given round.
  Future<Set<String>> fetchDraftedPlayers({
    required int season,
    required int round,
    String? gameType,
  }) async {
    try {
      final params = <String, String>{
        'season': season.toString(),
        'round':  round.toString(),
      };
      if (gameType != null && gameType.isNotEmpty) {
        params['gameType'] = gameType;
      }
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/draftedPlayers',
        params,
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return {};
      final json = jsonDecode(res.body);
      final ids = json['playerIds'] as List<dynamic>? ?? [];
      return ids.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Named squad ───────────────────────────────────────────────────────────

  /// Returns the set of named player IDs for a match.
  /// Empty set means teams haven't been announced yet.
  Future<Set<String>> fetchNamedSquad(String matchId) async {
    try {
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['namedSquad', matchId],
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

  // ── Player game log ──────────────────────────────────────────────────────────

  Future<List<PlayerGameLogEntry>> fetchPlayerGameLog({
    required int season,
    required String playerName,
  }) async {
    try {
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['playerGameLog', season.toString(), playerName],
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final games = json['games'] as List<dynamic>? ?? [];
      return games.map((g) => PlayerGameLogEntry.fromJson(g as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Vs opponent stats ────────────────────────────────────────────────────────

  /// Returns each player's historical average score vs their upcoming opponent.
  /// Key: playerName, value: {avgVsOpponent, gamesVs, upcomingOpponent}
  Future<Map<String, Map<String, dynamic>>> fetchVsOpponentStats({
    required int season,
    required int round,
    String gameType = 'weekend_quads',
  }) async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/vsOpponentStats',
        {
          'season':   season.toString(),
          'round':    round.toString(),
          'gameType': gameType,
        },
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return {};
      final json = jsonDecode(res.body);
      final stats = json['stats'] as List<dynamic>? ?? [];
      final map = <String, Map<String, dynamic>>{};
      for (final s in stats) {
        final name = s['player_name'] as String? ?? '';
        if (name.isEmpty) continue;
        // games_vs comes as a string from PostgreSQL COUNT(*)
        final gamesVsRaw = s['games_vs'];
        final gamesVs = gamesVsRaw is num
            ? gamesVsRaw.toInt()
            : int.tryParse(gamesVsRaw?.toString() ?? '') ?? 0;

        map[name] = {
          'avgVsOpponent': (s['avg_vs_opponent'] as num?)?.toInt() ?? 0,
          'gamesVs':       gamesVs,
          'opponent':       s['upcoming_opponent'] as String? ?? '',
        };
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ── Named squad persistence ──────────────────────────────────────────────────

  Future<Set<String>> fetchNamedSquadIds({
    required int season,
    required int round,
    required String gameType,
  }) async {
    try {
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['namedSquadIds', season.toString(), round.toString(), gameType],
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return {};
      final json = jsonDecode(res.body);
      final ids = json['playerIds'] as List<dynamic>? ?? [];
      return ids.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveNamedSquadIds({
    required int season,
    required int round,
    required String gameType,
    required Set<String> playerIds,
  }) async {
    try {
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['namedSquadIds', season.toString(), round.toString(), gameType],
      );
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'playerIds': playerIds.toList()}),
      );
    } catch (_) {}
  }

  Future<void> clearNamedSquadIds({
    required int season,
    required int round,
    required String gameType,
  }) async {
    try {
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['namedSquadIds', season.toString(), round.toString(), gameType],
      );
      await http.delete(url);
    } catch (_) {}
  }

  // ── Injury list ──────────────────────────────────────────────────────────────

  /// Fetches the current AFL injury list from the backend.
  /// Returns a list of {playerName, team, injury} maps.
  Future<List<Map<String, String>>> fetchInjuryList() async {
    try {
      final url = Uri.https(
        'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        '/injuryList',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final players = json['players'] as List<dynamic>? ?? [];
      return players
          .map((e) => Map<String, String>.from(
              (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Player flags ──────────────────────────────────────────────────────────────

  Future<Map<String, PlayerFlagEntry>> fetchFlags(int season) async {
    try {
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['playerFlags', season.toString()],
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
      final url = Uri(
        scheme: 'https',
        host: 'fantasy-pairs-and-weekend-quads-production.up.railway.app',
        pathSegments: ['playerFlags', season.toString(), playerId],
      );
      await http.delete(url);
    } catch (_) {}
  }
}