import 'dart:async';
import 'package:flutter/material.dart';

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
import '../widgets/leaderboard_table.dart';
import '../widgets/stats_overlay.dart';
import '../widgets/team_logo.dart';

import '../parsers/match_stats_parser.dart';

class GameViewScreen extends StatefulWidget {
  final int round;
  final String gameType;
  final List<PunterSelection> selections;
  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;
  final ChampionshipService championshipService;
  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;

  // String IDs instead of int
  final List<String>? selectedFixtureIds;

  final List<AflPlayer>? overridePlayers;

  const GameViewScreen({
    super.key,
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

  AflFixture? _selectedFixture;
  Timer? _liveTimer;

  Map<String, AflPlayerMatchStats> _currentStatsByPlayerId = {};

  final FridayPairsService _fridayPairsService = FridayPairsService();
  bool _fridayWinnerSelected = false;

  @override
  void initState() {
    super.initState();
    _startLivePolling();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _startLivePolling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshLiveScoresAndStats(),
    );
  }

  // ---------------------------------------------------------------------------
  // FRIDAY PAIRS TRIGGER
  // ---------------------------------------------------------------------------
  void _handleFridayPairsTrigger(AflFixture fixture) {
    if (widget.gameType != "friday_pairs") return;
    if (_fridayWinnerSelected) return;

    final isLive = !fixture.complete && fixture.time.isNotEmpty;

    if (isLive) {
      final winner =
          _fridayPairsService.selectRandomBottomHalf(widget.selections);

      setState(() {
        for (final s in widget.selections) {
          s.isPrizeWinner = (s.punterName == winner.punterName);
        }
        _fridayWinnerSelected = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // ROUND COMPLETION CHECK
  // ---------------------------------------------------------------------------
  void _checkRoundCompletion() {
    final fixtures = widget.fixtureRepo.fixturesForRound(widget.round);
    if (fixtures.isEmpty) return;

    final allComplete = fixtures.every((f) => f.complete);
    if (allComplete) {
      widget.roundCompletionService.markCompleted(widget.round);
    }
  }

  // ---------------------------------------------------------------------------
  // LIVE SCORES + STATS REFRESH
  // ---------------------------------------------------------------------------
  Future<void> _refreshLiveScoresAndStats() async {
    try {
      await widget.fixtureRepo.refreshLiveScoresForRound(widget.round);

      if (!mounted) return;

      _checkRoundCompletion();

      // matchId is stored as String, but MatchStatsParser expects an int
      final String? rawMatchId = _selectedFixture?.matchId;
      final int? matchId =
          rawMatchId != null ? int.tryParse(rawMatchId.trim()) : null;

      if (matchId != null) {
        final stats = await MatchStatsParser.fetchMatchStats(matchId);
        _updateStatsAndPunterScores(stats);
      } else {
        setState(() {});
      }

      _checkAndCompleteWeekendQuadsRound();
    } catch (_) {
      // Silently ignore errors
    }
  }

  void _updateStatsAndPunterScores(List<AflPlayerMatchStats> stats) {
    _currentStatsByPlayerId = {
      for (final s in stats) s.player.id: s,
    };

    for (final selection in widget.selections) {
      selection.liveScore = widget.fantasyService.calculatePunterScore(
        selection: selection,
        liveStatsByPlayerId: _currentStatsByPlayerId,
      );
    }

    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // RESET SELECTIONS
  // ---------------------------------------------------------------------------
  void _resetSelections() {
    if (widget.userRoleService.isReadOnly) return;

    final picks = widget.gameType == "weekend_quads" ? 4 : 2;

    for (final punter in widget.selections) {
      for (var i = 0; i < picks; i++) {
        punter.picks[i].player = null;
        punter.picks[i].score = 0;
      }
      punter.isPrizeWinner = false;
    }

    setState(() => _isCompleted = false);

    _updateStatsAndPunterScores(_currentStatsByPlayerId.values.toList());
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final allFixtures = _fixturesForGameType();

    // Apply optional fixture filtering
    var fixtures = allFixtures;
    if (widget.selectedFixtureIds != null) {
      fixtures = allFixtures.where((f) {
        final id = f.matchId ?? allFixtures.indexOf(f).toString();
        return widget.selectedFixtureIds!.contains(id);
      }).toList();
    }

    // Default selected fixture
    if (_selectedFixture == null && fixtures.isNotEmpty) {
      _selectedFixture = fixtures.first;
    }

    // -----------------------------------------------------------------------
    // FILTER PLAYERS BY CLUBS IN CURRENT FIXTURES (Pairs/Quads requirement)
    // -----------------------------------------------------------------------
    final Set<String> clubsInGame = fixtures
        .expand((f) => [f.homeTeam, f.awayTeam])
        .where((c) => c.isNotEmpty)
        .toSet();

    final List<AflPlayer> filteredPlayersForGame =
        (widget.overridePlayers ?? widget.playerRepo.players)
            .where((p) => clubsInGame.contains(p.club))
            .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40, // Slim header
        titleSpacing: 0,
        title: Text(
          _appBarTitle(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // FIXTURE SCROLLER
          SizedBox(
            height: 95,
            child: fixtures.isEmpty
                ? const Center(child: Text("No fixtures"))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: fixtures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = fixtures[i];
                      final selected = f == _selectedFixture;

                      _handleFridayPairsTrigger(f);

                      final homeScore = f.homeScore ?? 0;
                      final awayScore = f.awayScore ?? 0;
                      final homeWinning = homeScore > awayScore;
                      final awayWinning = awayScore > homeScore;

                      final quarterText = _quarterLabel(f);
                      final timeText = _formatTimeRemaining(f);

                      return GestureDetector(
                        onTap: () async {
                          setState(() => _selectedFixture = f);

                          // matchId is String?, parser expects int
                          final String? rawId = f.matchId;
                          final int? matchId =
                              rawId != null ? int.tryParse(rawId.trim()) : null;

                          if (matchId != null) {
                            final stats =
                                await MatchStatsParser.fetchMatchStats(matchId);

                            final homeTeam = f.homeTeam;
                            final awayTeam = f.awayTeam;

                            final rowsA = stats
                                .where((s) => s.team == homeTeam)
                                .map(_mapStats)
                                .toList();

                            final rowsB = stats
                                .where((s) => s.team == awayTeam)
                                .map(_mapStats)
                                .toList();

                            final bool noStats =
                                stats.isEmpty && rowsA.isEmpty && rowsB.isEmpty;

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

                            showDialog(
                              context: context,
                              builder: (_) => StatsOverlay(
                                leftTitle: homeTeam,
                                rightTitle: awayTeam,
                                leftRows: noStats ? [] : rowsA,
                                rightRows: noStats ? [] : rowsB,
                                columns: noStats ? [] : columns,
                                noStatsMessage:
                                    noStats ? "No stats available yet" : null,
                              ),
                            );

                            _updateStatsAndPunterScores(stats);
                          }
                        },
                        child: AnimatedScale(
                          scale: selected ? 1.03 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 115,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: selected
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 2,
                                    )
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color:
                                            Colors.black.withOpacity(0.10),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 6),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TeamLogo(f.homeTeam, size: 26),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: "$homeScore",
                                                style: TextStyle(
                                                  fontWeight: homeWinning
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              const TextSpan(text: " – "),
                                              TextSpan(
                                                text: "$awayScore",
                                                style: TextStyle(
                                                  fontWeight: awayWinning
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    TeamLogo(f.awayTeam, size: 26),
                                  ],
                                ),
                                Text(
                                  quarterText.isEmpty
                                      ? timeText
                                      : "$quarterText • $timeText",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // MAIN CONTENT
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPunterControls(context),
                        const SizedBox(height: 8),
                        Expanded(
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: PunterSelectionTable(
                                    visiblePunterCount: _visiblePunterCount,
                                    playersPerPunter:
                                        widget.gameType == "weekend_quads"
                                            ? 4
                                            : 2,
                                    // ✅ Now filtered to clubs in fixtures
                                    availablePlayers: filteredPlayersForGame,
                                    selections: widget.selections,
                                    isCompleted: _isCompleted,
                                    readOnly:
                                        widget.userRoleService.isReadOnly,
                                    onChanged:
                                        widget.userRoleService.isAdmin
                                            ? () {
                                                _updateStatsAndPunterScores(
                                                  _currentStatsByPlayerId
                                                      .values
                                                      .toList(),
                                                );
                                                setState(() {});
                                              }
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 12),
                                  child: LeaderboardTable(
                                    punters: widget.selections
                                        .take(_visiblePunterCount)
                                        .toList(),
                                    rowHeight: 34,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REMOVED: _teamLogoSmallSized — no longer needed
  // ---------------------------------------------------------------------------

  Widget _buildPunterControls(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          "Punters Playing",
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(width: 8),

        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _visiblePunterCount,
            isDense: true,
            style: theme.textTheme.bodyMedium,
            items: List.generate(25, (i) => i + 1)
                .map(
                  (v) => DropdownMenuItem<int>(
                    value: v,
                    child: Text("$v", style: theme.textTheme.bodyMedium),
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

        const SizedBox(width: 16),

        ElevatedButton(
          onPressed: widget.userRoleService.isAdmin ? _resetSelections : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 32),
          ),
          child: const Text(
            "Reset Selections",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FIXTURE FILTERING
  // ---------------------------------------------------------------------------
  List<AflFixture> _fixturesForGameType() {
    // If selectedFixtureIds is provided (PS/custom mode),
    // we must NOT filter by round; we start from all fixtures.
    final all = widget.selectedFixtureIds != null
        ? widget.fixtureRepo.fixtures
        : widget.fixtureRepo.fixturesForRound(widget.round);

    bool isDay(AflFixture f, int weekday) {
      final d = f.date;
      if (d == null) return false;
      return d.weekday == weekday;
    }

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
          if (d == null) return false;
          return d.weekday == DateTime.friday ||
              d.weekday == DateTime.saturday ||
              d.weekday == DateTime.sunday ||
              d.weekday == DateTime.monday;
        }).toList();
      case "custom_pairs":
        return all;
      default:
        return all;
    }
  }

  // ---------------------------------------------------------------------------
  // TIME + QUARTER HELPERS
  // ---------------------------------------------------------------------------
  String _quarterLabel(AflFixture f) {
    if (f.complete) return "FT";
    return "";
  }

  String _formatTimeRemaining(AflFixture f) {
    if (f.complete) return "FT";
    if (f.time.isNotEmpty) return f.time;
    return "--:--";
  }

  // ---------------------------------------------------------------------------
  // WEEKEND QUADS → CHAMPIONSHIP
  // ---------------------------------------------------------------------------
  void _checkAndCompleteWeekendQuadsRound() {
    if (widget.gameType != "weekend_quads") return;
    if (_isCompleted) return;

    final fixtures = widget.fixtureRepo.fixturesForRound(widget.round);
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

    debugPrint("🏆 Weekend Quads round completed and recorded for $month");
  }

  // ---------------------------------------------------------------------------
  // MONTH NAME HELPER
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // GAME TYPE LABELS + APP BAR TITLE
  // ---------------------------------------------------------------------------
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
    return "Round ${widget.round} • ${_gameTypeLabel()}";
  }

  // ---------------------------------------------------------------------------
  // MAP STATS → TABLE ROW
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _mapStats(AflPlayerMatchStats s) {
    return {
      "Player": s.player.name,
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
}
