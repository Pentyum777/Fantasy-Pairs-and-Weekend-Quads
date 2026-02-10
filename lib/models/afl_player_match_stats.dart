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

  final int clearances;
  final int metresGained;
  final int goalAssists;
  final int timeOnGroundPercentage;

  final int freesFor;
  final int freesAgainst;

  /// Live AFL Fantasy score (direct from backend)
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
    this.clearances = 0,
    this.metresGained = 0,
    this.goalAssists = 0,
    this.timeOnGroundPercentage = 0,
    this.freesFor = 0,
    this.freesAgainst = 0,
    this.fantasyPoints = 0,
  });
}