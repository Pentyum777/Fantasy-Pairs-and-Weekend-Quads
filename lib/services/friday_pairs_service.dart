import 'dart:math';
import '../models/punter_selection.dart';

class FridayPairsService {
  final Random _rng = Random();

  // ---------------------------------------------------------------------------
  // STEP 1 — Choose a random finishing position from the bottom half
  // ---------------------------------------------------------------------------
  //
  // Correct Friday Pairs rule:
  //   bottomCount = ceil(total / 2)
  //   start = total - bottomCount + 1
  //
  // Examples:
  //   total = 10 → bottomCount = 5 → positions 6–10
  //   total = 15 → bottomCount = 8 → positions 8–15
  //
  // Returns a 1-based finishing position.
  //
  int selectRandomBottomHalfPosition(int punterCount) {
    if (punterCount <= 1) {
      throw ArgumentError("Need at least 2 punters.");
    }

    // Number of entries in the bottom half
    final bottomCount = (punterCount / 2).ceil();

    // First position in the bottom half
    final start = punterCount - bottomCount + 1;

    // Random position in [start .. punterCount]
    return _rng.nextInt(bottomCount) + start;
  }

  // ---------------------------------------------------------------------------
  // STEP 2 — Get the punter currently sitting in a given finishing position
  // ---------------------------------------------------------------------------
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
  PunterSelection resolveTieByBestPlayer(List<PunterSelection> tied) {
    tied.sort((a, b) {
      final aBest = _bestPlayerScore(a);
      final bBest = _bestPlayerScore(b);
      return bBest.compareTo(aBest); // highest wins
    });

    return tied.first;
  }

  int _bestPlayerScore(PunterSelection p) {
    int best = 0;

    for (final pick in p.picks) {
      // FIX: use AF (AFL Fantasy) not "score"
      final score = pick.stats?["AF"] ?? 0;
      if (score > best) best = score;
    }

    return best;
  }

  // ---------------------------------------------------------------------------
  // STEP 4 — Determine the final Friday Pairs winner at round completion
  // ---------------------------------------------------------------------------
  PunterSelection determineFinalWinner(
    List<PunterSelection> sortedSelections,
    int randomPosition,
  ) {
    final index = randomPosition - 1;
    final targetScore = sortedSelections[index].totalScore;

    final tied = sortedSelections
        .where((p) => p.totalScore == targetScore)
        .toList();

    if (tied.length == 1) {
      return tied.first;
    }

    return resolveTieByBestPlayer(tied);
  }
}