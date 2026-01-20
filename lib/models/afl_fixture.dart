class AflFixture {
  /// Round label (e.g. "Round 1", "Opening Round", "Pre-Season")
  final String roundLabel;

  /// Numeric round number (0 = Opening Round, 1..24 = normal rounds)
  final int? round;

  /// Parsed match date (nullable for TBC/TBA)
  final DateTime? date;

  /// Home and away team codes (e.g. "CARL", "COLL")
  final String homeTeam;
  final String awayTeam;

  /// Venue name (e.g. "MCG", "Marvel Stadium")
  final String venue;

  /// Raw time text from Excel (e.g. "7.30pm")
  final String time;

  /// Source URL (AFL.com.au match page)
  final String source;

  /// AFL Match ID (CD_M… string)
  final String? matchId;

  /// Whether this is a pre-season match
  final bool isPreseason;

  /// Live or final scores (populated later)
  int? homeGoals;
  int? homeBehinds;
  int? homeScore;

  int? awayGoals;
  int? awayBehinds;
  int? awayScore;

  /// Whether the match is complete
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
    required this.isPreseason,
    this.homeGoals,
    this.homeBehinds,
    this.homeScore,
    this.awayGoals,
    this.awayBehinds,
    this.awayScore,
    this.complete = false,
  });

  /// Safe fallback fixture used when a lookup fails
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
        isPreseason: false,
        homeGoals: null,
        homeBehinds: null,
        homeScore: null,
        awayGoals: null,
        awayBehinds: null,
        awayScore: null,
        complete: false,
      );
}