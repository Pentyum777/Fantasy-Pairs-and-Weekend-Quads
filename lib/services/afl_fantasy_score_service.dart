import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class AFLFantasyService {
  static const String baseUrl =
      'https://fantasy-pairs-and-weekend-quads-production.up.railway.app';

  /// ⭐ Loaded at startup
  static Map<String, int> dfsMap = {};

  /// ⭐ Call this once at app startup (main.dart)
  static Future<void> loadDfsMap() async {
    try {
      final jsonString = await rootBundle.loadString('assets/dfs_map.json');
      final decoded = jsonDecode(jsonString);

      if (decoded is Map<String, dynamic>) {
        dfsMap = decoded.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0));
        print("DFS MAP LOADED: ${dfsMap.length} entries");
      }
    } catch (e) {
      print("❌ Failed to load dfs_map.json: $e");
      dfsMap = {};
    }
  }

  static Future<Map<String, dynamic>> fetchFantasyMatchPayload(
    String matchId,
  ) async {
    final uri = Uri.parse('$baseUrl/fantasy/$matchId');

    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (e) {
      return {};
    }

    if (resp.statusCode != 200 || resp.body.isEmpty) {
      return {};
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      return {};
    }

    if (decoded is! Map<String, dynamic>) {
      return {};
    }

    return decoded;
  }
}