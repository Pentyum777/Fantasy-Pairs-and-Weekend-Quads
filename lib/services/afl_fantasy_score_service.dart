import 'dart:convert';
import 'package:http/http.dart' as http;

class AFLFantasyService {
  static const String _baseUrl =
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app";

  static Future<List<Map<String, dynamic>>> fetchFantasyStats(String matchId) async {
    final url = Uri.parse("$_baseUrl/fantasy/$matchId");
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception(
        "Backend fantasy fetch failed: ${res.statusCode} — ${res.body}",
      );
    }

    final decoded = jsonDecode(res.body);
    final players = decoded["players"];

    if (players is List) {
      return List<Map<String, dynamic>>.from(players);
    }

    return [];
  }

  static Future<Map<String, dynamic>?> fetchMatchMeta(String matchId) async {
    final url = Uri.parse("$_baseUrl/meta/$matchId");
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception(
        "Backend meta fetch failed: ${res.statusCode} — ${res.body}",
      );
    }

    final decoded = jsonDecode(res.body);
    return decoded["match"] as Map<String, dynamic>?;
  }
}
