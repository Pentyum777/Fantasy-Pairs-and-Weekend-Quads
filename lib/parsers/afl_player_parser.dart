import '../models/afl_player.dart';

class AflPlayerParser {
  /// Expects [json] to be a List<dynamic> of player maps.
  static List<AflPlayer> parse(dynamic json) {
    if (json is! List) return [];

    return json.map<AflPlayer>((raw) {
      final map = raw as Map<String, dynamic>;

      return AflPlayer(
        id: (map['id'] ?? '').toString(),
        name: map['name'] ?? map['fullName'] ?? '',
        club: map['club'] ?? '',
        guernseyNumber: map['guernseyNumber'] is int
            ? map['guernseyNumber'] as int
            : int.tryParse(map['guernseyNumber']?.toString() ?? '') ?? 0,
        season: map['season'] is int
            ? map['season'] as int
            : int.tryParse(map['season']?.toString() ?? '') ?? 2026,
        fantasyScore: map['fantasyScore'] is int
            ? map['fantasyScore'] as int
            : int.tryParse(map['fantasyScore']?.toString() ?? '') ?? 0,
      );
    }).toList();
  }
}