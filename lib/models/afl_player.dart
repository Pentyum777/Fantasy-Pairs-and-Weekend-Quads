class AflPlayer {
  final String id;
  final String name;
  final String club;
  final int guernseyNumber;
  final int season;

  /// Live fantasy score (updated externally)
  int fantasyScore;

  AflPlayer({
    required this.id,
    required String? name,
    required String? club,
    this.guernseyNumber = 0,
    this.season = 2026,
    this.fantasyScore = 0,
  })  : name = (name ?? "").trim(),
        club = (club ?? "").trim();

  String get fullName => name;

  String get shortName {
    if (name.isEmpty) return "Unknown";
    final parts = name.split(" ");
    if (parts.length <= 1) return name;
    return "${parts.first} ${parts.last}";
  }

  static AflPlayer empty() => AflPlayer(
        id: '',
        name: 'Unknown',
        club: '',
        guernseyNumber: 0,
        season: 2026,
        fantasyScore: 0,
      );

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "club": club,
      "guernseyNumber": guernseyNumber,
      "season": season,
      "fantasyScore": fantasyScore,
    };
  }
}