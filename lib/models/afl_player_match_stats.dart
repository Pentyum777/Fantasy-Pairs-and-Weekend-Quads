import 'afl_player.dart';

class AflPlayerMatchStats {
  final AflPlayer player;

  final String team;
  final int kicks;
  final int handballs;
  final int disposals;
  final int marks;
  final int tackles;
  final int goals;
  final int behinds;
  final int hitouts;
  final int freesFor;
  final int freesAgainst;

  /// Live AFL Fantasy score (computed from raw stats)
  int fantasyPoints;

  AflPlayerMatchStats({
    required this.player,
    required this.team,
    this.kicks = 0,
    this.handballs = 0,
    this.disposals = 0,
    this.marks = 0,
    this.tackles = 0,
    this.goals = 0,
    this.behinds = 0,
    this.hitouts = 0,
    this.freesFor = 0,
    this.freesAgainst = 0,
    this.fantasyPoints = 0,
  });
}