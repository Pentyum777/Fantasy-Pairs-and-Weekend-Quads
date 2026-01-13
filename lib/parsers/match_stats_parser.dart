import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/afl_player_match_stats.dart';

class MatchStatsParser {
  /// Fetches live match stats from AFL Match Centre for a given matchId.
  static Future<List<AflPlayerMatchStats>> fetchMatchStats(int matchId) async {
    final url =
        "https://api.afl.com.au/cfs/afl/matchCentre/match/$matchId/playerStats";

    final response = await http.get(Uri.parse(url), headers: {
      "x-media-mis-token": "afl" // public token used by AFL website
    });

    if (response.statusCode != 200) {
      return [];
    }

    final json = jsonDecode(response.body);
    if (json["playerStats"] is! List) {
      return [];
    }

    final List<dynamic> raw = json["playerStats"];

    return raw.map<AflPlayerMatchStats>((p) {
      final player = AflPlayer(
        id: p["player"]["playerId"].toString(),
        name: p["player"]["name"] ?? "",
        club: p["team"] ?? "",
        guernseyNumber: int.tryParse(p["player"]["jumperNumber"]?.toString() ?? "0") ?? 0,
      );

      return AflPlayerMatchStats(
        player: player,
        team: p["team"] ?? "",
        kicks: p["kicks"] ?? 0,
        handballs: p["handballs"] ?? 0,
        disposals: p["disposals"] ?? 0,
        marks: p["marks"] ?? 0,
        tackles: p["tackles"] ?? 0,
        goals: p["goals"] ?? 0,
        behinds: p["behinds"] ?? 0,
        fantasyPoints: p["fantasyPoints"] ?? 0,
      );
    }).toList();
  }
}