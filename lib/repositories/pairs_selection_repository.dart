import '../models/afl_player.dart';

class PairsSelectionRepository {
  final List<List<AflPlayer>> pairs = [];

  bool isPlayerUsed(AflPlayer p) {
    return pairs.any((pair) => pair.contains(p));
  }

  bool addPair(AflPlayer p1, AflPlayer p2) {
    if (isPlayerUsed(p1) || isPlayerUsed(p2)) return false;

    pairs.add([p1, p2]);
    return true;
  }

  void removePair(int index) {
    pairs.removeAt(index);
  }
}