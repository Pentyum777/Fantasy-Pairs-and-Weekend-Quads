import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../models/afl_player.dart';
import '../repositories/player_repository.dart';

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
///
/// Data is persisted in the Postgres `selections` table via
/// the backend. On first open of the Championship screen,
/// [loadFromBackend] is called to restore all completed rounds.
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

  /// Stores all Weekend Quads rounds for the season, keyed by round number.
  /// Using a map prevents duplicates if a round is added twice (live + reload).
  final Map<int, List<PunterSelection>> _roundsByNumber = {};

  /// Stores rounds grouped by month label (e.g. "April").
  final Map<String, List<int>> _roundNumbersByMonth = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ---------------------------------------------------------------------------
  // BACKWARD-COMPATIBLE LIST ACCESSORS
  // ---------------------------------------------------------------------------

  List<List<PunterSelection>> get allRounds =>
      _roundsByNumber.values.toList();

  Map<String, List<List<PunterSelection>>> get roundsByMonth {
    final result = <String, List<List<PunterSelection>>>{};
    for (final entry in _roundNumbersByMonth.entries) {
      result[entry.key] = entry.value
          .map((r) => _roundsByNumber[r] ?? <PunterSelection>[])
          .where((list) => list.isNotEmpty)
          .toList();
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // LOAD FROM BACKEND
  // ---------------------------------------------------------------------------

  /// Fetches all completed weekend_quads rounds for [season] from the backend
  /// and populates the in-memory championship data. Safe to call multiple times
  /// (won't double-add rounds).
  Future<void> loadFromBackend({
    required int season,
    required PlayerRepository playerRepo,
    required String gameType,
  }) async {
    try {
      final url = Uri.https(
        "fantasy-pairs-and-weekend-quads-production.up.railway.app",
        "/completedRounds",
        {
          "season": season.toString(),
          "gameType": gameType,
        },
      );

      final res = await http.get(url);
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body);
      final rounds = json["rounds"] as List<dynamic>? ?? [];

      // ⭐ Clear existing data so we always get a fresh load from the DB.
      // This ensures rounds added in previous sessions are always shown.
      _roundsByNumber.clear();
      _roundNumbersByMonth.clear();

      for (final roundData in rounds) {
        final roundNumber = roundData["round"] as int? ?? 0;

        final punterNames = (roundData["punterNames"] as List<dynamic>? ?? [])
            .map((e) => e?.toString() ?? "")
            .toList();

        final picksJson = roundData["picks"] as List<dynamic>? ?? [];

        final players = await playerRepo.playersForSeason(season);

        final selections = _buildSelections(
          punterNames: punterNames,
          picksJson: picksJson,
          players: players,
          season: season,
        );

        if (selections.isEmpty) continue;

        _addRoundInternal(
          roundNumber: roundNumber,
          selections: selections,
          month: _monthFromRound(roundNumber),
        );
      }

      _loaded = true;
      debugPrint(
        "✅ ChampionshipService: loaded ${_roundsByNumber.length} rounds for season=$season gameType=$gameType",
      );
    } catch (e) {
      debugPrint("❌ ChampionshipService.loadFromBackend failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD SELECTIONS FROM RAW BACKEND DATA
  // ---------------------------------------------------------------------------

  List<PunterSelection> _buildSelections({
    required List<String> punterNames,
    required List<dynamic> picksJson,
    required List<AflPlayer> players,
    required int season,
  }) {
    final result = <PunterSelection>[];

    for (int i = 0; i < punterNames.length; i++) {
      final name = punterNames[i].trim();
      if (name.isEmpty) continue;

      final rowPicks = i < picksJson.length ? picksJson[i] : null;
      final picks = <PlayerPick>[];

      if (rowPicks is List) {
        for (int j = 0; j < rowPicks.length; j++) {
          final snapPick = rowPicks[j];
          if (snapPick is! Map) {
            picks.add(PlayerPick.empty(j + 1));
            continue;
          }

          final pid = (snapPick["playerId"] ?? "").toString().trim();
          final fantasyPoints = snapPick["stats"] is Map
              ? _asInt((snapPick["stats"] as Map)["AF"])
              : 0;

          final player = pid.isEmpty
              ? null
              : players.firstWhere(
                  (p) => p.id == pid,
                  orElse: () => AflPlayer(
                    id: pid,
                    name: "Unknown ($pid)",
                    club: "UNK",
                    season: season,
                  ),
                );

          picks.add(PlayerPick(
            pickNumber: j + 1,
            player: player,
            stats: snapPick["stats"] is Map<String, dynamic>
                ? Map<String, dynamic>.from(snapPick["stats"])
                : <String, dynamic>{},
            fantasyPoints: fantasyPoints,
          ));
        }
      }

      // ⭐ Skip rows with no real player picks (placeholder/empty rows)
      final hasRealPick = picks.any((p) => p.player != null);
      if (!hasRealPick) continue;

      // ⭐ Skip guest punters (name ends with *) and duplicate entries (name ends with " 2")
      if (name.endsWith("*") || name.endsWith(" 2")) continue;

      result.add(PunterSelection(
        punterNumber: i + 1,
        punterName: name,
        picks: picks,
        liveScore: picks.fold(0, (sum, p) => sum + (p.fantasyPoints ?? 0)),
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // ROUND POINTS
  // ---------------------------------------------------------------------------

  Map<String, int> calculateRoundPoints(List<PunterSelection> selections) {
    if (selections.isEmpty) return {};

    // ⭐ Only include punters who actually have at least one player picked
    final active = selections.where((s) =>
      s.punterName.trim().isNotEmpty &&
      s.picks.any((p) => p.player != null)
    ).toList();

    if (active.isEmpty) return {};

    final sorted = [...active]
      ..sort((a, b) {
        // Primary: total score descending
        final totalCmp = b.totalScore.compareTo(a.totalScore);
        if (totalCmp != 0) return totalCmp;

        // Tiebreaker: compare individual pick scores highest-to-lowest
        // Sort each punter's pick scores descending, then compare position by position
        final aScores = a.picks
            .where((p) => p.player != null)
            .map((p) => p.fantasyPoints ?? 0)
            .toList()
          ..sort((x, y) => y.compareTo(x));

        final bScores = b.picks
            .where((p) => p.player != null)
            .map((p) => p.fantasyPoints ?? 0)
            .toList()
          ..sort((x, y) => y.compareTo(x));

        final maxLen = aScores.length > bScores.length
            ? aScores.length
            : bScores.length;

        for (int i = 0; i < maxLen; i++) {
          final aVal = i < aScores.length ? aScores[i] : 0;
          final bVal = i < bScores.length ? bScores[i] : 0;
          final cmp = bVal.compareTo(aVal);
          if (cmp != 0) return cmp;
        }

        // Fully tied — sort alphabetically for stability
        return a.punterName.compareTo(b.punterName);
      });

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

  /// Called when a live round completes during the current session.
  void addRound(String month, List<PunterSelection> selections,
      {int roundNumber = 0}) {
    if (selections.isEmpty) return;

    // Derive a unique key: use roundNumber if provided, else use count
    final key = roundNumber > 0 ? roundNumber : (_roundsByNumber.length + 1);

    _addRoundInternal(
      roundNumber: key,
      selections: selections,
      month: month,
    );
  }

  void _addRoundInternal({
    required int roundNumber,
    required List<PunterSelection> selections,
    required String month,
  }) {
    _roundsByNumber[roundNumber] = selections;

    _roundNumbersByMonth.putIfAbsent(month, () => []);
    if (!_roundNumbersByMonth[month]!.contains(roundNumber)) {
      _roundNumbersByMonth[month]!.add(roundNumber);
    }
  }

  List<String> get months {
    final list = _roundNumbersByMonth.keys.toList()..sort();
    return list;
  }

  List<PunterSelection> get overallLeaderboard {
    if (_roundsByNumber.isEmpty) return [];

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
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Maps AFL round numbers to Monthly Medal labels (blocks of 4 rounds).
  /// Medal 1: Rounds 1-4, Medal 2: Rounds 5-8, ..., Medal 6: Rounds 21-24
  String _monthFromRound(int round) {
    if (round <= 4) return "Medal 1";
    if (round <= 8) return "Medal 2";
    if (round <= 12) return "Medal 3";
    if (round <= 16) return "Medal 4";
    if (round <= 20) return "Medal 5";
    return "Medal 6";
  }

  String monthName(int m) {
    const names = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December",
    ];
    return names[m - 1];
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }

  // ---------------------------------------------------------------------------
  // POINTS TABLE — per punter per round
  // ---------------------------------------------------------------------------

  /// Returns sorted round numbers (ascending) for a given set of round numbers,
  /// or all rounds if null.
  List<int> sortedRoundNumbers({List<int>? roundNumbers}) {
    final nums = roundNumbers ?? _roundsByNumber.keys.toList();
    return nums..sort();
  }

  /// Returns the round numbers for a given month.
  List<int> roundNumbersForSeries(String series) {
    return List<int>.from(_roundNumbersByMonth[series] ?? [])..sort();
  }

  // Alias for backward compatibility
  List<int> roundNumbersForMonth(String month) => roundNumbersForSeries(month);

  /// Builds a points table: punterName -> {roundNumber -> championshipPoints}.
  /// If [roundNumbers] is provided, only those rounds are included.
  /// Punters are sorted by total descending.
  List<PunterRoundPoints> buildPointsTable({List<int>? roundNumbers}) {
    final rounds = sortedRoundNumbers(roundNumbers: roundNumbers);

    // Build: punter -> {round -> points}
    final Map<String, Map<int, int>> table = {};

    for (final rnd in rounds) {
      final selections = _roundsByNumber[rnd];
      if (selections == null || selections.isEmpty) continue;

      final roundPoints = calculateRoundPoints(selections);

      for (final entry in roundPoints.entries) {
        table.putIfAbsent(entry.key, () => {})[rnd] = entry.value;
      }
    }

    // Build rows sorted by total descending
    final rows = table.entries.map((e) {
      final total = e.value.values.fold(0, (sum, v) => sum + v);
      return PunterRoundPoints(
        punterName: e.key,
        pointsByRound: e.value,
        total: total,
        rounds: rounds,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return rows;
  }

}
// ---------------------------------------------------------------------------
// DATA CLASS for points table rows
// ---------------------------------------------------------------------------
class PunterRoundPoints {
  final String punterName;
  final Map<int, int> pointsByRound;
  final int total;
  final List<int> rounds;

  const PunterRoundPoints({
    required this.punterName,
    required this.pointsByRound,
    required this.total,
    required this.rounds,
  });

  int pointsForRound(int round) => pointsByRound[round] ?? 0;
}