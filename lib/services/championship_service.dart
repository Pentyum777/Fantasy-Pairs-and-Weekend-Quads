import '../models/punter_selection.dart';

/// Championship points awarded based on finishing position.
/// Positions beyond 10th receive 0 points.
const Map<int, int> championshipPoints = {
  1: 25,
  2: 18,
  3: 15,
  4: 12,
  5: 10,
  6: 8,
  7: 6,
  8: 4,
  9: 2,
  10: 1,
};

/// A service that aggregates Weekend Quads results into
/// monthly and season-long Championship standings.
class ChampionshipService {
  // ---------------------------------------------------------------------------
  // SINGLETON
  // ---------------------------------------------------------------------------

  static final ChampionshipService _instance = ChampionshipService._internal();

  factory ChampionshipService() => _instance;

  ChampionshipService._internal();

  // ---------------------------------------------------------------------------
  // STORED DATA
  // ---------------------------------------------------------------------------

  /// Stores all Weekend Quads rounds for the season.
  final List<List<PunterSelection>> allRounds = [];

  /// Stores rounds grouped by month.
  final Map<String, List<List<PunterSelection>>> roundsByMonth = {};

  // ---------------------------------------------------------------------------
  // ROUND POINTS
  // ---------------------------------------------------------------------------

  Map<String, int> calculateRoundPoints(List<PunterSelection> selections) {
    if (selections.isEmpty) return {};

    final sorted = [...selections]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final result = <String, int>{};

    for (int i = 0; i < sorted.length; i++) {
      final rank = i + 1;
      final punter = sorted[i].punterName;
      final points = championshipPoints[rank] ?? 0;
      result[punter] = points;
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // AGGREGATION
  // ---------------------------------------------------------------------------

  Map<String, int> calculateAggregateChampionship(
    List<List<PunterSelection>> rounds,
  ) {
    final totals = <String, int>{};

    for (final roundSelections in rounds) {
      final roundPoints = calculateRoundPoints(roundSelections);

      for (final entry in roundPoints.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }

    return totals;
  }

  Map<String, int> calculateSeasonChampionship() {
    return calculateAggregateChampionship(allRounds);
  }

  // ---------------------------------------------------------------------------
  // SORTING
  // ---------------------------------------------------------------------------

  List<MapEntry<String, int>> sortLeaderboard(Map<String, int> totals) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  void addRound(String month, List<PunterSelection> selections) {
    if (selections.isEmpty) return;

    allRounds.add(selections);

    roundsByMonth.putIfAbsent(month, () => []);
    roundsByMonth[month]!.add(selections);
  }

  List<String> get months {
    final list = roundsByMonth.keys.toList()..sort();
    return list;
  }

  List<PunterSelection> get overallLeaderboard {
    if (allRounds.isEmpty) return [];

    final totals = calculateSeasonChampionship();
    final sorted = sortLeaderboard(totals);

    return sorted
        .map(
          (e) => PunterSelection(
            punterNumber: 0,
            punterName: e.key,
            picks: const [],
            liveScore: e.value,
          ),
        )
        .toList();
  }

  List<PunterSelection> monthlyLeaderboard(String month) {
    final rounds = roundsByMonth[month];
    if (rounds == null || rounds.isEmpty) return [];

    final totals = calculateAggregateChampionship(rounds);
    final sorted = sortLeaderboard(totals);

    return sorted
        .map(
          (e) => PunterSelection(
            punterNumber: 0,
            punterName: e.key,
            picks: const [],
            liveScore: e.value,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // MONTH NAME HELPER
  // ---------------------------------------------------------------------------

  String monthName(int m) {
    const names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return names[m - 1];
  }
}