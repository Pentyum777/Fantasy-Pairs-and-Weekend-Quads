import 'afl_player.dart';

class PlayerPick {
  /// Pick number (1-based index: 1, 2, 3, 4)
  final int pickNumber;

  /// Selected player (nullable until chosen)
  AflPlayer? player;

  /// Fantasy score for this pick
  int score;

  PlayerPick({
    required this.pickNumber,
    this.player,
    this.score = 0,
  });
}