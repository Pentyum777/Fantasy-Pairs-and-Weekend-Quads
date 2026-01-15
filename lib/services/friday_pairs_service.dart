import '../models/punter_selection.dart';

class FridayPairsService {
  /// Select a random winner from the bottom half of the leaderboard.
  PunterSelection selectRandomBottomHalf(List<PunterSelection> selections) {
    final sorted = [...selections]
      ..sort((a, b) => a.totalScore.compareTo(b.totalScore));

    final halfIndex = sorted.length ~/ 2;
    final bottomHalf = sorted.sublist(halfIndex);

    bottomHalf.shuffle();
    return bottomHalf.first;
  }
}