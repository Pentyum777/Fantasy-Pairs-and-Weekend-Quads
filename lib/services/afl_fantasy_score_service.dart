import 'dart:convert';
import 'package:http/http.dart' as http;

class AFLFantasyService {
  // Your real Railway backend root
  static const String baseUrl =
      'https://fantasy-pairs-and-weekend-quads-production.up.railway.app';

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
    throw Exception('Backend returned ${resp.statusCode} for $matchId');
  }

  dynamic decoded;
  try {
    decoded = json.decode(resp.body);
  } catch (e) {
    throw Exception('Backend returned invalid JSON for $matchId');
  }

  if (decoded == null || decoded is! Map<String, dynamic>) {
    throw Exception('Fantasy payload was not a JSON object for $matchId');
  }

  return decoded;
}
}