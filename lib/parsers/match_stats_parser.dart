import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/afl_player_match_stats.dart';
import '../repositories/player_repository.dart';
import '../repositories/fixture_repository.dart';

class MatchStatsParser {
  static const String baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  // ⭐ NEW: In-memory cache for match stats
  static final Map<String, List<AflPlayerMatchStats>> _cache = {};

  static Future<List<AflPlayerMatchStats>> fetchMatchStats(
    String matchId,
    PlayerRepository repo,
    FixtureRepository fixtureRepo,
  ) async {

    // ⭐ 1. Return cached stats instantly
    if (_cache.containsKey(matchId)) {
      return _cache[matchId]!;
    }

    // ⭐ 2. Fetch from backend
    final fantasyRes = await http.get(
      Uri.parse('$baseUrl/fantasy/$matchId'),
    );

    if (fantasyRes.statusCode != 200) return [];
    if (fantasyRes.body.isEmpty) return [];

    final fantasyJson = jsonDecode(fantasyRes.body);
    final playersRaw = fantasyJson['players'];
    if (playersRaw is! List) return [];

    final List<AflPlayerMatchStats> results = [];

    int asInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    Future<AflPlayer> _findPlayer(String name, int season) async {
      final normalized = name.toLowerCase().trim();
      final seasonPlayers = await repo.playersForSeason(season);

      for (final p in seasonPlayers) {
        if (p.name.toLowerCase().trim() == normalized) {
          return p;
        }
      }

      return AflPlayer(
        id: name,
        name: name,
        club: "",
        guernseyNumber: 0,
        season: season,
        fantasyScore: 0,
      );
    }

    final season = int.tryParse(matchId.substring(4, 8)) ?? 2025;

    for (final p in playersRaw) {
      if (p is! Map<String, dynamic>) continue;

      final name = p['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final stats = p['stats'] is Map
          ? Map<String, dynamic>.from(p['stats'])
          : <String, dynamic>{};

      final player = await _findPlayer(name, season);
      final teamCode = player.club;

      results.add(
        AflPlayerMatchStats(
          player: player,
          team: teamCode,
          kicks: asInt(stats['kicks']),
          handballs: asInt(stats['handballs']),
          disposals: asInt(stats['disposals']),
          marks: asInt(stats['marks']),
          tackles: asInt(stats['tackles']),
          goals: asInt(stats['goals']),
          behinds: asInt(stats['behinds'] ?? stats['behind']),
          hitouts: asInt(stats['hitouts']),
          freesFor: asInt(stats['freesFor']),
          freesAgainst: asInt(stats['freesAgainst']),
          timeOnGroundPercentage: asInt(stats['timeOnGroundPercentage']),
          fantasyPoints: asInt(stats['fantasyPoints']),
        ),
      );
    }

    // ⭐ 3. Store in cache
    _cache[matchId] = results;

    return results;
  }

  // ⭐ Optional: clear cache (useful when switching rounds)
  static void clearCache() {
    _cache.clear();
  }
}