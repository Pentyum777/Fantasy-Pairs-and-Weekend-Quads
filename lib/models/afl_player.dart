class AflPlayer {
  final String id;          // Stable identity (CD_Ixxxxx)
  final String name;        // Full or short name
  final String club;        // Normalized club code
  final int guernseyNumber;
  final int season;

  /// Live fantasy score (runtime only)
  int fantasyScore;

  AflPlayer({
    required String id,
    required String? name,
    required String? club,
    this.guernseyNumber = 0,
    this.season = 2026,
    this.fantasyScore = 0,
  })  : id = id.trim().isEmpty ? "UNKNOWN" : id.trim(),
        name = (name ?? "").trim(),
        club = (club ?? "").trim();

  String get fullName => name;

  String get shortName {
    if (name.isEmpty) return "Unknown";
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return parts.first;
    return "${parts.first} ${parts.last}";
  }

  bool get isUnknown => id == "UNKNOWN" || name == "Unknown";

  static AflPlayer empty() => AflPlayer(
        id: "UNKNOWN",
        name: "Unknown",
        club: "",
        guernseyNumber: 0,
        season: 2026,
        fantasyScore: 0,
      );

  factory AflPlayer.fromJson(Map<String, dynamic> json) {
    final rawId = json['playerId'] ?? json['id'] ?? "";
    final rawName = json['playerName'] ?? json['name'] ?? json['fullName'] ?? "";
    final rawClub = json['teamAbbr'] ?? json['club'] ?? json['team'] ?? "";

    return AflPlayer(
      id: rawId.toString(),
      name: rawName.toString(),
      club: rawClub.toString(),
      guernseyNumber: _asInt(json['guernseyNumber'] ?? json['number']),
      season: _asInt(json['season']) == 0 ? 2026 : _asInt(json['season']),
      fantasyScore: _asInt(json['fantasyScore']),
    );
  }

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

  AflPlayer copyWith({
    String? id,
    String? name,
    String? club,
    int? guernseyNumber,
    int? season,
    int? fantasyScore,
  }) {
    return AflPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      club: club ?? this.club,
      guernseyNumber: guernseyNumber ?? this.guernseyNumber,
      season: season ?? this.season,
      fantasyScore: fantasyScore ?? this.fantasyScore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AflPlayer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }
}