import '../models/afl_player_match_stats.dart';

class StatsRowBuilder {
  static Map<String, dynamic> fromStats(AflPlayerMatchStats s) {
    return {
      "fantasyPoints": s.fantasyPoints,
      "kicks": s.kicks,
      "handballs": s.handballs,
      "disposals": s.disposals,
      "marks": s.marks,
      "tackles": s.tackles,
      "goals": s.goals,
      "behinds": s.behinds,
      "hitouts": s.hitouts,
      "freesFor": s.freesFor,
      "freesAgainst": s.freesAgainst,
      "timeOnGroundPercentage": s.timeOnGroundPercentage,
    };
  }
}