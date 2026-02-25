import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../helpers/round_helper.dart';
import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/punter_score_service.dart';
import '../services/championship_service.dart';
import '../services/round_completion_service.dart';
import '../services/user_role_service.dart';
import '../services/friday_pairs_service.dart';

import '../models/afl_fixture.dart';
import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import '../models/afl_player_match_stats.dart';

import '../widgets/punter_selection_table.dart';
import '../widgets/stats_overlay.dart';
import '../widgets/team_logo.dart';
import '../widgets/leaderboard_panel.dart';
import '../widgets/background_container.dart';

import '../parsers/match_stats_parser.dart';
import '../constants/ui_dimensions.dart';

class GameViewScreen extends StatefulWidget {
  final int season;
  final int? round;
  final String gameType;
  final List<PunterSelection> selections;
  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;
  final ChampionshipService championshipService;
  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;
  final List<String>? selectedFixtureIds;
  final List<AflPlayer>? overridePlayers;
  

  const GameViewScreen({
    super.key,
    required this.season,
    required this.round,
    required this.gameType,
    required this.selections,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.fantasyService,
    required this.championshipService,
    required this.roundCompletionService,
    required this.userRoleService,
    this.selectedFixtureIds,
    this.overridePlayers,
  });

  @override
  State<GameViewScreen> createState() => _GameViewScreenState();
}

class _GameViewScreenState extends State<GameViewScreen> {
  int _visiblePunterCount = 10;
  bool _isCompleted = false;

  bool _isSubmitted = false;
  bool _leaderboardCollapsed = false;
  bool _fixturesCollapsed = false;
  bool _controlsCollapsed = false;

  final GlobalKey _punterTableKey = GlobalKey();

  AflFixture? _selectedFixture;
  Timer? _liveTimer;
  final ScrollController _punterScrollController = ScrollController();
  Map<String, AflPlayerMatchStats> _currentStatsByPlayerId = {};

  final FridayPairsService _fridayPairsService = FridayPairsService();
  bool _fridayWinnerSelected = false;
  int _fridayWinnerPosition = 0;
  

  bool get isLandscapePhone {
    final size = MediaQuery.of(context).size;
    return size.width > size.height && size.width < 900;
  }

  // ------------------------------------------------------------
  // Save round results for season-long storage
  // ------------------------------------------------------------
  Future<void> _saveRoundResultsToBackend(List<PunterSelection> punters) async {
    try {
      final url = Uri.parse(
        "https://fantasy-pairs-and-weekend-quads-production.up.railway.app/saveRoundResults",
      );

      final body = jsonEncode({
        "season": widget.season,
        "round": widget.round,
        "gameType": widget.gameType,
        "punters": punters.map((p) {
          return {
            "name": p.punterName,
            "total": p.totalScore,
            "picks": p.picks.map((pick) {
              return {
                "playerId": pick.player?.id,
                "score": pick.stats?["score"] ?? 0,
              };
            }).toList(),
          };
        }).toList(),
      });

      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
    } catch (e) {
      debugPrint("❌ Failed to save round results: $e");
    }
  }

  

  @override
  void initState() {
    super.initState();
    _startLivePolling();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _punterScrollController.dispose();
    super.dispose();
  }

  void _startLivePolling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        await _refreshLive();
        setState(() {});
      },
    );
  }

// -------------------------------------------------------------
// ROUND-WIDE STATS FETCHER
// -------------------------------------------------------------
Future<Map<String, AflPlayerMatchStats>> _fetchRoundStats() async {
  final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
    widget.season,
    widget.round,
  );

  final Map<String, AflPlayerMatchStats> roundStats = {};

  for (final f in fixtures) {
    final matchId = f.matchId?.trim();
    if (matchId == null || matchId.isEmpty) continue;

    final stats = await MatchStatsParser.fetchMatchStats(
      matchId,
      widget.playerRepo,
      widget.fixtureRepo,
    );

    if (stats.isEmpty) continue;

    for (final s in stats) {
      if (s.player != null) {
        roundStats[s.player!.id] = s;
      }
    }
  }

  return roundStats;
}

  // -------------------------------------------------------------
  // ROUND-WIDE STATS
  // -------------------------------------------------------------
  Future<void> _refreshLive() async {
  try {
    // Refresh fixture metadata (scores, quarter, clock, status)
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    for (final f in fixtures) {
      final matchId = f.matchId?.trim();
      if (matchId != null && matchId.isNotEmpty) {
        await widget.fixtureRepo.refreshLiveScores(matchId: matchId);
      }
    }

    if (!mounted) return;

    _checkRoundCompletion();

    // ⭐ NEW — Check if Friday Pairs final winner should be applied
    _finaliseFridayPairsWinner();

    // Fetch and store round-wide stats
    final roundStats = await _fetchRoundStats();
    _currentStatsByPlayerId = roundStats;

    // Apply live stats to the punter table (only if mounted)
    final tableState = _punterTableKey.currentState;
    if (tableState != null) {
      final dynamic dyn = tableState;

      dyn.applyLiveStatsToTable(_currentStatsByPlayerId);

      // Admins save snapshot after live update
      // (your saveSnapshot call goes here if needed)
    }

    _checkAndCompleteWeekendQuadsRound();

  } catch (e, st) {
    debugPrint("❌ Live refresh error: $e\n$st");
  }
}
  

void _finaliseFridayPairsWinner() {
  if (widget.gameType != "friday_pairs") return;
  if (!_fridayWinnerSelected) return;

  final fixtures = _fixturesForGameType();
  if (fixtures.isEmpty) return;

  final allComplete = fixtures.every((f) => f.complete);
  if (!allComplete) return;

  setState(() {
    for (final p in widget.selections) {
      p.isPrizeWinner = (p.punterNumber == _fridayWinnerPosition);
    }
  });

  debugPrint("🏁 Friday Pairs final winner = $_fridayWinnerPosition");
}

  void _checkRoundCompletion() {
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    if (fixtures.isEmpty) return;

    final allComplete = fixtures.every((f) => f.complete);

    if (allComplete) {
      widget.roundCompletionService.markCompleted(widget.round);

      // Save season results for Pairs games
      _saveRoundResultsToBackend(widget.selections);
    }
  }

  void _checkAndCompleteWeekendQuadsRound() {
    if (widget.gameType != "weekend_quads") return;
    if (_isCompleted) return;

    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    final allComplete =
        fixtures.isNotEmpty && fixtures.every((f) => f.complete);

    if (!allComplete) return;

    setState(() => _isCompleted = true);

    final firstFixture = fixtures.firstWhere(
      (f) => f.date != null,
      orElse: () => fixtures.first,
    );

    final month = firstFixture.date == null
        ? "Unknown"
        : _monthName(firstFixture.date!.month);

    widget.championshipService.addRound(month, widget.selections);

    // Save season results for Weekend Quads
    _saveRoundResultsToBackend(widget.selections);

    debugPrint("🏆 Weekend Quads completed for $month");
  }

  List<AflFixture> _fixturesForGameType() {
    final all = widget.round == null
        ? widget.fixtureRepo.preseasonFixturesForSeason(widget.season)
        : widget.fixtureRepo.fixturesForSeasonRound(
            widget.season,
            widget.round!,
          );

    bool isDay(AflFixture f, int weekday) =>
        f.date != null && f.date!.weekday == weekday;

    switch (widget.gameType) {
      case "thursday_pairs":
        return all.where((f) => isDay(f, DateTime.thursday)).toList();
      case "friday_pairs":
        return all.where((f) => isDay(f, DateTime.friday)).toList();
      case "saturday_pairs":
        return all.where((f) => isDay(f, DateTime.saturday)).toList();
      case "sunday_pairs":
        return all.where((f) => isDay(f, DateTime.sunday)).toList();
      case "monday_pairs":
        return all.where((f) => isDay(f, DateTime.monday)).toList();
      case "weekend_quads":
        return all.where((f) {
          final d = f.date;
          return d != null &&
              (d.weekday == DateTime.friday ||
                  d.weekday == DateTime.saturday ||
                  d.weekday == DateTime.sunday ||
                  d.weekday == DateTime.monday);
        }).toList();
      case "custom_pairs":
      default:
        return all;
    }
  }

  String _monthName(int m) {
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

  String _quarterLabel(AflFixture f) {
    if (f.complete) return "FT";
    if (f.quarterText.isNotEmpty) return f.quarterText;
    return "";
  }

  String _timeLabel(AflFixture f) {
    if (f.complete) return "FT";
    if (f.timeText.isNotEmpty) return f.timeText;
    if (f.time.isNotEmpty) return f.time;
    return "--:--";
  }

  String _gameTypeLabel() {
    switch (widget.gameType) {
      case "thursday_pairs":
        return "Thursday Pairs";
      case "friday_pairs":
        return "Friday Pairs";
      case "saturday_pairs":
        return "Saturday Pairs";
      case "sunday_pairs":
        return "Sunday Pairs";
      case "monday_pairs":
        return "Monday Pairs";
      case "weekend_quads":
        return "Weekend Quads";
      case "custom_pairs":
        return "Custom Pairs";
      default:
        return widget.gameType;
    }
  }

  String _appBarTitle() {
    final roundLabel = RoundHelper.label(widget.round);
    return "$roundLabel • ${_gameTypeLabel()}";
  }

  Map<String, dynamic> _mapStats(AflPlayerMatchStats s) {
    return {
      "Player": s.player?.name ?? "Unknown",
      "AF": s.fantasyPoints,
      "K": s.kicks,
      "HB": s.handballs,
      "D": s.disposals,
      "M": s.marks,
      "T": s.tackles,
      "G": s.goals,
      "B": s.behinds,
    };
  }

  // ignore: unused_element
  bool _canSubmit() {
    if (_isSubmitted) return true;
    if (!widget.userRoleService.isAdmin) return false;

    for (final row in widget.selections) {
      for (final pick in row.picks) {
        if (pick.player == null) return false;
      }
    }

    final seen = <String>{};
    for (final row in widget.selections) {
      for (final pick in row.picks) {
        final id = pick.player!.id;
        if (seen.contains(id)) return false;
        seen.add(id);
      }
    }

    return true;
  }

  // ignore: unused_element
  void _toggleSubmit() {
    setState(() => _isSubmitted = !_isSubmitted);

    if (_isSubmitted) {
      _submitGame();
    } else {
      _unsubmitGame();
    }
  }

  void _submitGame() {
    if (widget.gameType == "weekend_quads") {
      final fixtures = _fixturesForGameType();
      if (fixtures.isEmpty) return;

      final first = fixtures.firstWhere(
        (f) => f.date != null,
        orElse: () => fixtures.first,
      );

      final month = first.date == null
          ? "Unknown"
          : widget.championshipService.monthName(first.date!.month);

      widget.championshipService.addRound(month, widget.selections);
      debugPrint("🏆 Submitted to Championship for $month");
    }
  }

  void _unsubmitGame() {
    if (widget.gameType == "weekend_quads") {
      final fixtures = _fixturesForGameType();
      if (fixtures.isEmpty) return;

      final first = fixtures.firstWhere(
        (f) => f.date != null,
        orElse: () => fixtures.first,
      );

      final month = first.date == null
          ? "Unknown"
          : widget.championshipService.monthName(first.date!.month);

      widget.championshipService.roundsByMonth[month]
          ?.removeWhere((round) => identical(round, widget.selections));

      widget.championshipService.allRounds
          .removeWhere((round) => identical(round, widget.selections));

      debugPrint("⚠️ Unsubmitted from Championship");
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFixtures = _fixturesForGameType();

    var fixtures = allFixtures;
    if (widget.selectedFixtureIds != null) {
      fixtures = allFixtures.where((f) {
        final id = f.matchId ?? allFixtures.indexOf(f).toString();
        return widget.selectedFixtureIds!.contains(id);
      }).toList();
    }

    if (_selectedFixture == null && fixtures.isNotEmpty) {
      _selectedFixture = fixtures.first;
    }

    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: isLandscapePhone ? 36 : 44,
          titleSpacing: 0,
          title: Text(
            _appBarTitle(),
            style: TextStyle(
              fontSize: isLandscapePhone ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildFixtureStrip(fixtures),
            const Divider(height: 1),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFixtureStrip(List<AflFixture> fixtures) {
    if (fixtures.isEmpty) {
      return const SizedBox(
        height: 95,
        child: Center(child: Text("No fixtures")),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _fixturesCollapsed ? 36 : 88,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _fixturesCollapsed = !_fixturesCollapsed),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.black.withAlpha(51),
              child: Row(
                children: [
                  Text(
                    "Fixtures",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _fixturesCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (!_fixturesCollapsed)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: fixtures.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _buildFixtureCard(fixtures[i]),
              ),
            ),
        ],
      ),
    );
  }

void _handleFridayPairsTrigger(AflFixture f) {
  if (widget.gameType != "friday_pairs") return;
  if (_fridayWinnerSelected) return;

  if (f.quarterText.isEmpty && !f.complete) return;

  final punterCount = widget.selections.length;

  final pos =
      _fridayPairsService.selectRandomBottomHalfPosition(punterCount);

  _fridayWinnerPosition = pos;
  _fridayWinnerSelected = true;

  setState(() {
    for (final p in widget.selections) {
      p.isPrizeWinner = (p.punterNumber == pos);
    }
  });

  debugPrint("🎯 Friday Pairs random position = $pos");
}

  Widget _buildFixtureCard(AflFixture f) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final selected = f == _selectedFixture;
    _handleFridayPairsTrigger(f);

    final homeScore = f.homeScore;
    final awayScore = f.awayScore;
    final homeWinning = homeScore > awayScore;
    final awayWinning = awayScore > homeScore;

    final quarter = _quarterLabel(f);
    final time = _timeLabel(f);

    final scoreBaseStyle = TextStyle(
      fontSize: isLandscapePhone ? 12 : 13,
      fontWeight: FontWeight.w500,
      color: cs.onSurface,
    );

    final metaStyle = TextStyle(
      fontSize: isLandscapePhone ? 10 : 11,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade700,
      height: 1.1,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onFixtureTap(f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: isLandscapePhone ? 100 : 125,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? cs.surfaceContainerHighest.withAlpha(72)
                : cs.surfaceContainerHighest.withAlpha(40),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TeamLogo(f.homeTeam, size: isLandscapePhone ? 22 : 26),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: scoreBaseStyle,
                        children: [
                          TextSpan(
                            text: "$homeScore",
                            style: TextStyle(
                              fontWeight: homeWinning
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: "–"),
                          TextSpan(
                            text: "$awayScore",
                            style: TextStyle(
                              fontWeight: awayWinning
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ),
                  TeamLogo(f.awayTeam, size: isLandscapePhone ? 22 : 26),
                ],
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  quarter.isEmpty ? time : "$quarter • $time",
                  style: metaStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _onFixtureTap(AflFixture f) async {
    setState(() => _selectedFixture = f);

    final matchId = f.matchId?.trim();
    if (matchId == null || matchId.isEmpty) return;

    final stats = _currentStatsByPlayerId.values.toList();

    final homeTeam = f.homeTeam;
    final awayTeam = f.awayTeam;

    final rowsA = stats
        .where((s) => s.player?.club == homeTeam)
        .map(_mapStats)
        .toList();

    final rowsB = stats
        .where((s) => s.player?.club == awayTeam)
        .map(_mapStats)
        .toList();

    final noStats = rowsA.isEmpty && rowsB.isEmpty;

    const columns = [
      "Player",
      "AF",
      "K",
      "HB",
      "D",
      "M",
      "T",
      "G",
      "B",
    ];

    showDialog<void>(
      context: context,
      builder: (_) => StatsOverlay(
        leftTitle: homeTeam,
        rightTitle: awayTeam,
        leftRows: noStats ? <Map<String, dynamic>>[] : rowsA,
        rightRows: noStats ? <Map<String, dynamic>>[] : rowsB,
        columns: noStats ? <String>[] : columns,
        noStatsMessage: noStats ? "No stats available yet" : null,
      ),
    );
  }

  String _timestampLabel = "--:--";

  Widget _buildPunterControls() {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _controlsCollapsed ? 32 : null,
      padding: EdgeInsets.symmetric(
        vertical: _controlsCollapsed ? 0 : (isLandscapePhone ? 2 : 4),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _controlsCollapsed = !_controlsCollapsed),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    "Punter Controls",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _leaderboardCollapsed
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(
                          () => _leaderboardCollapsed = !_leaderboardCollapsed);
                    },
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _controlsCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (!_controlsCollapsed)
            Row(
              children: [
                Text("Punters Playing", style: theme.textTheme.bodyMedium),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                      color: theme.colorScheme.surface,
                    ),
                    child: DropdownButton<int>(
                      value: _visiblePunterCount,
                      isDense: true,
                      menuMaxHeight: 280,
                      itemHeight: 32,
                      style: theme.textTheme.bodyMedium,
                      items: List.generate(25, (i) => i + 1)
                          .map(
                            (v) => DropdownMenuItem<int>(
                              value: v,
                              child: Text("$v"),
                            ),
                          )
                          .toList(),
                      onChanged: widget.userRoleService.isAdmin
                          ? (value) {
                              if (value == null) return;
                              setState(() => _visiblePunterCount = value);
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withAlpha(64),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Updated $_timestampLabel",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPunterAndLeaderboard() {
  return Expanded(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final innerWidth = constraints.maxWidth;
        final picks = widget.gameType == "weekend_quads" ? 4 : 2;

        final leaderboardWidth = _leaderboardCollapsed
            ? UIDimensions.collapsedLeaderboardWidth
            : UIDimensions.rankColumnWidth +
                UIDimensions.punterNameColumnWidth +
                UIDimensions.totalColumnWidth;

        final double punterTableWidth =
            _leaderboardCollapsed ? innerWidth : innerWidth - leaderboardWidth;

        // ✅ Safe round for pre‑season (round can be null)
        final int safeRound = widget.round ?? 0;

        return FutureBuilder<List<AflPlayer>>(
          future: widget.playerRepo.playersForSeason(widget.season),
          builder: (context, snapshot) {
            print(
                "🔥 FUTUREBUILDER snapshot: hasData=${snapshot.hasData}, error=${snapshot.error}");

            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Failed to load players"));
            }

            final seasonPlayers = snapshot.data!;
            List<AflPlayer> availablePlayers = [];

            // ⭐ If custom pairs, use overridePlayers directly
            if (widget.gameType == "custom_pairs" &&
                widget.overridePlayers != null) {
              availablePlayers = widget.overridePlayers!;
            } else {
              final fixtures = _fixturesForGameType();
              final fixtureClubCodes =
                  fixtures.expand((f) => [f.homeTeam, f.awayTeam]).toSet();

              availablePlayers = seasonPlayers
                  .where((p) => p.club.isNotEmpty)
                  .where((p) => fixtureClubCodes.contains(p.club))
                  .toList();
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(64),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PunterSelectionTable(
                      key: _punterTableKey,
                      gameType: widget.gameType,
                      season: widget.season.toString(),
                      round: safeRound, // ✅ no bang
                      tableWidth: punterTableWidth,
                      visiblePunterCount: _visiblePunterCount,
                      playersPerPunter: picks,
                      availablePlayers: availablePlayers,
                      selections: widget.selections,
                      isCompleted: _isCompleted,
                      readOnly: !widget.userRoleService.isAdmin,
                      onChanged:
                          widget.userRoleService.isAdmin ? () {} : null,
                      collapsed: _leaderboardCollapsed,
                      scrollController: _punterScrollController,
                      fantasyService: widget.fantasyService,
                      userRoleService: widget.userRoleService,
                      onTimestampChanged: (t) {
                        setState(() => _timestampLabel = t);
                      },
                      onLiveScoreUpdateSave: () {
                        final tableState = _punterTableKey.currentState;
                        if (tableState != null) {
                          (tableState as dynamic).saveSnapshot();
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: leaderboardWidth,
                    child: LeaderboardPanel(
                      punters: widget.selections
                          .take(_visiblePunterCount)
                          .toList(),
                      rowHeight: UIDimensions.rowHeight,
                      collapsed: _leaderboardCollapsed,
                      scrollController: _punterScrollController,
                      onCollapseChanged: (collapsed) {
                        setState(() => _leaderboardCollapsed = collapsed);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPunterControls(),
          const SizedBox(height: 6),
          _buildPunterAndLeaderboard(),
        ],
      ),
    );
  }

  


  void validateAflData(
    List<AflFixture> fixtures,
    PlayerRepository repo,
  ) {
    final fixtureClubs = fixtures
        .expand((f) => [
              f.homeTeam.trim().toUpperCase(),
              f.awayTeam.trim().toUpperCase(),
            ])
        .toSet();

    final playerClubs =
        repo.players.map((p) => p.club.trim().toUpperCase()).toSet();

    final missingInPlayers = fixtureClubs.difference(playerClubs);
    final missingInFixtures = playerClubs.difference(fixtureClubs);

    debugPrint("=== AFL DATA VALIDATION ===");

    if (missingInPlayers.isNotEmpty) {
      debugPrint("❌ Clubs in FIXTURES but NOT in PLAYERS:");
      debugPrint(missingInPlayers.toString());
    }

    if (missingInFixtures.isNotEmpty) {
      debugPrint("❌ Clubs in PLAYERS but NOT in FIXTURES:");
      debugPrint(missingInFixtures.toString());
    }

    if (missingInPlayers.isEmpty && missingInFixtures.isEmpty) {
      debugPrint("✅ Fixtures and players are aligned.");
    }
  }
}
