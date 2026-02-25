import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';

Future<void> validateAflData({
  required int season,
  required FixtureRepository fixtureRepo,
  required PlayerRepository playerRepo,
}) async {
  print("====================================");
  print(" AFL DATA VALIDATION START ");
  print("====================================");

  // ⭐ Fixtures for the selected season only
  final fixtures = fixtureRepo.fixturesBySeason[season] ?? [];

  final fixtureTeams = <String>{};
  for (final f in fixtures) {
    fixtureTeams.add(f.homeTeam.trim().toUpperCase());
    fixtureTeams.add(f.awayTeam.trim().toUpperCase());
  }

  print("\nFixture team codes found:");
  print(fixtureTeams);

  // ⭐ Players for the selected season only
  final seasonPlayers = await playerRepo.playersForSeason(season);

  final playerTeams = <String>{};
  for (final p in seasonPlayers) {
    playerTeams.add(p.club.trim().toUpperCase());
  }

  print("\nPlayer club codes found:");
  print(playerTeams);

  final missingInPlayers = fixtureTeams.difference(playerTeams);
  final missingInFixtures = playerTeams.difference(fixtureTeams);

  print("\n=== MISMATCH REPORT ===");

  if (missingInPlayers.isEmpty) {
    print("✔ All fixture clubs exist in player list");
  } else {
    print("❌ Clubs in FIXTURES but NOT in PLAYERS:");
    print(missingInPlayers);
  }

  if (missingInFixtures.isEmpty) {
    print("✔ All player clubs exist in fixtures");
  } else {
    print("❌ Clubs in PLAYERS but NOT in FIXTURES:");
    print(missingInFixtures);
  }

  // ⭐ Validate club codes for this season only
  final failedPlayers = seasonPlayers
      .where((p) => p.club.isEmpty || p.club.length < 2)
      .toList();

  if (failedPlayers.isNotEmpty) {
    print("\n❌ Players with invalid or missing club codes:");
    for (final p in failedPlayers) {
      print(" - ${p.name} (${p.club})");
    }
  } else {
    print("\n✔ All players have valid normalized club codes");
  }

  print("\n====================================");
  print(" AFL DATA VALIDATION COMPLETE ");
  print("====================================");
}