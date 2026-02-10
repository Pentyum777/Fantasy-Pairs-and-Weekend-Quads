import 'afl_player.dart';

class PlayerPick {
  /// Pick number (1-based index: 1, 2, 3, 4)
  final int pickNumber;

  /// Selected player (nullable until chosen)
  AflPlayer? player;

  /// Full fantasy stats injected after GraphQL fetch.
  /// Null until `loadFantasyStats()` populates it.
  Map<String, dynamic>? stats;

  PlayerPick({
    required this.pickNumber,
    this.player,
    this.stats,
  });

  // ------------------------------------------------------------
  // Convenience getters for UI cells
  // ------------------------------------------------------------

  int get fantasyPoints => _int("fantasyPoints");
  int get goals => _int("goals");
  int get behinds => _int("behinds");
  int get disposals => _int("disposals");
  int get kicks => _int("kicks");
  int get handballs => _int("handballs");
  int get marks => _int("marks");
  int get tackles => _int("tackles");
  int get hitouts => _int("hitouts");
  int get clearances => _int("clearances");
  int get metresGained => _int("metresGained");
  int get goalAssists => _int("goalAssists");
  int get timeOnGroundPercentage => _int("timeOnGroundPercentage");

  // ------------------------------------------------------------
  // Internal helper
  // ------------------------------------------------------------
  int _int(String key) {
    final v = stats?[key];
    if (v is int) return v;
    if (v is double) return v.round();
    return 0;
  }
}