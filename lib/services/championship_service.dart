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

  /// Maps AFL round numbers to month names (approximate — adjust if needed).
  String _monthFromRound(int round) {
    if (round <= 3) return "March";
    if (round <= 7) return "April";
    if (round <= 11) return "May";
    if (round <= 15) return "June";
    if (round <= 19) return "July";
    if (round <= 23) return "August";
    return "September";
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
}