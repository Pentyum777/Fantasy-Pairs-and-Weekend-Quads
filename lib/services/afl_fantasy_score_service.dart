import 'dart:convert';
import 'package:http/http.dart' as http;

class AFLFantasyService {
  static const String baseUrl = 'https://your-backend-url/api';

  /// Returns:
  /// {
  ///   "matchId": "...",
  ///   "homeScore": 88,
  ///   "awayScore": 74,
  ///   "quarter": "Final",
  ///   "clock": "FT",
  ///   "players": [ ... ]
  /// }
  static Future<Map<String, dynamic>> fetchFantasyMatchPayload(
    String matchId,
  ) async {
    final uri = Uri.parse('$baseUrl/fantasy/$matchId');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load fantasy payload for $matchId');
    }

    final decoded = json.decode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected fantasy payload shape');
    }

    return decoded;
  }
}