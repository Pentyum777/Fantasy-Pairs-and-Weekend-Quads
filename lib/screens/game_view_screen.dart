import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

    bool _leaderboardCollapsed = false;
  bool _fixturesCollapsed = false;
  bool _controlsCollapsed = false;

  final GlobalKey _punterTableKey = GlobalKey();

  late List<PunterSelection> _selections;

  AflFixture? _selectedFixture;
  Timer? _liveTimer;
  final ScrollController _punterScrollController = ScrollController();

  Map<String, AflPlayerMatchStats> _currentStatsByPlayerId = {};
  List<AflFixture> _currentFixtures = []; // NEW: cache fixtures

  final FridayPairsService _fridayPairsService = FridayPairsService();
  bool _fridayWinnerSelected = false;
  int _fridayWinnerPosition = 0;

  // NEW: cache players (replaces FutureBuilder)
  List<AflPlayer>? _seasonPlayers;
  bool _loadingPlayers = true;

  String _timestampLabel = "--:--";

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
  _selections = _selections;   // ⭐ Make selections persistent

_loadSeasonPlayers().then((_) {
  _loadSelectionsSnapshot();       // Snapshot now applies to _selections
});
  _startLivePolling();
}

  @override
  void dispose() {
    _liveTimer?.cancel();
    _punterScrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // NEW: load players once (removes FutureBuilder)
  // ------------------------------------------------------------
  Future<void> _loadSeasonPlayers() async {
    try {
      final players = await widget.playerRepo.playersForSeason(widget.season);
      if (!mounted) return;
      setState(() {
        _seasonPlayers = players;
        _loadingPlayers = false;
      });
    } catch (e, st) {
      debugPrint("❌ Failed to load players: $e\n$st");
      if (!mounted) return;
      setState(() {
        _seasonPlayers = [];
        _loadingPlayers = false;
      });
    }
  }

Future<void> _loadSelectionsSnapshot() async {
  try {
    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/loadSelections",
      {
        "gameType": widget.gameType,
        "season": widget.season.toString(),
        "round": widget.round.toString(),
      },
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      debugPrint("⚠️ loadSelectionsSnapshot: HTTP ${res.statusCode}");
      return;
    }

    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      debugPrint("❌ loadSelectionsSnapshot: invalid JSON");
      return;
    }

    final data = json["data"];
    if (data is! Map<String, dynamic>) {
      debugPrint("⚠️ loadSelectionsSnapshot: missing data field");
      return;
    }

    // ⭐ Apply snapshot directly to widget.selections
    _applySnapshotToSelections(data);

// ⭐ Determine how many punters to show
final hasAnySelections = _selections.any((p) {
  final hasName = p.punterName.trim().isNotEmpty && !p.punterName.startsWith("P");
  final hasPicks = p.picks.any((pick) => pick.player != null);
  return hasName || hasPicks;
});

setState(() {
  if (hasAnySelections) {
    // Use the number of punters actually entered
    _visiblePunterCount = _selections.length;
  } else {
    // Default to 10 punters
    _visiblePunterCount = 10;
  }
});

debugPrint("📥 Snapshot restored. Visible punters = $_visiblePunterCount");

    debugPrint("📥 Snapshot restored before UI build");

  } catch (e, st) {
    debugPrint("❌ Failed to load selections snapshot: $e\n$st");
  }
}

void _applySnapshotToSelections(Map<String, dynamic> data) {
  final punterNames = (data["punterNames"] as List<dynamic>? ?? [])
      .map((e) => e?.toString() ?? "")
      .toList();

  final picksJson = (data["picks"] as List<dynamic>? ?? []);

  for (int i = 0; i < _selections.length; i++) {
    final row = _selections[i];

    // ---- Restore punter name ----
    if (i < punterNames.length) {
      final name = punterNames[i].trim();
      row.punterName = name.isEmpty ? "P${row.punterNumber}" : name;
    }

    // ---- Restore picks ----
    if (i >= picksJson.length) {
      for (final pick in row.picks) {
        pick.player = null;
        pick.stats = null;
      }
      continue;
    }

    final snapRow = picksJson[i];
    if (snapRow is! List) continue;

    for (int j = 0; j < row.picks.length; j++) {
      final pick = row.picks[j];

      if (j >= snapRow.length) {
        pick.player = null;
        pick.stats = null;
        continue;
      }

      final snapPick = snapRow[j];
      if (snapPick is! Map) {
        pick.player = null;
        pick.stats = null;
        continue;
      }

      final pid = (snapPick["playerId"] ?? "").toString().trim();

      if (pid.isEmpty) {
        pick.player = null;
        pick.stats = null;
        continue;
      }

      // ---- Restore player from seasonPlayers ----
      final restored = _seasonPlayers?.where((p) => p.id == pid).toList() ?? [];

      pick.player = restored.isEmpty
          ? AflPlayer(
              id: pid,
              name: "Unknown ($pid)",
              club: "UNK",
              guernseyNumber: 0,
              season: widget.season,
            )
          : restored.first;

      // ---- Restore stats ----
      final rawStats = snapPick["stats"];
      pick.stats = rawStats is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawStats)
          : null;
    }
  }
}

  // ------------------------------------------------------------
  // LIVE POLLING (flicker‑free)
  // ------------------------------------------------------------
  void _startLivePolling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        await _refreshLive(); // no setState here
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
  // HELPERS: live detection + equality checks
  // -------------------------------------------------------------
  

  bool _fixturesEqual(List<AflFixture> a, List<AflFixture> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final fa = a[i];
      final fb = b[i];
      if (fa.matchId != fb.matchId ||
          fa.homeScore != fb.homeScore ||
          fa.awayScore != fb.awayScore ||
          fa.quarterText != fb.quarterText ||
          fa.timeText != fb.timeText ||
          fa.complete != fb.complete) {
        return false;
      }
    }
    return true;
  }

  bool _statsEqual(
  Map<String, AflPlayerMatchStats> a,
  Map<String, AflPlayerMatchStats> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (final key in a.keys) {
    final sa = a[key];
    final sb = b[key];
    if (sa == null || sb == null) return false;

    if ((sa.fantasyPoints ?? 0) != (sb.fantasyPoints ?? 0)) return false;
    if ((sa.kicks ?? 0) != (sb.kicks ?? 0)) return false;
    if ((sa.handballs ?? 0) != (sb.handballs ?? 0)) return false;
    if ((sa.disposals ?? 0) != (sb.disposals ?? 0)) return false;
    if ((sa.marks ?? 0) != (sb.marks ?? 0)) return false;
    if ((sa.tackles ?? 0) != (sb.tackles ?? 0)) return false;
    if ((sa.goals ?? 0) != (sb.goals ?? 0)) return false;
    if ((sa.behinds ?? 0) != (sb.behinds ?? 0)) return false;
  }

  return true;
}

  // -------------------------------------------------------------
  // ROUND-WIDE STATS + FIXTURES REFRESH (flicker‑free)
  // -------------------------------------------------------------
  Future<void> _refreshLive() async {
  try {
    // 1. Get fixtures for this round
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    // 2. Refresh live scores for each fixture
    for (final f in fixtures) {
      final matchId = f.matchId?.trim();
      if (matchId != null && matchId.isNotEmpty) {
        await widget.fixtureRepo.refreshLiveScores(matchId: matchId);
      }
    }

    if (!mounted) return;

    // 3. Re-read fixtures after refresh
    final updatedFixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    // 4. Always run completion checks
    _checkRoundCompletion();
    _finaliseFridayPairsWinner();
    _checkAndCompleteWeekendQuadsRound();

    // 5. Determine if round is fully complete
    final allComplete = updatedFixtures.every((f) => f.complete);

    // ⭐ ALWAYS fetch stats unless the entire round is complete
    Map<String, AflPlayerMatchStats> roundStats = _currentStatsByPlayerId;

    if (!allComplete) {
      roundStats = await _fetchRoundStats();
    }

    // 6. Detect changes
    final fixturesChanged =
        !_fixturesEqual(updatedFixtures, _currentFixtures);

    final statsChanged =
        !_statsEqual(roundStats, _currentStatsByPlayerId);

    // ⭐ DESKTOP FIX:
    // Always rebuild when stats are fetched, even if unchanged.
    // Desktop timers are throttled and can skip dirty-marking.
    // Desktop-safe: always rebuild when stats are fetched
final shouldRebuild = fixturesChanged || statsChanged;

// On desktop, timers can be throttled, so force rebuild every cycle
final isDesktop = Theme.of(context).platform == TargetPlatform.macOS ||
                  Theme.of(context).platform == TargetPlatform.windows ||
                  Theme.of(context).platform == TargetPlatform.linux;

if (!shouldRebuild && !isDesktop) {
  return;
}

    // 7. Apply changes atomically
    setState(() {
      _currentFixtures = updatedFixtures;
      _currentStatsByPlayerId = roundStats;

      final tableState = _punterTableKey.currentState;
      if (tableState != null) {
        final dynamic dyn = tableState;
        dyn.applyLiveStatsToTable(_currentStatsByPlayerId);
      }
    });

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
      for (final p in _selections) {
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
      _saveRoundResultsToBackend(_selections);
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

    widget.championshipService.addRound(month, _selections);
    _saveRoundResultsToBackend(_selections);

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

  // Only trigger when the game is officially underway
  final isLive = f.quarterText.isNotEmpty && !f.complete;
  if (!isLive) return;

  final punterCount = _selections.length;

  final pos = _fridayPairsService.selectRandomBottomHalfPosition(punterCount);

  _fridayWinnerPosition = pos;
  _fridayWinnerSelected = true;

  setState(() {
    for (final p in _selections) {
      p.isPrizeWinner = (p.punterNumber == pos);
    }
  });

  debugPrint("🎯 Friday Pairs random position = $pos (of $punterCount)");
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

    final isLive = !f.complete && quarter.isNotEmpty;

    final metaText = isLive
        ? "LIVE • $quarter $time"
        : quarter.isEmpty
            ? time
            : "$quarter • $time";

    final scoreBaseStyle = TextStyle(
      fontSize: isLandscapePhone ? 12 : 13,
      fontWeight: FontWeight.w500,
      color: cs.onSurface,
    );

    final metaStyle = TextStyle(
      fontSize: isLandscapePhone ? 10 : 11,
      fontWeight: FontWeight.w500,
      color: isLive ? Colors.red.shade400 : Colors.grey.shade700,
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
                ? cs.surfaceVariant.withAlpha(72)
                : cs.surfaceVariant.withAlpha(40),
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
                  metaText,
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
                    color:
                        theme.colorScheme.surfaceVariant.withAlpha(64),
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

          final int safeRound = widget.round ?? 0;

          if (_loadingPlayers) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_seasonPlayers == null || _seasonPlayers!.isEmpty) {
            return const Center(child: Text("Failed to load players"));
          }

          final seasonPlayers = _seasonPlayers!;
          List<AflPlayer> availablePlayers = [];

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
              color: theme.colorScheme.surfaceVariant.withAlpha(64),
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
                    season: widget.season,
                    round: safeRound,
                    tableWidth: punterTableWidth,
                    visiblePunterCount: _visiblePunterCount,
                    playersPerPunter: picks,
                    availablePlayers: availablePlayers,
                    selections: _selections,
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
                    punters: _selections
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
    int season,
  ) async {
    final fixtureClubs = fixtures
        .expand((f) => [
              f.homeTeam.trim().toUpperCase(),
              f.awayTeam.trim().toUpperCase(),
            ])
        .toSet();

    final seasonPlayers = await repo.playersForSeason(season);

    final playerClubs = seasonPlayers
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
      debugPrint("✅ Fixtures and players are aligned.");
    }
  }
}