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

      total += (stats.fantasyPoints ?? 0);
    }

    return total;
  }

  // ---------------------------------------------------------------------------
  // ⭐ NEW: Build completed round results for backend persistence
  // ---------------------------------------------------------------------------
  ///
  /// Produces the exact JSON structure required by:
  /// POST /saveRoundResults
  ///
  /// [
  ///   {
  ///     "name": "Wayne",
  ///     "total": 123,
  ///     "picks": [
  ///       { "playerId": "1234", "score": 55 },
  ///       { "playerId": "5678", "score": 68 }
  ///     ]
  ///   }
  /// ]
  ///
  List<Map<String, dynamic>> buildCompletedRoundResults({
    required List<PunterSelection> selections,
    required Map<String, AflPlayerMatchStats> statsByPlayerId,
  }) {
    final List<Map<String, dynamic>> punters = [];

    for (final sel in selections) {
      int total = 0;

      final picksJson = <Map<String, dynamic>>[];

      for (final pick in sel.picks) {
        final playerId = pick.player?.id;
        final stats = playerId != null ? statsByPlayerId[playerId] : null;
        final score = stats?.fantasyPoints ?? 0;

        total += score;

        picksJson.add({
          "playerId": playerId,
          "score": score,
        });
      }

      punters.add({
        "name": sel.punterName,
        "total": total,
        "picks": picksJson,
      });
    }

    return punters;
  }
}