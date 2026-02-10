import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const slugs = <String>[
    // Premiership season
    "7164", "7165", "7169", "7166", "7167", "7170", "7168", "7171", "7163",
  ];

  print("slug,matchId,homeTeam,awayTeam,startTime,venue");

  for (final slug in slugs) {
    final url = "https://www.afl.com.au/afl/matches/$slug";

    try {
      final details = await _fetchMatchDetails(slug, url);

      print([
        slug,
        details.matchId ?? "",
        _csv(details.homeTeam),
        _csv(details.awayTeam),
        details.startTime ?? "",
        _csv(details.venue),
      ].join(","));
    } catch (e) {
      print("$slug,ERROR: $e,,,,");
    }
  }
}

String _csv(String? value) {
  if (value == null) return "";
  if (value.contains(',') || value.contains('"')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

class MatchDetails {
  final String? matchId;
  final String? homeTeam;
  final String? awayTeam;
  final String? startTime;
  final String? venue;

  MatchDetails({
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    required this.startTime,
    required this.venue,
  });
}

Future<MatchDetails> _fetchMatchDetails(String slug, String url) async {
  final response = await http.get(
    Uri.parse(url),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  );

  if (response.statusCode != 200) {
    throw Exception("HTTP ${response.statusCode}");
  }

  final body = utf8.decode(response.bodyBytes);

  // Extract match ID (CD_M...)
  final matchIdRegex = RegExp(r'CD_M\d+');
  final matchId = matchIdRegex.firstMatch(body)?.group(0);

  // Extract home/away/venue/startTime from embedded JSON if present
  String? homeTeam;
  String? awayTeam;
  String? startTime;
  String? venue;

  final jsonRegex =
      RegExp(r'__INITIAL_STATE__\s*=\s*({.*?});', dotAll: true);
  final jsonMatch = jsonRegex.firstMatch(body);

  if (jsonMatch != null) {
    try {
      final jsonText = jsonMatch.group(1)!;
      final state = jsonDecode(jsonText);

      dynamic matchData;

      if (state is Map<String, dynamic>) {
        matchData = state['match'] ??
            state['matchCentre'] ??
            state['matchDetail'] ??
            state['matchData'];
      }

      if (matchData is Map<String, dynamic>) {
        homeTeam = (matchData['homeTeamName'] ??
                matchData['homeTeam']?['teamName'] ??
                matchData['homeTeam']?['name'])
            ?.toString();

        awayTeam = (matchData['awayTeamName'] ??
                matchData['awayTeam']?['teamName'] ??
                matchData['awayTeam']?['name'])
            ?.toString();

        startTime = (matchData['startTime'] ??
                matchData['startDateTime'] ??
                matchData['start']?['dateTime'])
            ?.toString();

        venue = (matchData['venueName'] ??
                matchData['venue']?['name'] ??
                matchData['venue']?['shortName'])
            ?.toString();
      }
    } catch (_) {}
  }

  // Fallback regex extraction
  homeTeam ??=
      RegExp(r'"homeTeamName"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
  awayTeam ??=
      RegExp(r'"awayTeamName"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
  venue ??=
      RegExp(r'"venueName"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
  startTime ??=
      RegExp(r'"startTime"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);

  return MatchDetails(
    matchId: matchId,
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    startTime: startTime,
    venue: venue,
  );
}