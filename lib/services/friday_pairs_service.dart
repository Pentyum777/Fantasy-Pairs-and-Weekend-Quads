import 'dart:math';
import '../models/punter_selection.dart';

class FridayPairsService {
  final Random _rng = Random();

  // ---------------------------------------------------------------------------
  // STEP 1 — Choose a random finishing position from the bottom half
  // ---------------------------------------------------------------------------
  //
  // Example:
  // If there are 10 punters:
  //   bottom half = positions 6,7,8,9,10
  //   randomly pick one of those positions
  //
  // Returns a 1-based finishing position.
  //
  int selectRandomBottomHalfPosition(int punterCount) {
    if (punterCount <= 1) {
      throw ArgumentError("Need at least 2 punters.");
    }

    // 1-based index where bottom half starts
    final halfStart = (punterCount ~/ 2) + 1;

    // Generate list of positions in the bottom half
    final positions = List.generate(
      punterCount - halfStart + 1,
      (i) => halfStart + i,
    );

    positions.shuffle(_rng);
    return positions.first;
  }

  // ---------------------------------------------------------------------------
  // STEP 2 — Get the punter currently sitting in a given finishing position
  // ---------------------------------------------------------------------------
  //
  // selections must be in punterNumber order (1..N)
  //
  PunterSelection getPunterAtPosition(
    List<PunterSelection> selections,
    int position,
  ) {
    if (position < 1 || position > selections.length) {
      throw ArgumentError("Position out of range.");
    }

    return selections[position - 1];
  }

  // ---------------------------------------------------------------------------
  // STEP 3 — Resolve ties using highest individual player score
  // ---------------------------------------------------------------------------
  //
  // Given a list of tied punters, return the one whose single best player
  // score is the highest.
  //
  PunterSelection resolveTieByBestPlayer(List<PunterSelection> tied) {
    tied.sort((a, b) {
      final aBest = _bestPlayerScore(a);
      final bBest = _bestPlayerScore(b);
      return bBest.compareTo(aBest); // highest wins
    });

    return tied.first;
  }

  // Helper: compute highest individual player score for a punter
  int _bestPlayerScore(PunterSelection p) {
    int best = 0;

    for (final pick in p.picks) {
      final score = pick.stats?["score"] ?? 0;
      if (score > best) best = score;
    }

    return best;
  }

  // ---------------------------------------------------------------------------
  // STEP 4 — Determine the final Friday Pairs winner at round completion
  // ---------------------------------------------------------------------------
  //
  // sortedSelections must be sorted DESC by totalScore.
  // randomPosition is the 1-based finishing slot chosen earlier.
  //
  PunterSelection determineFinalWinner(
    List<PunterSelection> sortedSelections,
    int randomPosition,
  ) {
    final index = randomPosition - 1;
    final targetScore = sortedSelections[index].totalScore;

    // All punters tied at that finishing score
    final tied = sortedSelections
        .where((p) => p.totalScore == targetScore)
        .toList();

    if (tied.length == 1) {
      return tied.first;
    }

    // Tie-breaker: highest individual player score
    return resolveTieByBestPlayer(tied);
  }
}