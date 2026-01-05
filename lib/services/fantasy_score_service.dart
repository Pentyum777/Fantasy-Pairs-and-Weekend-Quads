import 'package:http/http.dart' as http;
import 'dart:convert';

class FantasyScoreService {
  /// Fetches live fantasy scores from an AFL.com.au match URL.
  /// Returns a map: { "Player Name" : fantasyPoints }
  Future<Map<String, int>> fetchScores(String url) async {
    try {
      if (url.isEmpty) return {};

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print("Fantasy fetch failed: ${response.statusCode}");
        return {};
      }

      final body = response.body;

      // NOTE: This is a placeholder approach.
      // You will likely need to inspect the actual AFL.com.au page
      // and adjust this extraction accordingly.
      final start = body.indexOf('"playerStats":');
      if (start == -1) {
        print("Fantasy JSON not found in page");
        return {};
      }

      final end = body.indexOf(']', start);
      if (end == -1) {
        print("Fantasy JSON closing bracket not found");
        return {};
      }

      final jsonString = body.substring(start + 14, end + 1);

      final decoded = json.decode(jsonString);

      final scores = <String, int>{};

      if (decoded is List) {
        for (var player in decoded) {
          try {
            final name = player["player"]["name"] ?? "";
            final points = player["fantasyPoints"] ?? 0;
            if (name is String && points is int) {
              scores[name] = points;
            }
          } catch (_) {
            // Skip malformed entries
          }
        }
      }

      print("Fetched fantasy scores for ${scores.length} players");
      return scores;
    } catch (e) {
      print("Fantasy fetch error: $e");
      return {};
    }
  }
}