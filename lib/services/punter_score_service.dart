import '../models/punter_selection.dart';
import '../models/afl_player_match_stats.dart';

class PunterScoreService {
  const PunterScoreService();

  /// Calculates the total AFL Fantasy score for a punter given:
  /// - Their selected players (picks)
  /// - A map of live stats keyed by playerId (String)
  ///
  /// Any pick with no player or no stats contributes 0.
  int calculatePunterScore({
    required PunterSelection selection,
    required Map<String, AflPlayerMatchStats> liveStatsByPlayerId,
  }) {
    int total = 0;

    for (final pick in selection.picks) {
      final player = pick.player;
      if (player == null) continue;

      final stats = liveStatsByPlayerId[player.id];
      if (stats == null) continue;

      total += stats.fantasyPoints;
    }

    return total;
  }
}