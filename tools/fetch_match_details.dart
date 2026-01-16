import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const slugs = <String>[
    // Premiership season
    "8041","8042","8040","8043","8046","8045","8044","8047","8049","8048",
    "8051","8056","8055","8050","8052","8053","8054","8059","8057","8058",
    "8060","8062","8064","8061","8065","8063","8071","8075","8066","8067",
    "8069","8070","8068","8074","8073","8077","8072","8076","8078","8079",
    "8080","8081","8082","8084","8088","8083","8085","8086","8087","8089",
    "8092","8090","8091","8094","8093","8097","8095","8098","8096","8105",
    "8100","8099","8101","8104","8102","8103","8109","8108","8106","8114",
    "8107","8111","8113","8116","8110","8112","8115","8120","8119","8122",
    "8118","8117","8121","8125","8124","8129","8123","8126","8127","8128",
    "8130","8131","8133","8134","8132","8137","8135","8136","8138","8139",
    "8140","8141","8142","8143","8144","8145","8148","8146","8147","8150",
    "8149","8152","8151","8153","8154","8158","8156","8155","8157","8159",
    "8170","8160","8161","8164","8162","8163","8165","8166","8168","8167",
    "8174","8172","8169","8179","8171","8173","8178","8180","8187","8175",
    "8176","8177","8181","8183","8186","8184","8182","8192","8185","8188",
    "8193","8190","8189","8194","8191","8195","8200","8197","8196","8199",
    "8198","8202","8203","8201","8208","8206","8207","8205","8204","8216",
    "8210","8209","8213","8211","8215","8212","8214","8217","8221","8218",
    "8223","8219","8228","8220","8225","8222","8224","8230","8227","8229",
    "8226","8233","8244","8231","8238","8232","8234","8237","8239","8240",
    "8235","8246","8236","8242","8245","8243","8241",

    // Pre-season
    "8251","8250","8252","8255","8253","8254","8256","8257","8258",
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
        homeTeam = matchData['homeTeamName'] ??
            matchData['homeTeam']?['teamName'] ??
            matchData['homeTeam']?['name'];

        awayTeam = matchData['awayTeamName'] ??
            matchData['awayTeam']?['teamName'] ??
            matchData['awayTeam']?['name'];

        startTime = matchData['startTime'] ??
            matchData['startDateTime'] ??
            matchData['start']?['dateTime'];

        venue = matchData['venueName'] ??
            matchData['venue']?['name'] ??
            matchData['venue']?['shortName'];
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