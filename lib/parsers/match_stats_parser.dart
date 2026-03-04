import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/afl_player_match_stats.dart';
import '../repositories/player_repository.dart';
import '../repositories/fixture_repository.dart';

class MatchStatsParser {
  static const String baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  // In-memory cache
  static final Map<String, List<AflPlayerMatchStats>> _cache = {};

  static Future<List<AflPlayerMatchStats>> fetchMatchStats(
    String matchId,
    PlayerRepository repo,
    FixtureRepository fixtureRepo, // kept for compatibility
  ) async {
    // 1. Return cached results
    if (_cache.containsKey(matchId)) {
      return _cache[matchId]!;
    }

    // 2. Fetch from backend
    http.Response res;
    try {
      res = await http.get(Uri.parse('$baseUrl/fantasy/$matchId'));
    } catch (e) {
      // Network failure
      return [];
    }

    // Reject empty or non-200 responses
    if (res.statusCode != 200 || res.body.isEmpty) {
      return [];
    }

    // 3. Safe JSON decode (prevents ga0)
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      // HTML or corrupted JSON → avoid crash
      return [];
    }

    if (decoded is! Map) return [];

    final playersRaw = decoded['players'];
    if (playersRaw is! List) return [];

    // Load all players for 2025 (your dataset)
    final seasonPlayers = await repo.playersForSeason(2025);

    final List<AflPlayerMatchStats> results = [];

    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

    // Match DFS player to your repo player
    AflPlayer _matchPlayer(String id, String name) {
      // 1. ID match
      final byId = seasonPlayers.where((p) => p.id == id);
      if (byId.isNotEmpty) return byId.first;

      // 2. Name match
      final normalized = name.toLowerCase().trim();
      for (final p in seasonPlayers) {
        if (p.name.toLowerCase().trim() == normalized) {
          return p;
        }
      }

      // 3. Fallback placeholder
      return AflPlayer(
        id: id.isNotEmpty ? id : name,
        name: name,
        club: "",
        guernseyNumber: 0,
        season: 2025,
        fantasyScore: 0,
      );
    }

    // Parse each DFS player
    for (final raw in playersRaw) {
      if (raw is! Map) continue;

      // Safe extraction
      final id = raw['id']?.toString().trim() ?? "";
      final name = raw['name']?.toString().trim() ?? "";

      // Safe stats map
      final stats = raw['stats'] is Map
          ? Map<String, dynamic>.from(raw['stats'])
          : <String, dynamic>{};

      final repoPlayer = _matchPlayer(id, name);

      final player = AflPlayer(
        id: repoPlayer.id,
        name: repoPlayer.name,
        club: repoPlayer.club,
        guernseyNumber: repoPlayer.guernseyNumber,
        season: repoPlayer.season,
        fantasyScore: repoPlayer.fantasyScore,
      );

      results.add(
        AflPlayerMatchStats(
          player: player,
          team: player.club,
          kicks: asInt(stats['kicks']),
          handballs: asInt(stats['handballs']),
          disposals: asInt(stats['kicks']) + asInt(stats['handballs']),
          marks: asInt(stats['marks']),
          tackles: asInt(stats['tackles']),
          goals: asInt(stats['goals']),
          behinds: asInt(stats['behinds']),
          hitouts: asInt(stats['hitouts']),
          freesFor: asInt(stats['freesFor']),
          freesAgainst: asInt(stats['freesAgainst']),
          timeOnGroundPercentage: asInt(stats['timeOnGroundPercentage']),
          fantasyPoints: asInt(stats['fantasyPoints']),
        ),
      );
    }

    // Cache only non-empty results
    if (results.isNotEmpty) {
      _cache[matchId] = results;
    }

    return results;
  }

  static void clearCache() => _cache.clear();
}