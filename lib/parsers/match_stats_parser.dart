import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/afl_player_match_stats.dart';
import '../repositories/player_repository.dart';
import '../repositories/fixture_repository.dart';

class MatchStatsParser {
  static const String baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  static final Map<String, List<AflPlayerMatchStats>> _cache = {};

  static Future<List<AflPlayerMatchStats>> fetchMatchStats(
    String matchId,
    PlayerRepository repo,
    FixtureRepository fixtureRepo,
  ) async {
    if (_cache.containsKey(matchId)) {
      return _cache[matchId]!;
    }

    http.Response res;
    try {
      res = await http.get(Uri.parse('$baseUrl/fantasy/$matchId'));
    } catch (_) {
      return [];
    }

    if (res.statusCode != 200 || res.body.isEmpty) return [];

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return [];
    }

    if (decoded is! Map) return [];

    final playersRaw = decoded['players'];
    if (playersRaw is! List) return [];

    final currentYear = DateTime.now().year;
final seasonPlayers = await repo.playersForSeason(currentYear);

    final List<AflPlayerMatchStats> results = [];

    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

    AflPlayer _matchPlayer(String id, String name) {
      final byId = seasonPlayers.where((p) => p.id == id);
      if (byId.isNotEmpty) return byId.first;

      final normalized = name.toLowerCase().trim();
      for (final p in seasonPlayers) {
        if (p.name.toLowerCase().trim() == normalized) {
          return p;
        }
      }

      return AflPlayer(
        id: id.isNotEmpty ? id : name,
        name: name,
        club: "",
        guernseyNumber: 0,
        season: 2025,
        fantasyScore: 0,
      );
    }

    for (final raw in playersRaw) {
      if (raw is! Map) continue;

      // NEW FIELD NAMES
      final id = raw['playerId']?.toString().trim() ?? "";
      final name = raw['playerName']?.toString().trim() ?? "";

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
          team: raw['teamAbbr']?.toString() ?? player.club,

          // DIRECT FIELDS (no stats{} object anymore)
          kicks: asInt(raw['kicks']),
          handballs: asInt(raw['handballs']),
          disposals: asInt(raw['kicks']) + asInt(raw['handballs']),
          marks: asInt(raw['marks']),
          tackles: asInt(raw['tackles']),
          goals: asInt(raw['goals']),
          behinds: asInt(raw['behinds']),
          hitouts: asInt(raw['hitouts']),
          freesFor: asInt(raw['freesFor']),
          freesAgainst: asInt(raw['freesAgainst']),
          timeOnGroundPercentage: asInt(raw['timeOnGroundPercentage']),

          // DFS fantasy points
          fantasyPoints: asInt(raw['dreamTeamPoints']),
        ),
      );
    }

    if (results.isNotEmpty) {
      _cache[matchId] = results;
    }

    return results;
  }

  static void clearCache() => _cache.clear();
}