import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_fixture.dart';
import '../utils/afl_club_codes.dart';
import '../parsers/fixture_parser.dart';

import '../services/afl_fantasy_score_service.dart';
import '../models/punter_selection.dart';

class FixtureRepository {
  final Map<int, List<AflFixture>> fixturesBySeason = {};

  static const Map<String, String> _fixtureClubMap = {
    "CARL": "CAR",
    "CARLTON": "CAR",
    "COLL": "COL",
    "COLLINGWOOD": "COL",
    "BRI": "BRL",
    "BRISBANE": "BRL",
    "BRISBANE LIONS": "BRL",
    "MELB": "MELB",
    "MELBOURNE": "MELB",
    "RICH": "RIC",
    "RICHMOND": "RIC",
    "WB": "WBD",
    "WESTERN BULLDOGS": "WBD",
    "WESTERN BULLDOGS FOOTBALL CLUB": "WBD",
    "GWS GIANTS": "GWS",
    "GWS": "GWS",
  };

  String normalizeFixtureClub(String raw) {
    final cleaned = raw
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final base = AflClubCodes.normalize(cleaned);
    if (base.isEmpty) return base;

    final key = base.toUpperCase();
    return _fixtureClubMap[key] ?? base;
  }

  Future<void> loadFixturesFromExcelFile(String path) async {
    print("DEBUG: loadFixturesFromExcelFile CALLED for path = $path");

    final season = _extractSeasonFromFilename(path);

    if (season == null) {
      print("❌ Could not determine season from filename: $path");
      return;
    }

    try {
      print("DEBUG: Attempting to load asset via rootBundle: $path");

      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();

      print("DEBUG: bytes loaded = ${bytes.length}");

      final parser = FixtureParser();
      final parsedFixtures = parser.parse(bytes);

      fixturesBySeason[season] = parsedFixtures;

      print("DEBUG: parsedFixtures.length = ${parsedFixtures.length}");
      print("✅ Loaded ${parsedFixtures.length} fixtures for $season");
    } catch (e) {
      print("❌ DEBUG: ERROR loading fixture asset: $e");
    }
  }

  List<int> allRoundsForSeason(int season) {
    final fixtures = fixturesBySeason[season] ?? [];
    final rounds = fixtures
        .where((f) => !f.isPreseason && f.round != null)
        .map((f) => f.round!)
        .toSet()
        .toList();

    rounds.sort();
    return rounds;
  }

  List<AflFixture> fixturesForSeasonRound(int season, int? round) {
    final fixtures = fixturesBySeason[season] ?? [];

    if (round == null) {
      return fixtures.where((f) => f.isPreseason).toList();
    }

    return fixtures
        .where((f) => !f.isPreseason && f.round == round)
        .toList();
  }

  List<AflFixture> preseasonFixturesForSeason(int season) {
    return fixturesBySeason[season]
            ?.where((f) => f.isPreseason)
            .toList() ??
        [];
  }

  /// Uses full match payload (metadata + players).
  Future<void> refreshLiveScores({
    required String matchId,
    required List<PunterSelection> selections,
  }) async {
    final payload = await AFLFantasyService.fetchFantasyMatchPayload(matchId);

    final players = payload['players'] as List<dynamic>? ?? const [];
    final homeScore = payload['homeScore'] as int?;
    final awayScore = payload['awayScore'] as int?;
    final quarter = payload['quarter'] as String?;
    final clock = payload['clock'] as String?;
    final status = payload['status'] as String?;

    // Update fixture metadata if present.
    if (homeScore != null &&
        awayScore != null &&
        (quarter != null || clock != null)) {
      updateFixtureScores(
        matchId: matchId,
        homeScore: homeScore,
        awayScore: awayScore,
        quarter: quarter ?? 'Final',
        clock: clock ?? 'FT',
        status: status ?? '',
      );
    }

    // Build DFS-ID → stats map.
    final statsById = <String, Map<String, dynamic>>{};
    for (final p in players) {
      if (p is! Map<String, dynamic>) continue;
      final id = p["id"] as String?;
      final rawStats = p["stats"] as Map<String, dynamic>?;

      if (id == null || rawStats == null) continue;
      statsById[id] = rawStats;
    }

    for (final punter in selections) {
      for (final pick in punter.picks) {
        final id = pick.player?.id;

        if (id == null) {
          pick.fantasyPoints = 0;
          pick.stats = {};
          continue;
        }

        final raw = statsById[id];

        if (raw == null) {
          pick.fantasyPoints = 0;
          pick.stats = {};
          continue;
        }

        pick.fantasyPoints = raw["fantasyPoints"] as int? ?? 0;

        pick.stats = {
          "kicks": raw["kicks"],
          "handballs": raw["handballs"],
          "marks": raw["marks"],
          "tackles": raw["tackles"],
          "hitouts": raw["hitouts"],
          "freesFor": raw["freesFor"],
          "freesAgainst": raw["freesAgainst"],
          "goals": raw["goals"],
          "behinds": raw["behinds"],
          "timeOnGroundPercentage": raw["timeOnGroundPercentage"],
        };
      }

      punter.liveScore = punter.picks.fold<int>(
        0,
        (sum, p) => sum + p.fantasyPoints,
      );
    }
  }

  /// ⭐ FIXED: Now accepts `status`
  void updateFixtureScores({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String quarter,
    required String clock,
    String? status,
  }) {
    for (final season in fixturesBySeason.keys) {
      for (final f in fixturesBySeason[season]!) {
        if (f.matchId == matchId) {
          f.homeScore = homeScore;
          f.awayScore = awayScore;
          f.quarterText = quarter;
          f.timeText = clock;

          if (status != null) {
            f.status = status;
          }

          return;
        }
      }
    }
  }

  int? _extractSeasonFromFilename(String path) {
    final match = RegExp(r'(\d{4})').firstMatch(path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}