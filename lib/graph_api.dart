import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Microsoft Graph base URL
const String graphBase = "https://graph.microsoft.com/v1.0";

/// Get the signed‑in user's profile
Future<Map<String, dynamic>> getUserProfile(String accessToken) async {
  final url = Uri.parse("$graphBase/me");

  final response = await http.get(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    print("Failed to load profile: ${response.statusCode}");
    return {};
  }
}

/// Download the AFL Players Excel file from OneDrive
///
/// Update the path below to match your OneDrive file location.
/// Example:
///   /me/drive/root:/Documents/AFL_Players_2026.xlsx:/content
Future<Uint8List?> downloadFantasyExcel(String accessToken) async {
  // TODO: Update this path to match your actual OneDrive file location
  const String filePath =
      "/me/drive/root:/Documents/AFL_Players_2026.xlsx:/content";

  final url = Uri.parse("$graphBase$filePath");

  final response = await http.get(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
    },
  );

  if (response.statusCode == 200) {
    print("Excel file downloaded successfully.");
    return response.bodyBytes;
  } else {
    print("Failed to download Excel file: ${response.statusCode}");
    print(response.body);
    return null;
  }
}