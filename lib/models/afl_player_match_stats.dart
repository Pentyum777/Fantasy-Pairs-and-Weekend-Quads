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

  factory AflPlayerMatchStats.fromJson(Map<String, dynamic> json) {
    return AflPlayerMatchStats(
      player: json['player'] is Map<String, dynamic>
          ? AflPlayer.fromJson(json['player'] as Map<String, dynamic>)
          : null,
      team: (json['team'] ?? '').toString(),
      kicks: json['kicks'] as int?,
      handballs: json['handballs'] as int?,
      disposals: json['disposals'] as int?,
      marks: json['marks'] as int?,
      tackles: json['tackles'] as int?,
      goals: json['goals'] as int?,
      behinds: json['behinds'] as int?,
      hitouts: json['hitouts'] as int?,
      clearances: json['clearances'] as int?,
      metresGained: json['metresGained'] as int?,
      goalAssists: json['goalAssists'] as int?,
      timeOnGroundPercentage: json['timeOnGroundPercentage'] as int?,
      freesFor: json['freesFor'] as int?,
      freesAgainst: json['freesAgainst'] as int?,
      fantasyPoints: json['fantasyPoints'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player': player?.toJson(),
      'team': team,
      'kicks': kicks,
      'handballs': handballs,
      'disposals': disposals,
      'marks': marks,
      'tackles': tackles,
      'goals': goals,
      'behinds': behinds,
      'hitouts': hitouts,
      'clearances': clearances,
      'metresGained': metresGained,
      'goalAssists': goalAssists,
      'timeOnGroundPercentage': timeOnGroundPercentage,
      'freesFor': freesFor,
      'freesAgainst': freesAgainst,
      'fantasyPoints': fantasyPoints,
    };
  }
}
