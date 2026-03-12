import 'dart:convert';
import 'package:http/http.dart' as http;

class RoundCompletionService {
  RoundCompletionService();   // ⭐ NOT const

  Future<void> saveRoundResults({
    required int season,
    required int round,
    required String gameType,
    required List<Map<String, dynamic>> punters,
  }) async {
    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/saveRoundResults",
    );

    final body = jsonEncode({
      "season": season,
      "round": round,
      "gameType": gameType,
      "punters": punters,
    });

    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
  }

  final Set<int> completedRounds = {};

  bool isCompleted(int roundNumber) => completedRounds.contains(roundNumber);

  void markCompleted(int? round) {
    if (round != null) completedRounds.add(round);
  }
}