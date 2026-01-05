class AflPlayer {
  final String name;
  final String club;
  final int guernseyNumber;
  final int season;
  int liveScore;

  AflPlayer({
    String? name,
    String? fullName,
    required this.club,
    this.guernseyNumber = 0,
    this.season = 2026,
    this.liveScore = 0,
  }) : name = name ?? fullName ?? "";

  String get fullName => name;
}