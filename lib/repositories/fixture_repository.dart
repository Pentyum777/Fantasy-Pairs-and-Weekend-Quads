import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_fixture.dart';
import '../utils/afl_club_codes.dart';
import '../parsers/fixture_parser.dart';
import '../services/afl_fantasy_score_service.dart';

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

      // Always store a list, even if empty
      fixturesBySeason[season] = parsedFixtures;

      print("DEBUG: parsedFixtures.length = ${parsedFixtures.length}");
      print("✅ Loaded ${parsedFixtures.length} fixtures for $season");
    } catch (e) {
      print("❌ DEBUG: ERROR loading fixture asset: $e");
      fixturesBySeason[season] = <AflFixture>[]; // prevent null map entries
    }
  }

  List<int> allRoundsForSeason(int season) {
    final fixtures = fixturesBySeason[season];
    if (fixtures == null || fixtures.isEmpty) return <int>[];

    final rounds = <int>{};

    for (final f in fixtures) {
      final r = f.round;
      if (f.isPreseason || r == null) continue;
      rounds.add(r);
    }

    final sorted = rounds.toList()..sort();
    return sorted;
  }

  List<AflFixture> fixturesForSeasonRound(int season, int? round) {
    final fixtures = fixturesBySeason[season] ?? const <AflFixture>[];

    if (round == null) {
      return fixtures.where((f) => f.isPreseason).toList();
    }

    return fixtures
        .where((f) => !f.isPreseason && f.round == round)
        .toList();
  }

  List<AflFixture> preseasonFixturesForSeason(int season) {
    final fixtures = fixturesBySeason[season];
    if (fixtures == null || fixtures.isEmpty) return <AflFixture>[];

    return fixtures.where((f) => f.isPreseason).toList();
  }

  Future<void> refreshLiveScores({
    required String matchId,
  }) async {
    final payload = await AFLFantasyService.fetchFantasyMatchPayload(matchId);

    if (payload.isEmpty) return;

    final homeScore = payload['homeScore'] as int?;
    final awayScore = payload['awayScore'] as int?;
    final quarter = payload['quarter'] as String?;
    final clock = payload['clock'] as String?;
    final status = payload['status'] as String?;

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
  }

  void updateFixtureScores({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String quarter,
    required String clock,
    String? status,
  }) {
    for (final season in fixturesBySeason.keys) {
      final list = fixturesBySeason[season];
      if (list == null || list.isEmpty) continue;

      for (final f in list) {
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
    final match = RegExp(r'(\d{4})(?=\D*$)').firstMatch(path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}