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

/// Generic OneDrive file downloader
///
/// [filePath] must be in the format:
///   /me/drive/root:/<folder>/<subfolder>/<filename>:/content
///
/// Example:
///   /me/drive/root:/Documents/AFL/afl_players_2026.xlsx:/content
Future<Uint8List?> downloadOneDriveFile(
    String accessToken, String filePath) async {
  final url = Uri.parse("$graphBase$filePath");

  final response = await http.get(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
    },
  );

  if (response.statusCode == 200) {
    print("File downloaded successfully: $filePath");
    return response.bodyBytes;
  } else {
    print("Failed to download file: ${response.statusCode}");
    print(response.body);
    return null;
  }
}

/// Download AFL Players Excel file
///
/// Update the path below to match your actual OneDrive folder structure.
Future<Uint8List?> downloadAflPlayersExcel(String accessToken) async {
  const String filePath =
      "/me/drive/root:/Documents/AFL/afl_players_2026.xlsx:/content";

  return downloadOneDriveFile(accessToken, filePath);
}

/// Download AFL Fixtures Excel file
///
/// Update the path below to match your actual OneDrive folder structure.
Future<Uint8List?> downloadAflFixturesExcel(String accessToken) async {
  const String filePath =
      "/me/drive/root:/Documents/AFL/afl_fixtures_2026.xlsx:/content";

  return downloadOneDriveFile(accessToken, filePath);
}