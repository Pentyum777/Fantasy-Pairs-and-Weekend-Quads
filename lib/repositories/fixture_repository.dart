import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_fixture.dart';
import '../utils/afl_club_codes.dart';
import '../parsers/fixture_parser.dart';

// CORRECT IMPORT
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

  Future<void> refreshLiveScores({
    required String matchId,
    required List<PunterSelection> selections,
  }) async {
    final stats = await AFLFantasyService.fetchFantasyStats(matchId);

    final statsById = <String, int>{};
    for (final p in stats) {
      final id = p["id"] as String;
      final fp = p["stats"]["fantasyPoints"] as int? ?? 0;
      statsById[id] = fp;
    }

    for (final punter in selections) {
      for (final pick in punter.picks) {
        final id = pick.player?.id;

        if (id == null) {
          pick.stats = {"fantasyPoints": 0};
          continue;
        }

        final fp = statsById[id] ?? 0;

        pick.stats = {
          "fantasyPoints": fp,
        };
      }

      // Update liveScore (mutable field)
      punter.liveScore = punter.picks.fold<int>(
        0,
        (sum, p) => sum + p.fantasyPoints,
      );
    }
  }

  void updateFixtureScores({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String quarter,
    required String clock,
  }) {
    for (final season in fixturesBySeason.keys) {
      for (final f in fixturesBySeason[season]!) {
        if (f.matchId == matchId) {
          f.homeScore = homeScore;
          f.awayScore = awayScore;
          f.quarterText = quarter;
          f.timeText = clock;
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