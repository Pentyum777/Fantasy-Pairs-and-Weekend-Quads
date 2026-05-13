import 'player_pick.dart';
import 'afl_player.dart';

class PunterSelection {
  final int punterNumber;
  final List<PlayerPick> picks;

  String punterName;
  int liveScore;
 bool isPrizeWinner;

bool isCompletedPunter = false;

 PunterSelection({
    required this.punterNumber,
    required this.picks,
    this.punterName = "",
    this.liveScore = 0,
    this.isPrizeWinner = false,
  });

  // ------------------------------------------------------------
  // NEW: Create a clean, empty punter row (P26, P27, etc.)
  // ------------------------------------------------------------
  factory PunterSelection.empty({
    required int punterNumber,
    required int playersPerPunter,
  }) {
    return PunterSelection(
      punterNumber: punterNumber,
      punterName: "",
      picks: List.generate(
        playersPerPunter,
        (i) => PlayerPick(
          pickNumber: i + 1,
          player: null,
          stats: null,
        ),
      ),
      liveScore: 0,
      isPrizeWinner: false,
    );
  }

  // ------------------------------------------------------------
  // JSON Serialization
  // ------------------------------------------------------------
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

  // ------------------------------------------------------------
  // Null-safe total score
  // ------------------------------------------------------------
  int get totalScore {
    int total = 0;
    for (final pick in picks) {
      if (pick.player == null) continue;
      total += (pick.fantasyPoints ?? 0);
    }
    return total;
  }

  /// Returns the sum of each selected player's season average fantasy score.
  int avgScore(List<AflPlayer> allPlayers) {
    final avgMap = <String, int>{
      for (final p in allPlayers) p.id: p.fantasyScore,
    };
    int total = 0;
    for (final pick in picks) {
      final player = pick.player;
      if (player == null) continue;
      total += avgMap[player.id] ?? player.fantasyScore;
    }
    return total;
  }
}