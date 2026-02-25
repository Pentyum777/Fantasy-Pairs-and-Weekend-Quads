import 'dart:io';

import '../lib/repositories/player_repository.dart';
import '../lib/repositories/fixture_repository.dart';
import '../lib/parsers/match_stats_parser.dart';
import '../lib/models/afl_player_match_stats.dart';

/// Run with:
/// dart tools/find_missing_players.dart 2026 1
///
/// Where:
///   2026 = season
///   1    = round number (or 0 for preseason)
///
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print("Usage: dart find_missing_players.dart <season> <round>");
    exit(1);
  }

  final season = int.parse(args[0]);
  final round = int.parse(args[1]);

  print("🔍 Scanning season $season, round $round...");

  final fixtureRepo = FixtureRepository();
  final playerRepo = PlayerRepository();

  // Load fixtures
  await fixtureRepo.loadFixturesFromExcelFile('assets/afl_fixtures_$season.xlsx');

  // Load players
  await playerRepo.loadSeason(season);
  final seasonPlayers = await playerRepo.playersForSeason(season);

  final knownIds = seasonPlayers.map((p) => p.id).toSet();

  // Get fixtures for the round
  final fixtures = round == 0
      ? fixtureRepo.preseasonFixturesForSeason(season)
      : fixtureRepo.fixturesForSeasonRound(season, round);

  if (fixtures.isEmpty) {
    print("⚠️ No fixtures found for season $season round $round");
    exit(0);
  }

  final missing = <String>{};

  for (final f in fixtures) {
    final matchId = f.matchId?.trim();
    if (matchId == null || matchId.isEmpty) continue;

    print("📡 Fetching stats for match $matchId...");

    final stats = await MatchStatsParser.fetchMatchStats(
      matchId,
      playerRepo,
      fixtureRepo,
    );

    for (final AflPlayerMatchStats s in stats) {
      final id = s.player?.id;
      if (id == null) continue;

      if (!knownIds.contains(id)) {
        missing.add(id);
      }
    }
  }

  print("\n========================================");
  print("🧩 Missing players for season $season:");
  print("========================================");

  if (missing.isEmpty) {
    print("🎉 No missing players — your list is complete!");
  } else {
    for (final id in missing) {
      print("❌ Missing: $id");
    }
  }

  print("========================================\n");
}