class AflFixture {
  /// Round label as provided by Squiggle (e.g. "Round 1", "Finals Week 2")
  final String roundLabel;

  /// Numeric round number (Squiggle provides this directly)
  final int round;

  /// Parsed match date (nullable because Squiggle sometimes omits it)
  final DateTime? date;

  /// Home and away team codes (e.g. "CARL", "COLL")
  final String homeTeam;
  final String awayTeam;

  /// Venue name (e.g. "MCG", "Marvel Stadium")
  final String venue;

  /// Time zone string from Squiggle (e.g. "AEDT")
  final String time;

  /// Always "squiggle" in your new pipeline
  final String source;

  /// Squiggle match ID — also used for AFL Match Centre live stats
  final int? matchId;

  /// Live or final scores
  int? homeGoals;
  int? homeBehinds;
  int? homeScore;

  int? awayGoals;
  int? awayBehinds;
  int? awayScore;

  /// Whether the match is complete (Squiggle uses 100 for complete)
  bool complete;

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
    this.homeGoals,
    this.homeBehinds,
    this.homeScore,
    this.awayGoals,
    this.awayBehinds,
    this.awayScore,
    this.complete = false,
  });

  /// Safe fallback fixture used when a matchId lookup fails
  static AflFixture empty() => AflFixture(
        roundLabel: "",
        round: 0,
        date: null,
        homeTeam: "",
        awayTeam: "",
        venue: "",
        time: "",
        source: "empty",
        matchId: null,
        homeGoals: null,
        homeBehinds: null,
        homeScore: null,
        awayGoals: null,
        awayBehinds: null,
        awayScore: null,
        complete: false,
      );
}