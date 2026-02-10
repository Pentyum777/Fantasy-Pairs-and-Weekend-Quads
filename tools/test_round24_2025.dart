import '../lib/services/afl_fantasy_score_service.dart';

Future<void> main() async {
  // Use real match IDs that exist in the AFL GraphQL database
  const matchIds = [
    "CD_M20240180101",
    "CD_M20240180102",
    "CD_M20240180103",
  ];

  for (final id in matchIds) {
    print("\n==============================");
    print("Fetching fantasy stats for $id");
    print("==============================");

    // Fantasy stats (your main requirement)
    final fantasy = await AFLFantasyService.fetchFantasyStats(id);

    // Optional: match metadata (scores, quarter, clock)
    final meta = await AFLFantasyService.fetchMatchMeta(id);

    print("→ Received ${fantasy.length} fantasy stat entries.");

    if (meta != null) {
      print("Score: ${meta['homeTeam']['score']} - ${meta['awayTeam']['score']}");
      print("Quarter: ${meta['quarter']}  Clock: ${meta['clock']}");
    }

    if (fantasy.isNotEmpty) {
      for (final p in fantasy.take(5)) {
        print("  ${p['name']} → ${p['stats']['fantasyPoints']} pts");
      }
    } else {
      print("  No fantasy stats returned.");
    }
  }
}