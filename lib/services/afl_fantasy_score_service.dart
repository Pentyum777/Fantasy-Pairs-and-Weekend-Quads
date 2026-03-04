import 'dart:convert';
import 'package:http/http.dart' as http;

class AFLFantasyService {
  static const String baseUrl =
      'https://fantasy-pairs-and-weekend-quads-production.up.railway.app';

  /// Returns a safe fantasy payload map or an empty map on failure.
  static Future<Map<String, dynamic>> fetchFantasyMatchPayload(
    String matchId,
  ) async {
    final uri = Uri.parse('$baseUrl/fantasy/$matchId');

    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (e) {
      // Network failure → return empty payload
      return {};
    }

    // Reject empty or non-200 responses
    if (resp.statusCode != 200 || resp.body.isEmpty) {
      return {};
    }

    // Safe JSON decode (prevents ga0)
    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      // HTML or corrupted JSON → avoid crash
      return {};
    }

    // Must be a JSON object
    if (decoded is! Map<String, dynamic>) {
      return {};
    }

    return decoded;
  }
}