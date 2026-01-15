import 'player_pick.dart';

class PunterSelection {
  final int punterNumber;
  final List<PlayerPick> picks;

  String punterName;
  int liveScore;

  // ⭐ NEW FIELD — used by Friday Pairs
  bool isPrizeWinner;

  PunterSelection({
    required this.punterNumber,
    required this.picks,
    this.punterName = "",
    this.liveScore = 0,
    this.isPrizeWinner = false, // default
  });

  // Championship placeholder constructor
  factory PunterSelection.placeholder({
    required String name,
    required int totalScore,
  }) {
    return PunterSelection(
      punterNumber: -1,   // not used for Championship
      picks: const [],    // Championship doesn't use picks
      punterName: name,
      liveScore: totalScore,
      isPrizeWinner: false,
    );
  }

  int get totalScore {
    return picks.fold(0, (sum, p) => sum + (p.score));
  }
}