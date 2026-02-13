import 'afl_player.dart';

class PlayerPick {
  final int pickNumber;
  AflPlayer? player;

  /// Raw stats only (no fantasyPoints)
  Map<String, dynamic>? stats;

  /// Single source of truth for fantasy points
  int fantasyPoints;

  PlayerPick({
    required this.pickNumber,
    this.player,
    this.stats,
    this.fantasyPoints = 0,
  });

  int get kicks => _int("kicks");
  int get handballs => _int("handballs");
  int get marks => _int("marks");
  int get tackles => _int("tackles");
  int get hitouts => _int("hitouts");
  int get freesFor => _int("freesFor");
  int get freesAgainst => _int("freesAgainst");
  int get goals => _int("goals");
  int get behinds => _int("behinds");
  int get timeOnGroundPercentage => _int("timeOnGroundPercentage");

  int _int(String key) {
    final v = stats?[key];
    if (v is int) return v;
    if (v is double) return v.round();
    return 0;
  }
}