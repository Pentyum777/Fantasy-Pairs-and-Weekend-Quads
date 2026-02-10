import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/afl_player_match_stats.dart';
import '../repositories/player_repository.dart';
import '../repositories/fixture_repository.dart';

class MatchStatsParser {
  // Your deployed backend
  static const String baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  static Future<List<AflPlayerMatchStats>> fetchMatchStats(
    String matchId,
    PlayerRepository repo,
    FixtureRepository fixtureRepo,
  ) async {
    // -----------------------------
    // 1) Fetch fantasy stats
    // -----------------------------
    final fantasyRes = await http.get(
      Uri.parse('$baseUrl/fantasy/$matchId'),
    );

    if (fantasyRes.statusCode != 200) {
      print(
        '❌ DFS fantasy request failed for $matchId '
        '(status ${fantasyRes.statusCode}). Body: ${fantasyRes.body}',
      );
      return [];
    }

    if (fantasyRes.body.isEmpty) {
      print('❌ Empty DFS fantasy body for matchId=$matchId');
      return [];
    }

    dynamic fantasyJson;
    try {
      fantasyJson = jsonDecode(fantasyRes.body);
    } catch (e) {
      print('❌ Failed to decode DFS fantasy JSON for $matchId: $e');
      return [];
    }

    // -----------------------------
    // 2) Fetch match metadata
    // -----------------------------
    try {
      final metaRes = await http.get(
        Uri.parse('$baseUrl/meta/$matchId'),
      );

      if (metaRes.statusCode == 200 && metaRes.body.isNotEmpty) {
        final metaJson = jsonDecode(metaRes.body);
        final match = metaJson['match'];

        if (match != null) {
          final home = match['homeTeam'];
          final away = match['awayTeam'];

          if (home != null && away != null) {
            final homeScore = home['score'] ?? 0;
            final awayScore = away['score'] ?? 0;

            final quarter = match['quarter']?.toString() ?? '';
            final clock = match['clock']?.toString() ?? '';

            fixtureRepo.updateFixtureScores(
              matchId: matchId,
              homeScore: homeScore,
              awayScore: awayScore,
              quarter: quarter,
              clock: clock,
            );
          }
        }
      } else {
        print(
          '⚠️ DFS meta request failed for $matchId '
          '(status ${metaRes.statusCode}). Body: ${metaRes.body}',
        );
      }
    } catch (e) {
      print('⚠️ DFS meta parse error for matchId=$matchId: $e');
    }

    // -----------------------------
    // 3) Validate fantasy JSON
    // -----------------------------
    if (fantasyJson is! Map<String, dynamic>) {
      print('❌ DFS fantasy JSON not an object for matchId=$matchId');
      return [];
    }

    final playersRaw = fantasyJson['players'];
    if (playersRaw is! List) {
      print('❌ DFS fantasy JSON missing "players" list for matchId=$matchId');
      return [];
    }

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

    // -----------------------------
    // 4) Build player stats
    // -----------------------------
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

    return results;
  }
}