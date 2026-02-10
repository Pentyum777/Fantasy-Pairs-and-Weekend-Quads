import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';

void validateAflData({
  required FixtureRepository fixtureRepo,
  required PlayerRepository playerRepo,
}) {
  print("====================================");
  print(" AFL DATA VALIDATION START ");
  print("====================================");

  // ⭐ NEW: Flatten all fixtures across all seasons
  final allFixtures = fixtureRepo.fixturesBySeason.values
      .expand((seasonList) => seasonList)
      .toList();

  final fixtureTeams = <String>{};
  for (final f in allFixtures) {
    fixtureTeams.add(f.homeTeam.trim().toUpperCase());
    fixtureTeams.add(f.awayTeam.trim().toUpperCase());
  }

  print("\nFixture team codes found:");
  print(fixtureTeams);

  final playerTeams = <String>{};
  for (final p in playerRepo.players) {
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

  final failedPlayers = playerRepo.players
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