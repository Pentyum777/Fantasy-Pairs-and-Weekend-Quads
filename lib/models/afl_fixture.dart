class AflFixture {
  final String roundLabel;
  final int? round;
  final DateTime? date;

  final String homeTeam;
  final String awayTeam;

  final String venue;
  final String time;
  final String source;
  final String? matchId;

  final String? footyInfoUrl;
  final String? footyInfoId;

  final bool isPreseason;

  // Live / result data
  int homeScore;
  int awayScore;
  String quarterText;
  String timeText;
  String status;   // ⭐ NEW FIELD

  AflFixture({
    required this.roundLabel,
    required this.round,
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.venue,
    required this.time,
    required this.source,
    required this.matchId,
    required this.isPreseason,
    this.footyInfoUrl,
    this.footyInfoId,
    this.homeScore = 0,
    this.awayScore = 0,
    this.quarterText = "",
    this.timeText = "",
    this.status = "",   // ⭐ NEW DEFAULT
  });

  /// Backwards‑compatible flag used by GameViewScreen
  bool get complete {
    final q = quarterText.toLowerCase();
    return q.contains("final") || q == "ft";
  }
}