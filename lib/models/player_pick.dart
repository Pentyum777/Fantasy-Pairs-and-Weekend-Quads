import 'afl_player.dart';

class PlayerPick {
  final int pickNumber;
  AflPlayer? player;

  Map<String, dynamic>? stats;
  int? fantasyPoints;

  PlayerPick({
    required this.pickNumber,
    this.player,
    this.stats,
    this.fantasyPoints,
  });

  // -----------------------------
  // JSON Serialization
  // -----------------------------
  factory PlayerPick.fromJson(Map<String, dynamic> json) {
    return PlayerPick(
      pickNumber: json['pickNumber'] as int,
      player: json['player'] != null
          ? AflPlayer.fromJson(json['player'])
          : null,
      stats: json['stats'] != null
          ? Map<String, dynamic>.from(json['stats'])
          : null,
      fantasyPoints: json['fantasyPoints'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pickNumber': pickNumber,
      'player': player?.toJson(),
      'stats': stats,
      'fantasyPoints': fantasyPoints,
    };
  }

  // -----------------------------
  // UI getters (null-safe)
  // -----------------------------
  int get kicks => _int("K");
  int get handballs => _int("HB");
  int get marks => _int("M");
  int get tackles => _int("T");
  int get goals => _int("G");
  int get behinds => _int("B");

  int get hitouts => _int("HO");
  int get freesFor => _int("FF");
  int get freesAgainst => _int("FA");
  int get timeOnGroundPercentage => _int("TOG");

  int _int(String key) {
    final v = stats?[key];
    if (v is int) return v;
    if (v is double) return v.round();
    return 0;
  }
}