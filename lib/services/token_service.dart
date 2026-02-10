import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TokenService {
  static const _tokenFile = 'token.json';

  static Future<String> getToken() async {
    // 1. Try loading existing token
    final existing = await _loadToken();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    // 2. Otherwise fetch a new one
    final fresh = await _fetchNewToken();
    await _saveToken(fresh);
    return fresh;
  }

  static Future<String?> _loadToken() async {
    final file = File(_tokenFile);
    if (!file.existsSync()) return null;

    final json = jsonDecode(await file.readAsString());
    return json['authHeader']?.toString() ?? '';
  }

  static Future<void> _saveToken(String token) async {
    final file = File(_tokenFile);
    await file.writeAsString(jsonEncode({'authHeader': token}));
  }

  static Future<String> _fetchNewToken() async {
  final url = Uri.parse("https://api.afl.com.au/cfs/afl/WMCTok");

  final res = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Origin": "https://www.afl.com.au",
      "Referer": "https://www.afl.com.au/",
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "x-api-key": "aflwebclientid",
    },
    body: jsonEncode({}),
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to refresh AFL token (status ${res.statusCode})");
  }

  final data = jsonDecode(res.body);
  final token = (data['token'] ?? data['authHeader'])?.toString();

  if (token == null || token.isEmpty) {
    throw Exception("AFL token response missing token field");
  }

  return "Bearer $token";
}
}