import 'afl_player.dart';

class AflPlayerMatchStats {
  final AflPlayer? player;

  final String team;

  // All raw stats from backend MUST be nullable
  final int? kicks;
  final int? handballs;
  final int? disposals;
  final int? marks;
  final int? tackles;
  final int? goals;
  final int? behinds;
  final int? hitouts;

  final int? clearances;
  final int? metresGained;
  final int? goalAssists;
  final int? timeOnGroundPercentage;

  final int? freesFor;
  final int? freesAgainst;

  /// Live AFL Fantasy score (direct from backend)
  int? fantasyPoints;

  AflPlayerMatchStats({
    this.player,
    required this.team,

    // All backend-fed fields must be nullable
    this.kicks,
    this.handballs,
    this.disposals,
    this.marks,
    this.tackles,
    this.goals,
    this.behinds,
    this.hitouts,

    this.clearances,
    this.metresGained,
    this.goalAssists,
    this.timeOnGroundPercentage,

    this.freesFor,
    this.freesAgainst,

    this.fantasyPoints,
  });
}