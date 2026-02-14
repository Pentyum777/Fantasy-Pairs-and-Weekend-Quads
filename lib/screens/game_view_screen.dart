import 'dart:async';
import 'package:flutter/material.dart';

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

  AflFixture? _selectedFixture;
  Timer? _liveTimer;
  final ScrollController _punterScrollController = ScrollController();
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
    _punterScrollController.dispose();
    super.dispose();
  }

  void _startLivePolling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshLive(),
    );
  }

  // -------------------------------------------------------------
  // ROUND-WIDE STATS
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

    // Fetch stats (may be empty)
    final stats = await MatchStatsParser.fetchMatchStats(
      matchId,
      widget.playerRepo,
      widget.fixtureRepo,
    );

    // If stats are empty, still populate players for both clubs
    if (stats.isEmpty) {
  // ⭐ Do NOT overwrite real DFS stats with zeros
  continue;
}

    // Normal case: stats exist
    for (final s in stats) {
      if (s.player != null) {
        roundStats[s.player!.id] = s;
      }
    }
  }

  return roundStats;
}

  Future<void> _refreshLive() async {
  try {
    // ⭐ Update fixture metadata (scores, quarter, clock, status)
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

    // ⭐ Fetch stats for ALL matches in the round
    final roundStats = await _fetchRoundStats();

    // ⭐ Apply round-wide stats to punter table + overlay
    _applyLiveStats(roundStats.values.toList());

    _checkAndCompleteWeekendQuadsRound();
  } catch (e, st) {
    debugPrint("❌ Live refresh error: $e\n$st");
  }
}

  void _applyLiveStats(List<AflPlayerMatchStats> stats) {
  // Build lookup map
  _currentStatsByPlayerId = {
    for (final s in stats)
      if (s.player != null) s.player!.id: s
  };

  // Apply stats to every punter selection + pick
  for (final selection in widget.selections) {
    for (final pick in selection.picks) {
      final id = pick.player?.id;

      if (id == null) {
        pick.fantasyPoints = 0;
        pick.stats = null;
        continue;
      }

      final s = _currentStatsByPlayerId[id];

      if (s == null) {
        pick.fantasyPoints = 0;
        pick.stats = null;
        continue;
      }

      // ⭐ Update pick stats for punter table
      pick.fantasyPoints = s.fantasyPoints;
      pick.stats = {
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

    // ⭐ Update total score using round‑wide stats
    selection.liveScore = widget.fantasyService.calculatePunterScore(
      selection: selection,
      liveStatsByPlayerId: _currentStatsByPlayerId,
    );
  }

  setState(() {});
}

    void _checkRoundCompletion() {
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    if (fixtures.isEmpty) return;

    if (fixtures.every((f) => f.complete)) {
      widget.roundCompletionService.markCompleted(widget.round);
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

  void _resetSelections() {
    if (widget.userRoleService.isReadOnly) return;

    final picks = widget.gameType == "weekend_quads" ? 4 : 2;

    for (final punter in widget.selections) {
      for (var i = 0; i < picks; i++) {
        punter.picks[i].player = null;
        punter.picks[i].stats = null;
      }
      punter.isPrizeWinner = false;
    }

    setState(() {
      _isCompleted = false;
      _isSubmitted = false;
    });

    _applyLiveStats(_currentStatsByPlayerId.values.toList());
  }

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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        titleSpacing: 0,
        title: Text(
          _appBarTitle(),
          style: const TextStyle(
            fontSize: 15,
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
    );
  }
    Widget _buildFixtureStrip(List<AflFixture> fixtures) {
    if (fixtures.isEmpty) {
      return const SizedBox(
        height: 95,
        child: Center(child: Text("No fixtures")),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: fixtures.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _buildFixtureCard(fixtures[i]),
        ),
      ),
    );
  }

  Widget _buildFixtureCard(AflFixture f) {
  final selected = f == _selectedFixture;
  _handleFridayPairsTrigger(f);

  final homeScore = f.homeScore;
  final awayScore = f.awayScore;
  final homeWinning = homeScore > awayScore;
  final awayWinning = awayScore > homeScore;

  final quarter = _quarterLabel(f);
  final time = _timeLabel(f);

  // ⭐ Unified compact text styles
  final scoreBaseStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
  );

  final metaStyle = TextStyle(
    fontSize: 11,
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
        width: 125,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ⭐ Top row: home logo + score + away logo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TeamLogo(f.homeTeam, size: 26),

                Expanded(
  child: Text.rich(
    TextSpan(
      style: scoreBaseStyle,
      children: [
        TextSpan(
          text: "$homeScore",
          style: TextStyle(
            fontWeight: homeWinning ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const TextSpan(text: " – "),
        TextSpan(
          text: "$awayScore",
          style: TextStyle(
            fontWeight: awayWinning ? FontWeight.w700 : FontWeight.w500,
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

TeamLogo(f.awayTeam, size: 26),
              ],
            ),

            // ⭐ Quarter / Time
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

  // ⭐ Always use round‑wide stats (already fetched by _refreshLive)
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



  Widget _buildPunterControls() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed:
                widget.userRoleService.isAdmin ? _resetSelections : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              "Reset Selections",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (widget.userRoleService.isAdmin) ...[
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _canSubmit() ? _toggleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSubmitted ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 28),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _isSubmitted ? "Unsubmit" : "Submit",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _leaderboardCollapsed
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              setState(() => _leaderboardCollapsed = !_leaderboardCollapsed);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPunterAndLeaderboard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final innerWidth = constraints.maxWidth;
      final picks = widget.gameType == "weekend_quads" ? 4 : 2;

      final leaderboardWidth = _leaderboardCollapsed
          ? UIDimensions.collapsedLeaderboardWidth
          : UIDimensions.rankColumnWidth +
              UIDimensions.punterNameColumnWidth +
              UIDimensions.totalColumnWidth;

      final double punterTableWidth =
          _leaderboardCollapsed ? innerWidth : innerWidth - leaderboardWidth;

      return FutureBuilder<List<AflPlayer>>(
        future: widget.playerRepo.playersForSeason(widget.season),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final seasonPlayers = snapshot.data!;

          // ⭐ FIX: Use ALL round players, not fixture-scoped players
          final availablePlayers = seasonPlayers;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: punterTableWidth,
                child: PunterSelectionTable(
                  tableWidth: punterTableWidth,
                  visiblePunterCount: _visiblePunterCount,
                  playersPerPunter: picks,
                  availablePlayers: availablePlayers,
                  selections: widget.selections,
                  isCompleted: _isCompleted,
                  readOnly:
                      widget.userRoleService.isReadOnly || _isSubmitted,
                  onChanged: widget.userRoleService.isAdmin
                      ? () {
                          _applyLiveStats(
                            _currentStatsByPlayerId.values.toList(),
                          );
                        }
                      : null,
                  collapsed: _leaderboardCollapsed,
                  scrollController: _punterScrollController,
                ),
              ),
              SizedBox(
                width: leaderboardWidth,
                child: LeaderboardPanel(
                  punters: widget.selections
                      .take(_visiblePunterCount)
                      .toList(),
                  rowHeight: 34,
                  collapsed: _leaderboardCollapsed,
                  scrollController: _punterScrollController,
                  onCollapseChanged: (collapsed) {
                    setState(() => _leaderboardCollapsed = collapsed);
                  },
                ),
              ),
            ],
          );
        },
      );
    },
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
          Expanded(child: _buildPunterAndLeaderboard()),
        ],
      ),
    );
  }

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

    final playerClubs = repo.players
        .map((p) => p.club.trim().toUpperCase())
        .toSet();

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
      debugPrint("✔ All clubs aligned between fixtures and players");
    }

    final emptyClubs =
        repo.players.where((p) => p.club.trim().isEmpty).toList();
    if (emptyClubs.isNotEmpty) {
      debugPrint("❌ Players with empty club codes:");
      for (final p in emptyClubs) {
        debugPrint(" - ${p.name}");
      }
    }

    debugPrint("=== END AFL VALIDATION ===");
  }
}