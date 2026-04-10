import 'afl_player.dart';

class AflPlayerMatchStats {
  final AflPlayer? player;

  final String team;

  final int? kicks;
  final int? handballs;
  final int? disposals;
  final int? marks;
  final int? tackles;
  final int? goals;
  final int? behinds;
  final int? hitouts;

  final int? timeOnGroundPercentage;

  final int? freesFor;
  final int? freesAgainst;

  /// AFL Fantasy (DreamTeam) points
  int? fantasyPoints;

  /// Optional DFS fields
  final int? superCoachPoints;
  final int? gameDayPoints;

  /// Quarter splits
  final int? q1;
  final int? q2;
  final int? q3;
  final int? q4;

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
    this.timeOnGroundPercentage,
    this.freesFor,
    this.freesAgainst,
    this.fantasyPoints,
    this.superCoachPoints,
    this.gameDayPoints,
    this.q1,
    this.q2,
    this.q3,
    this.q4,
  });

bool isCompletedGame = false;

  factory AflPlayerMatchStats.fromJson(Map<String, dynamic> json) {
    int? _asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '');

    final int? kicks = _asInt(json['kicks']);
    final int? handballs = _asInt(json['handballs']);

    return AflPlayerMatchStats(
      player: json['player'] is Map<String, dynamic>
          ? AflPlayer.fromJson(json['player'] as Map<String, dynamic>)
          : null,

      team: (json['team'] ?? json['teamAbbr'] ?? '').toString(),

      kicks: kicks,
      handballs: handballs,
      disposals: (kicks ?? 0) + (handballs ?? 0),

      marks: _asInt(json['marks']),
      tackles: _asInt(json['tackles']),
      goals: _asInt(json['goals']),
      behinds: _asInt(json['behinds']),
      hitouts: _asInt(json['hitouts']),

      timeOnGroundPercentage: _asInt(json['timeOnGroundPercentage']),
      freesFor: _asInt(json['freesFor']),
      freesAgainst: _asInt(json['freesAgainst']),

      fantasyPoints: _asInt(json['dreamTeamPoints']),
      superCoachPoints: _asInt(json['superCoachPoints']),
      gameDayPoints: _asInt(json['gameDayPoints']),

      q1: _asInt(json['q1']),
      q2: _asInt(json['q2']),
      q3: _asInt(json['q3']),
      q4: _asInt(json['q4']),
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
      'timeOnGroundPercentage': timeOnGroundPercentage,
      'freesFor': freesFor,
      'freesAgainst': freesAgainst,
      'fantasyPoints': fantasyPoints,
      'superCoachPoints': superCoachPoints,
      'gameDayPoints': gameDayPoints,
      'q1': q1,
      'q2': q2,
      'q3': q3,
      'q4': q4,
    };
  }
}