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

  // -----------------------------
  // JSON Serialization
  // -----------------------------
  factory PunterSelection.fromJson(Map<String, dynamic> json) {
    return PunterSelection(
      punterNumber: json['punterNumber'] as int,
      picks: (json['picks'] as List<dynamic>)
          .map((p) => PlayerPick.fromJson(p))
          .toList(),
      punterName: json['punterName'] ?? "",
      liveScore: json['liveScore'] ?? 0,
      isPrizeWinner: json['isPrizeWinner'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'punterNumber': punterNumber,
      'picks': picks.map((p) => p.toJson()).toList(),
      'punterName': punterName,
      'liveScore': liveScore,
      'isPrizeWinner': isPrizeWinner,
    };
  }

  // -----------------------------
  // Null-safe total score
  // -----------------------------
  int get totalScore {
    int total = 0;
    for (final pick in picks) {
      if (pick.player == null) continue;
      total += (pick.fantasyPoints ?? 0);
    }
    return total;
  }
}