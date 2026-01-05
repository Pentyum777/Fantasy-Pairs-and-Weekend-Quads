class AflFixture {
  final int round;
  final DateTime date;
  final String homeTeam;
  final String awayTeam;
  final String venue;
  final String time;
  final String source; // AFL.com.au URL for fantasy data

  AflFixture({
    required this.round,
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.venue,
    required this.time,
    required this.source,
  });
}