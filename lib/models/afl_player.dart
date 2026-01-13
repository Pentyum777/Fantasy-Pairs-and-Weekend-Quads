class AflPlayer {
  /// Unique identifier used across:
  /// - Player repository
  /// - Live stats mapping
  /// - Punter selections
  /// - Match stats
  final String id;

  /// Display name (e.g. "Marcus Bontempelli")
  final String name;

  /// Club code (e.g. "WB", "COLL", "CARL")
  final String club;

  /// Jumper number
  final int guernseyNumber;

  /// Season year (default 2026)
  final int season;

  /// Live AFL Fantasy score (updated every polling cycle)
  int fantasyScore;

  AflPlayer({
    required this.id,
    required String? name,
    required this.club,
    this.guernseyNumber = 0,
    this.season = 2026,
    this.fantasyScore = 0,
  }) : name = name ?? "";

  /// Full name alias (kept for compatibility)
  String get fullName => name;

  /// Short name used for dropdowns and compact UI
  /// "Marcus Bontempelli" -> "Marcus Bontempelli"
  /// "Nick Daicos" -> "Nick Daicos"
  String get shortName {
    final parts = name.split(" ");
    if (parts.length <= 1) return name;
    return "${parts.first} ${parts.last}";
  }

  /// Fallback player used when no valid player is selected
  static AflPlayer empty() => AflPlayer(
        id: '',
        name: 'Unknown',
        club: '',
        guernseyNumber: 0,
        season: 2026,
        fantasyScore: 0,
      );
}