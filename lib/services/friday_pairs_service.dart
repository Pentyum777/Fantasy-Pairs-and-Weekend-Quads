import '../models/punter_selection.dart';

class FridayPairsService {
  /// Selects a random winner from the bottom half of the leaderboard.
  ///
  /// The list is sorted ascending by totalScore, meaning the lowest-scoring
  /// punters appear first. The bottom half is then shuffled and the first
  /// element is returned as the winner.
  PunterSelection selectRandomBottomHalf(List<PunterSelection> selections) {
    if (selections.isEmpty) {
      throw ArgumentError("Selections list cannot be empty.");
    }

    final sorted = [...selections]
      ..sort((a, b) => a.totalScore.compareTo(b.totalScore));

    final halfIndex = sorted.length ~/ 2;
    final bottomHalf = sorted.sublist(halfIndex);

    bottomHalf.shuffle();
    return bottomHalf.first;
  }
}