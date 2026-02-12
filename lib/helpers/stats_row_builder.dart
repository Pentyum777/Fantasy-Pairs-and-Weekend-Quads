import '../models/player_pick.dart';

class StatsRowBuilder {
  static Map<String, dynamic> build(PlayerPick pick) {
    return {
      "Player": pick.player?.name ?? "",
      "K": pick.kicks,
      "H": pick.handballs,
      "M": pick.marks,
      "T": pick.tackles,
      "HO": pick.hitouts,
      "FF": pick.freesFor,
      "FA": pick.freesAgainst,
      "G": pick.goals,
      "B": pick.behinds,
      "TOG": pick.timeOnGroundPercentage,
    };
  }
}