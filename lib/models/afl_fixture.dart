class AflFixture {
  final String roundLabel; // e.g. "OPENING ROUND" or "Round 1"
  final int round;         // numeric round used in selectors
  final DateTime date;
  final String homeTeam;
  final String awayTeam;
  final String venue;
  final String time;       // raw time string from the sheet, e.g. "7.30pm"
  final String source;     // GAME DATA SOURCE (URL)

  AflFixture({
    required this.roundLabel,
    required this.round,
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.venue,
    required this.time,
    required this.source,
  });
}