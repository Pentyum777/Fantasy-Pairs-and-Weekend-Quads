import 'player_pick.dart';

class PunterSelection {
  final int punterNumber;
  final List<PlayerPick> picks;

  String punterName;
  int liveScore;
  bool isPrizeWinner;

  PunterSelection({
    required this.punterNumber,
    required this.picks,
    this.punterName = "",
    this.liveScore = 0,
    this.isPrizeWinner = false,
  });

  factory PunterSelection.placeholder({
    required String name,
    required int totalScore,
  }) {
    return PunterSelection(
      punterNumber: -1,
      picks: const [],
      punterName: name,
      liveScore: totalScore,
      isPrizeWinner: false,
    );
  }

  int get totalScore {
    int total = 0;
    for (final pick in picks) {
      if (pick.player == null) continue;
      total += pick.fantasyPoints;
    }
    return total;
  }
}