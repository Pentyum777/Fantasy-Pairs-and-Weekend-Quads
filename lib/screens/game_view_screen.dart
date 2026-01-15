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
import '../widgets/side_by_side_game_tables.dart';
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
  final List<int>? selectedFixtureIds;
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

  // A match is considered "in progress" if:
  // - It is NOT complete
  // - The time string is non-empty (clock is running)
  final isLive = !fixture.complete && fixture.time.isNotEmpty;

  if (isLive) {
    final winner = _fridayPairsService.selectRandomBottomHalf(widget.selections);

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

      if (_selectedFixture?.matchId != null) {
        final stats =
            await MatchStatsParser.fetchMatchStats(_selectedFixture!.matchId!);
        _updateStatsAndPunterScores(stats);
      } else {
        setState(() {});
      }

      _checkAndCompleteWeekendQuadsRound();
    } catch (_) {}
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
  // TEAM LOGO
  // ---------------------------------------------------------------------------
  Widget _teamLogo(String clubCode) {
    final assetPath = 'logos/$clubCode.png';

    return SizedBox(
      width: 36,
      height: 36,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Center(
              child: Text(
                clubCode,
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
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

    var fixtures = allFixtures;

    if (widget.selectedFixtureIds != null) {
      fixtures = allFixtures.where((f) {
        final id = f.matchId ?? allFixtures.indexOf(f);
        return widget.selectedFixtureIds!.contains(id);
      }).toList();
    }

    if (_selectedFixture == null && fixtures.isNotEmpty) {
      _selectedFixture = fixtures.first;
    }

    final players = widget.overridePlayers ??
        (_selectedFixture == null
            ? <AflPlayer>[]
            : _playersForFixture(_selectedFixture!));

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
      ),
      body: Column(
        children: [
          // FIXTURE SCROLLER
          SizedBox(
            height: 110,
            child: fixtures.isEmpty
                ? const Center(child: Text("No fixtures"))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    itemCount: fixtures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final f = fixtures[i];
                      final selected = f == _selectedFixture;

                      // 🔥 Friday Pairs trigger
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

                          if (f.matchId != null) {
                            final stats = await MatchStatsParser
                                .fetchMatchStats(f.matchId!);
                            _updateStatsAndPunterScores(stats);
                          }
                        },
                        child: SizedBox(
                          width: 160,
                          height: 100,
                          child: Card(
                            elevation: selected ? 6 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: selected
                                  ? BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 2,
                                    )
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _teamLogo(f.homeTeam),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 18,
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
                                                const TextSpan(text: "–"),
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
                                      _teamLogo(f.awayTeam),
                                    ],
                                  ),
                                  Text(
                                    quarterText.isEmpty
                                        ? timeText
                                        : "$quarterText • $timeText",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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
                // LEFT SIDE
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPunterControls(context),
                        const SizedBox(height: 8),

                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Punter Table
                              Expanded(
                                flex: 3,
                                child: PunterSelectionTable(
                                  visiblePunterCount: _visiblePunterCount,
                                  playersPerPunter:
                                      widget.gameType == "weekend_quads"
                                          ? 4
                                          : 2,
                                  availablePlayers: players,
                                  selections: widget.selections,
                                  isCompleted: _isCompleted,
                                  readOnly: widget.userRoleService.isReadOnly,
                                  onChanged: widget.userRoleService.isAdmin
                                      ? () {
                                          _updateStatsAndPunterScores(
                                            _currentStatsByPlayerId.values
                                                .toList(),
                                          );
                                          setState(() {});
                                        }
                                      : null,
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Leaderboard
                              Expanded(
                                flex: 1,
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
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // RIGHT SIDE: Stats Panel
                SizedBox(
                  width: 300,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _selectedFixture == null
                          ? const Center(child: Text("No stats available."))
                          : _buildStatsPanel(_selectedFixture!),
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
  // PUNTER CONTROLS
  // ---------------------------------------------------------------------------
  Widget _buildPunterControls(BuildContext context) {
    return Row(
      children: [
        Text(
          "Punters Playing",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _visiblePunterCount,
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
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed:
              widget.userRoleService.isAdmin ? _resetSelections : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text(
            "Reset Selections",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STATS PANEL
  // ---------------------------------------------------------------------------
  Widget _buildStatsPanel(AflFixture fixture) {
    if (fixture.matchId == null) {
      return const Center(child: Text("No stats available."));
    }

    final stats = _currentStatsByPlayerId.values.toList();
    if (stats.isEmpty) {
      return const Center(child: Text("No stats available."));
    }

    final homeTeam = fixture.homeTeam;
    final awayTeam = fixture.awayTeam;

    final rowsA =
        stats.where((s) => s.team == homeTeam).map(_mapStats).toList();
    final rowsB =
        stats.where((s) => s.team == awayTeam).map(_mapStats).toList();

    if (rowsA.isEmpty && rowsB.isEmpty) {
      return const Center(child: Text("No stats available for this match."));
    }

    return SideBySideGameTables(
      leftTitle: homeTeam,
      rightTitle: awayTeam,
      leftRows: rowsA,
      rightRows: rowsB,
      columns: const [
        "Player",
        "AF",
        "K",
        "HB",
        "D",
        "M",
        "T",
        "G",
        "B",
      ],
    );
  }

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

  // ---------------------------------------------------------------------------
  // GAME TYPE LABELS
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
  // FIXTURE FILTERING
  // ---------------------------------------------------------------------------
  List<AflFixture> _fixturesForGameType() {
    final all = widget.fixtureRepo.fixturesForRound(widget.round);

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

  List<AflPlayer> _playersForFixture(AflFixture fixture) {
    final clubs = {fixture.homeTeam, fixture.awayTeam};

    return widget.playerRepo.players
        .where((p) => clubs.contains(p.club))
        .toList();
  }

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
  //
    void _checkAndCompleteWeekendQuadsRound() {
    if (widget.gameType != "weekend_quads") return;
    if (_isCompleted) return;

    final fixtures = widget.fixtureRepo.fixturesForRound(widget.round);
    final allComplete = fixtures.isNotEmpty && fixtures.every((f) => f.complete);

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
}