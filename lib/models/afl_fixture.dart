class AflFixture {
  final String roundLabel;
  final int? round;
  final DateTime? date;

  final String homeTeam;
  final String awayTeam;

  final String venue;
  final String? time;
  final String source;

  /// AFL MatchCentre ID (CD_M…)
  final String? matchId;

  /// DFS Australia game ID (7164, 7165, etc.)
  /// ⭐ This is the new field your backend now requires.
  String? dfsId;

  final String? footyInfoUrl;
  final String? footyInfoId;

  final bool isPreseason;

  // Live / result data
  int homeScore;
  int awayScore;
  String? quarterText;
  String timeText;
  String status;

  AflFixture({
    required this.roundLabel,
    required this.round,
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.venue,
    this.time,
    required this.source,
    required this.matchId,
    required this.isPreseason,
    this.footyInfoUrl,
    this.footyInfoId,

    // ⭐ NEW FIELD
    this.dfsId,

    this.homeScore = 0,
    this.awayScore = 0,
    this.quarterText,
    this.timeText = "",
    this.status = "",
  });

/// Returns the actual start DateTime of the fixture by combining
/// the `date` and the `time` string ("7:25pm", "19:25", etc.)
DateTime? get startDateTime {
  if (date == null || (time ?? '').isEmpty) return date;

  try {
    // Normalise time string
    final t = (time ?? '').toLowerCase().replaceAll(" ", "");

    int hour = 0;
    int minute = 0;

    if (t.contains("am") || t.contains("pm")) {
      // Example: "7:25pm"
      final parts = t.replaceAll("am", "").replaceAll("pm", "").split(":");
      hour = int.parse(parts[0]);
      minute = int.parse(parts[1]);

      final isPm = t.contains("pm");
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    } else {
      // Example: "19:25"
      final parts = t.split(":");
      hour = int.parse(parts[0]);
      minute = int.parse(parts[1]);
    }

    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      hour,
      minute,
    );
  } catch (_) {
    return date; // fallback
  }
}

  /// Backwards‑compatible flag used by GameViewScreen
  bool get complete {
    final q = (quarterText ?? "").toLowerCase();
    return q.contains("final") || q == "ft";
  }
}