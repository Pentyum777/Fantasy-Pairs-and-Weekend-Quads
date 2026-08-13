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
import 'package:my_app/utils/afl_club_codes.dart';

import '../parsers/match_stats_parser.dart';
import '../constants/ui_dimensions.dart';
import '../services/game_data_cache.dart';
import '../widgets/screenshot_overlay.dart';

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
  final GameDataCache? gameDataCache;



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
    this.gameDataCache,
  });

  @override
  State<GameViewScreen> createState() => _GameViewScreenState();
}

class _GameViewScreenState extends State<GameViewScreen> {
  // ------------------------------------------------------------
  // NEW: Mode detection
  // ------------------------------------------------------------
  bool get isCustomBuilder => widget.gameType == "custom_builder";
  bool get isCustomGame => widget.gameType == "custom_game";

  int _visiblePunterCount = 15;
  int _maxPunterDropdown = 25;
  bool _punterCountManuallySet = false;
  List<String> _knownPunterNames = [];
  bool _showAveragePreview = false;
  bool _isCompleted = false;

  bool _leaderboardCollapsed = false;
  bool _fixturesCollapsed = false;
  bool _controlsCollapsed = false;

  final GlobalKey _punterTableKey = GlobalKey();

  // ⭐ Correct: declared ONCE
  late List<PunterSelection> _selections;

  AflFixture? _selectedFixture;
  Timer? _liveTimer;
  Timer? _syncTimer;       // polls for remote selection changes
  int _lastKnownTimestamp = 0; // unix ms of last loaded snapshot
  final ScrollController _punterScrollController = ScrollController();

  Map<String, AflPlayerMatchStats> _currentStatsByPlayerId = {};

  /// Bumped every time _applyLiveStats runs so any open StatsOverlay can rebuild.
  final ValueNotifier<int> _statsRefreshTick = ValueNotifier<int>(0);

  final FridayPairsService _fridayPairsService = FridayPairsService();
  bool _fridayWinnerSelected = false;
  int _fridayWinnerPosition = 0;

  List<AflPlayer>? _seasonPlayers;
  bool _loadingPlayers = true;

  String _timestampLabel = "--:--";
  bool _isSubmitted = false;

  bool get isLandscapePhone {
    final size = MediaQuery.of(context).size;
    return size.width > size.height && size.width < 900;
  }

  // ⭐ NEW: prevents table from building before snapshot loads
  bool _snapshotLoaded = false;



bool _isPlayerFromCompletedFixture(AflPlayerMatchStats s) {
  final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
    widget.season,
    widget.round,
  );

  final team = AflClubCodes.normalize(s.team);

  if (team.isEmpty) {
    debugPrint("❌ No team found in stats → NOT completed");
    return false;
  }

  for (final f in fixtures) {
    final home = AflClubCodes.normalize(f.homeTeam);
    final away = AflClubCodes.normalize(f.awayTeam);
    if ((f.quarterText ?? "").toLowerCase().contains("final") && (team == home || team == away)) {
      return true;
    }
  }

  return false;
}

bool _isPlayerInLiveFixture(AflPlayerMatchStats s) {
  final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
    widget.season,
    widget.round,
  );

  final team = AflClubCodes.normalize(s.team);
  if (team.isEmpty) return false;

  for (final f in fixtures) {
    final home = AflClubCodes.normalize(f.homeTeam);
    final away = AflClubCodes.normalize(f.awayTeam);

    if (team == home || team == away) {
      if (_isFixtureLive(f)) return true;
    }
  }

  return false;
}

bool _isFixtureLive(AflFixture f) {
  final q = (f.quarterText ?? "").toLowerCase().trim();

  if (q.isEmpty) return false;
  if (q.contains("final") || q == "ft") return false;

  return true; // any other quarterText = LIVE
}



  @override
void initState() {
  super.initState();

  final cache = widget.gameDataCache;
  final cacheKey = "${widget.season}-${widget.round}-${widget.gameType}";

  // Use the shared selection list directly — no clone.
  // GameTypeSelectionScreen owns the list; we mutate it in place.
  if (widget.selections.isNotEmpty) {
    _selections = widget.selections;
  } else {
    final playersPerPunter = widget.gameType == "weekend_quads" ? 4 : 2;
    _selections = List.generate(
      15,
      (i) => PunterSelection.empty(
        punterNumber: i + 1,
        playersPerPunter: playersPerPunter,
      ),
    );
  }

  // ⭐ Mark as completed immediately if all fixtures for this round are
  // in the past (more than 24 hours ago). This prevents live polling from
  // zeroing out scores for historical rounds.
  if (_isRoundHistorical()) {
    _isCompleted = true;
  }

  // Restore cached selections immediately (shows picks with zero delay)
  // Only restore if cache has real data (not just empty placeholder rows)
  if (cache != null && cache.hasSelections(cacheKey)) {
    final cached = cache.getSelections(cacheKey);
    final cachedHasData = cached.any((p) =>
        p.punterName.trim().isNotEmpty ||
        p.picks.any((pick) => pick.player != null));
    if (cachedHasData) {
      _selections = cached;
      debugPrint("✅ Restored selections from cache: $cacheKey count=${_selections.length}");
    } else {
      debugPrint("⚠️ Cache exists but empty — will reload from network");
    }
  } else {
    debugPrint("❌ No cached selections for: $cacheKey");
  }

  // Restore cached stats immediately (shows last-known data with zero delay)
  if (cache != null && cache.hasStats(cacheKey)) {
    _currentStatsByPlayerId = cache.getStats(cacheKey);
  }

  // Restore cached players immediately (skips the async load)
  if (cache != null && cache.hasPlayers(widget.season)) {
    _seasonPlayers = cache.getPlayers(widget.season);
    _loadingPlayers = false;
    _recomputeVisiblePunterCount();

    // Load known punter names for dropdown
    _fetchKnownPunterNames();
    // Enrich with averages if not yet done (fantasyScore still 0)
    if (_seasonPlayers!.every((p) => p.fantasyScore == 0)) {
      _enrichPlayerFantasyScores(_seasonPlayers!);
    }

    // Only fetch fresh snapshot from network if we have no prior data
    // Exclude placeholder names like P1, P2... from hasData check
    final hasData = _selections.any((p) {
      final name = p.punterName.trim();
      final isPlaceholder = RegExp(r'^P\d+$').hasMatch(name);
      return (!isPlaceholder && name.isNotEmpty) ||
          p.picks.any((pick) => pick.player != null);
    });

    if (!hasData) {
      // No cached data — load from network, don't mark snapshot loaded yet
      _loadSelectionsSnapshot().then((_) {
        _snapshotLoaded = true;
        // ⭐ Save selections to cache so returning to this game is instant
        cache.setSelections(cacheKey, _selections);
        if (mounted) setState(() {});
        _startLivePolling();
        // ⭐ Trigger a live stats refresh 5 seconds after load
        // so scores appear quickly without waiting for the next poll cycle
        if (!_isCompleted) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && !_isCompleted) _refreshLive();
          });
        }
      });
    } else {
      // ⭐ Have cached data — show immediately then refresh live
      _snapshotLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // For completed rounds, build stats from snapshot so grey shading works
        if (_isCompleted) {
          _buildStatsFromSnapshot();
          final tableState = _punterTableKey.currentState;
          if (tableState != null) {
            final dynamic dyn = tableState;
            dyn.applyLiveStatsToTable(_currentStatsByPlayerId);
          }
          _refreshFixtureScores();
        }
        setState(() {});
        if (!_isCompleted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !_isCompleted) _refreshLive();
          });
          _fetchCurrentTimestamp().then((_) => _startLivePolling());
        }
      });
    }
  } else {
    // First visit — load everything normally
    _loadSeasonPlayers().then((_) async {
      if (cache != null && _seasonPlayers != null) {
        cache.setPlayers(widget.season, _seasonPlayers!);
      }
      await _loadSelectionsSnapshot();
      _snapshotLoaded = true;
      if (mounted) setState(() {});
      _startLivePolling();
    });
  }
}

/// Returns true if all fixtures for this round finished more than 24 hours ago.
/// Used to skip live polling for historical rounds and preserve stored scores.
bool _isRoundHistorical() {
  if (widget.round == null) return false;

  final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
    widget.season,
    widget.round,
  );

  if (fixtures.isEmpty) return false;

  final cutoff = DateTime.now().subtract(const Duration(hours: 24));

  // All fixtures must have a date, and all must be before the cutoff
  return fixtures.every((f) => f.date != null && f.date!.isBefore(cutoff));
}

  @override
  void dispose() {
    _liveTimer?.cancel();
    _syncTimer?.cancel();
    _punterScrollController.dispose();
    _statsRefreshTick.dispose();
    super.dispose();
  }

  Future<void> _loadSeasonPlayers() async {
    try {
      final players = await widget.playerRepo.playersForSeason(widget.season);
      if (!mounted) return;
      setState(() {
        _seasonPlayers = players;
        _loadingPlayers = false;
      });
      // ⭐ Enrich players with season averages for dropdown sorting
      _enrichPlayerFantasyScores(players);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seasonPlayers = [];
        _loadingPlayers = false;
      });
    }
  }

  /// Fetches season average scores and sets fantasyScore on each AflPlayer
  /// so the player dropdown can be sorted by average.
  Future<void> _enrichPlayerFantasyScores(List<AflPlayer> players) async {
    try {
      final url = Uri.https(
        "fantasy-pairs-and-weekend-quads-production.up.railway.app",
        "/playerSeasonStats/${widget.season}",
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return;
      final json = jsonDecode(res.body);
      final statsJson = json["players"] as List<dynamic>? ?? [];
      // Build a map of playerId -> afAvg
      final avgMap = <String, int>{};
      for (final s in statsJson) {
        final pid = s["player_id"] as String? ?? "";
        final avg = (s["af_avg"] as num?)?.toInt() ?? 0;
        if (pid.isNotEmpty) avgMap[pid] = avg;
      }
      // Apply to player objects
      for (final p in players) {
        final avg = avgMap[p.id];
        if (avg != null && avg > 0) p.fantasyScore = avg;
      }
    } catch (_) {}
  }

  Future<void> _loadSelectionsSnapshot() async {
  try {
    final safeRound = widget.round ?? 0;

    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/loadSelections",
      {
        "gameType": widget.gameType,
        "season": widget.season.toString(),
        "round": safeRound.toString(),
      },
    );

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final data = json["data"];

      if (data is Map<String, dynamic>) {
        _applySnapshotToSelections(data);
        debugPrint("📋 After apply: ${_selections.where((p) => p.punterName.trim().isNotEmpty).length} named punters, ${_selections.where((p) => p.picks.any((pick) => pick.player != null)).length} with picks");
        if (mounted) setState(() {}); // Refresh table immediately after applying

        // ⭐ Track timestamp so we can detect remote changes
        final ts = (json["lastUpdated"] as num?)?.toInt() ?? 0;
        if (ts > 0) _lastKnownTimestamp = ts;

        // ⭐ For historical rounds, build stats map and refresh fixture scores
        if (_isCompleted) {
          if (_currentStatsByPlayerId.isEmpty) {
            _buildStatsFromSnapshot();
          }
          // Fetch real fixture scores from Squiggle (shows final scores on cards)
          _refreshFixtureScores();
        }
      }
    }
  } catch (e) {
    debugPrint("❌ Snapshot load failed: $e");
  } finally {
    _snapshotLoaded = true;
    if (mounted) setState(() {});
  }
}






/// Fetches final scores for all fixtures in this round from the backend.
/// Called once on load for historical rounds so fixture cards show real scores.
Future<void> _refreshFixtureScores() async {
  final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
    widget.season,
    widget.round,
  );
  for (final f in fixtures) {
    final matchId = f.matchId?.trim();
    if (matchId != null && matchId.isNotEmpty) {
      try {
        await widget.fixtureRepo.refreshLiveScores(matchId: matchId);
      } catch (_) {}
    }
  }
  if (mounted) setState(() {});
}

/// Builds _currentStatsByPlayerId from pick stats already loaded in _selections.
/// Used for historical rounds where the live DFS feed no longer has data,
/// so the stats overlay has real data without any network call.
void _buildStatsFromSnapshot() {
  final Map<String, AflPlayerMatchStats> statsMap = {};

  for (final selection in _selections) {
    for (final pick in selection.picks) {
      final player = pick.player;
      final stats = pick.stats;
      if (player == null || stats == null || stats.isEmpty) continue;

      int asInt(String key) {
        final v = stats[key];
        if (v is int) return v;
        if (v is double) return v.round();
        return int.tryParse(v?.toString() ?? "") ?? 0;
      }

      final s = AflPlayerMatchStats(
        player: player,
        team: player.club,
        kicks: asInt("K"),
        handballs: asInt("HB"),
        disposals: asInt("D"),
        marks: asInt("M"),
        tackles: asInt("T"),
        hitouts: asInt("HO"),
        freesFor: asInt("FF"),
        freesAgainst: asInt("FA"),
        goals: asInt("G"),
        behinds: asInt("B"),
        timeOnGroundPercentage: asInt("TOG"),
        fantasyPoints: asInt("AF"),
      );
      s.isCompletedGame = (asInt("AF") > 0);
      s.isLiveGame = false;
      statsMap[player.id] = s;
    }
  }

  if (statsMap.isNotEmpty) {
    _currentStatsByPlayerId = statsMap;
    debugPrint("✅ Built stats from snapshot: \${statsMap.length} players");
  }
}

void _applyLiveStats(List<AflPlayerMatchStats> stats) {
  final Map<String, AflPlayerMatchStats> map = Map<String, AflPlayerMatchStats>.from(_currentStatsByPlayerId);

  for (final s in stats) {
    try {
      if (s.player == null) continue;
      if (s.player!.id.isEmpty) continue;

      // Live + completed flags
      final completed = _isPlayerFromCompletedFixture(s);
      final live = _isPlayerInLiveFixture(s);

      s.isCompletedGame = completed;
      s.isLiveGame = live;

      // Only update if new stats have actual data (non-zero AF),
      // or if we don't have this player yet
      final existing = map[s.player!.id];
      final newAF = s.fantasyPoints;
      if (existing == null || (newAF != null && newAF > 0)) {
        map[s.player!.id] = s;
      }
    } catch (e) {
      debugPrint("⚠️ _applyLiveStats skip player: $e");
      continue;
    }
  }

  _currentStatsByPlayerId = map;

  // Notify any open StatsOverlay to rebuild with the latest stats
  _statsRefreshTick.value++;

  // ⭐ Write back to cache so returning to this game shows data instantly
  final cache = widget.gameDataCache;
  if (cache != null && map.isNotEmpty) {
    final key = "${widget.season}-${widget.round}-${widget.gameType}";
    cache.setStats(key, map);
    // Also save selections so cached scores are up to date on return
    cache.setSelections(key, _selections);
  }
}

  void _applySnapshotToSelections(Map<String, dynamic> data) {
  debugPrint("🔄 _applySnapshotToSelections: gameType=${widget.gameType} round=${widget.round} players=${_seasonPlayers?.length ?? 0} mounted=$mounted");
  // SAFETY: Do not restore snapshot until players are loaded
  if (_seasonPlayers == null || _seasonPlayers!.isEmpty) {
    debugPrint("⚠️ Players not loaded yet — retrying in 500ms");
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _applySnapshotToSelections(data);
        // Update cache with now-populated selections
        final cache = widget.gameDataCache;
        final cacheKey = "${widget.season}-${widget.round}-${widget.gameType}";
        if (cache != null) cache.setSelections(cacheKey, _selections);
        setState(() {});
      }
    });
    return;
  }

  final punterNames = (data["punterNames"] as List<dynamic>? ?? [])
      .map((e) => e?.toString() ?? "")
      .toList();

  final picksJson = (data["picks"] as List<dynamic>? ?? []);

  // Determine required row count — use actual data, no hardcoded minimum
  final snapshotRowCount = [
    punterNames.length,
    picksJson.length,
  ].reduce((a, b) => a > b ? a : b);

  final playersPerPunter = _selections.isNotEmpty
      ? _selections.first.picks.length
      : (widget.gameType == "weekend_quads" ? 4 : 2);

  // Ensure enough rows exist
  while (_selections.length < snapshotRowCount) {
    _selections.add(
      PunterSelection.empty(
        punterNumber: _selections.length + 1,
        playersPerPunter: playersPerPunter,
      ),
    );
  }

  // Restore names + picks
  for (int i = 0; i < _selections.length; i++) {
    final row = _selections[i];

    // Restore name
    if (i < punterNames.length) {
      row.punterName = punterNames[i].trim();
    }

    // Restore picks
    if (i >= picksJson.length) continue;
    final snapRow = picksJson[i];
    if (snapRow is! List) continue;

    for (int j = 0; j < row.picks.length; j++) {
      final pick = row.picks[j];

      if (j >= snapRow.length) {
        pick.player = null;
        pick.stats = <String, dynamic>{};
        continue;
      }

      final snapPick = snapRow[j];
      if (snapPick is! Map) {
        pick.player = null;
        pick.stats = <String, dynamic>{};
        continue;
      }

      final pid = (snapPick["playerId"] ?? "").toString().trim();
      if (pid.isEmpty) {
        pick.player = null;
        pick.stats = <String, dynamic>{};
        continue;
      }

      // Restore player
      final restored = _seasonPlayers!.where((p) => p.id == pid).toList();
      pick.player = restored.isEmpty
          ? AflPlayer(
              id: pid,
              name: "Unknown ($pid)",
              club: "UNK",
              guernseyNumber: 0,
              season: widget.season,
            )
          : restored.first;

      // Restore stats
      final rawStats = snapPick["stats"];
      pick.stats = rawStats is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawStats)
          : <String, dynamic>{};

      // ⭐ Restore fantasy points from stats so totalScore works
      final af = pick.stats?["AF"];
      if (af != null) {
        pick.fantasyPoints = af is int ? af : int.tryParse(af.toString()) ?? 0;
      }
    }
  }

  // Restore saved punter count if present in snapshot
  final savedCount = data["visiblePunterCount"];
  if (savedCount is int && savedCount > 0) {
    _visiblePunterCount  = savedCount;
    _punterCountManuallySet = true;
    if (savedCount > _maxPunterDropdown) _maxPunterDropdown = savedCount;
  } else {
    // Recompute visible punters (only if not manually set)
    _recomputeVisiblePunterCount();
  }

  debugPrint("✅ Snapshot applied: visible=$_visiblePunterCount, maxDrop=$_maxPunterDropdown");
}

  void _recomputeVisiblePunterCount() {
    // If the user has manually set the count, don't override it
    if (_punterCountManuallySet) return;

    final usedCount = _selections.where((p) {
      final name = p.punterName.trim();
      final hasRealName = name.isNotEmpty;
      final hasPick = p.picks.any((pick) => pick.player != null);
      return hasRealName || hasPick;
    }).length;

    // Use the actual active punter count, minimum 1
    _visiblePunterCount = usedCount > 0 ? usedCount : 15;
    _maxPunterDropdown = _visiblePunterCount > 25 ? _visiblePunterCount : 25;
  }

  Future<void> _fetchKnownPunterNames() async {
    try {
      final res = await http.get(Uri.parse(
        "https://fantasy-pairs-and-weekend-quads-production.up.railway.app/punterInsights?season=${widget.season}",
      ));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data['ok'] != true) return;
      final punters = data['punters'] as Map<String, dynamic>? ?? {};
      final names = punters.keys
          .where((n) => n.isNotEmpty && n[0] == n[0].toUpperCase() && n[0] != n[0].toLowerCase())
          .where((n) => !RegExp(r'\d').hasMatch(n))
          .where((n) => !RegExp(r'[*#@!]').hasMatch(n))
          .toList()
        ..sort();
      if (mounted) {
        setState(() => _knownPunterNames = names);
      }
    } catch (_) {
      // Silently fail — dropdown will just show names from current table
    }
  }



Future<void> _saveSnapshot() async {
  try {
    // Always save — even if all names are cleared, we need to persist that
    final safeRound = widget.round ?? 0;

    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/saveSelections",
    );

    // Clean punter names
    final punterNames = _selections
        .map((p) => p.punterName.toString().trim())
        .toList(growable: false);

    // Clean picks + stats
    final picks = _selections.map((p) {
      return p.picks.map((pick) {
        final stats = pick.stats;

        return {
          "playerId": pick.player?.id ?? "",
          "stats": (stats is Map<String, dynamic>)
              ? Map<String, dynamic>.from(stats)
              : <String, dynamic>{},
        };
      }).toList();
    }).toList();

    final body = jsonEncode({
      "gameType": widget.gameType,
      "season": widget.season,
      "round": safeRound,
      "punterNames": punterNames,
      "picks": picks,
      "visiblePunterCount": _visiblePunterCount,
    });

    final saveRes = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    // ⭐ Update our timestamp from the save response so we don't
    // immediately re-reload our own change
    if (saveRes.statusCode == 200) {
      try {
        final saveJson = jsonDecode(saveRes.body);
        final ts = (saveJson["lastUpdated"] as num?)?.toInt() ?? 0;
        if (ts > 0) _lastKnownTimestamp = ts;
      } catch (_) {}
      // ⭐ Update cache so switching games and back is instant
      final cache = widget.gameDataCache;
      final cacheKey = "${widget.season}-${widget.round}-${widget.gameType}";
      if (cache != null) cache.setSelections(cacheKey, _selections);
    }
  } catch (e) {
    debugPrint("❌ saveSnapshot failed: $e");
  }
}




 // -------------------------------------------------------------
  // ROUND-WIDE STATS FETCHER
  // -------------------------------------------------------------
  Future<Map<String, AflPlayerMatchStats>> _fetchRoundStats() async {
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    final matchIds = fixtures
        .map((f) => f.matchId?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (matchIds.isEmpty) return {};

    // Fetch all fixtures in parallel — cuts 9 sequential calls down to 1 round-trip
    final results = await Future.wait(
      matchIds.map((id) => MatchStatsParser.fetchMatchStats(
            id,
            widget.playerRepo,
            widget.fixtureRepo,
          ).catchError((_) => <AflPlayerMatchStats>[])),
    );

    final Map<String, AflPlayerMatchStats> roundStats = {};
    for (final statsList in results) {
      for (final s in statsList) {
        if (s.player != null) {
          roundStats[s.player!.id] = s;
        }
      }
    }

    return roundStats;
  }

  // ------------------------------------------------------------
  // NEW: Publish Custom Game (PUB‑A)
  // ------------------------------------------------------------
  Future<void> _publishCustomGame() async {
  try {
    final safeRound = widget.round ?? 0;

    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/saveSelections",
    );

    // Clean punter names
    final punterNames = _selections
        .map((p) => p.punterName.toString().trim())
        .toList(growable: false);

    // Clean picks + stats (same as _saveSnapshot)
    final picks = _selections.map((p) {
      return p.picks.map((pick) {
        final stats = pick.stats;

        return {
          "playerId": pick.player?.id ?? "",
          "stats": (stats is Map<String, dynamic>)
              ? Map<String, dynamic>.from(stats)
              : <String, dynamic>{},
        };
      }).toList();
    }).toList();

    final body = jsonEncode({
      "gameType": "custom_game",
      "season": widget.season,
      "round": safeRound,
      "punterNames": punterNames,
      "picks": picks,   // ✔ now defined
    });

    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (!mounted) return;

    // Persist the selected fixture IDs in the cache so they survive
    // navigation away from this screen and back.
    final safeRound2 = widget.round ?? 0;
    final cacheKey = "${widget.season}-$safeRound2-custom_game";
    if (widget.gameDataCache != null &&
        widget.selectedFixtureIds != null &&
        widget.selectedFixtureIds!.isNotEmpty) {
      widget.gameDataCache!.setFixtureIds(cacheKey, widget.selectedFixtureIds!);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          season: widget.season,
          round: widget.round,
          gameType: "custom_game",
          selections: _selections,
          fixtureRepo: widget.fixtureRepo,
          playerRepo: widget.playerRepo,
          fantasyService: widget.fantasyService,
          championshipService: widget.championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService: widget.userRoleService,
          selectedFixtureIds: widget.selectedFixtureIds,
          overridePlayers: widget.overridePlayers,
          gameDataCache: widget.gameDataCache,
        ),
      ),
    );
  } catch (_) {}
}


  // ------------------------------------------------------------
  // LIVE POLLING
  // ------------------------------------------------------------
  void _startLivePolling() {
  _liveTimer?.cancel();
  _liveTimer = Timer.periodic(
    const Duration(seconds: 5),
    (_) async {
      await _refreshLive();
    },
  );

  // ⭐ Live sync: poll for remote selection changes every 3 seconds.
  // If another admin has updated the selections, reload the snapshot.
  // Only runs when not completed (no need to sync historical rounds).
  _syncTimer?.cancel();
  if (!_isCompleted) {
    _syncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) async {
        await _checkForRemoteChanges();
      },
    );
  }
}

/// Fetches the current selection timestamp from the backend and stores it
/// as the baseline for future sync polling. Called when we skip the full
/// snapshot load (data already in cache) so polling has a valid baseline.
Future<void> _fetchCurrentTimestamp() async {
  try {
    final safeRound = widget.round ?? 0;
    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/selectionTimestamp",
      {
        "gameType": widget.gameType,
        "season": widget.season.toString(),
        "round": safeRound.toString(),
      },
    );
    final res = await http.get(url);
    if (res.statusCode != 200) return;
    final json = jsonDecode(res.body);
    final ts = (json["lastUpdated"] as num?)?.toInt() ?? 0;
    if (ts > 0) _lastKnownTimestamp = ts;
    debugPrint("📌 Baseline timestamp set: $_lastKnownTimestamp");
  } catch (_) {
    // Silent fail
  }
}

/// Polls the backend for the latest selection timestamp.
/// If newer than what we last loaded, reloads the full snapshot.
Future<void> _checkForRemoteChanges() async {
  if (!mounted) return;
  try {
    final safeRound = widget.round ?? 0;
    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/selectionTimestamp",
      {
        "gameType": widget.gameType,
        "season": widget.season.toString(),
        "round": safeRound.toString(),
      },
    );
    final res = await http.get(url);
    if (res.statusCode != 200) return;

    final json = jsonDecode(res.body);
    final remoteTs = (json["lastUpdated"] as num?)?.toInt() ?? 0;

    debugPrint("🔍 Sync check: remote=$remoteTs local=$_lastKnownTimestamp");

    // If remote is newer than what we have, reload
    if (remoteTs > 0 && remoteTs > _lastKnownTimestamp) {
      debugPrint("🔄 Remote changes detected — reloading selections");
      _lastKnownTimestamp = remoteTs; // update immediately to prevent re-trigger
      await _loadSelectionsSnapshot();

      // ⭐ For historical or non-live rounds, rebuild stats from snapshot
      // and push directly to table so live polling doesn't zero them out
      if (_isCompleted || _currentStatsByPlayerId.isEmpty) {
        _buildStatsFromSnapshot();
      }

      // ⭐ Push updated selections directly into the table widget
      final tableState = _punterTableKey.currentState;
      if (tableState != null && mounted) {
        final dynamic dyn = tableState;
        dyn.applyLiveStatsToTable(_currentStatsByPlayerId);
      }

      if (mounted) setState(() {});
    }
  } catch (_) {
    // Silent fail — sync is best-effort
  }
}

Future<void> _refreshLive({bool force = false}) async {
  if (_isCompleted && !force) return; // skip for completed rounds unless forced
  if (!mounted) return;

  try {
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season,
      widget.round,
    );

    // 1. Fetch player stats and fixture scores in parallel
    final fixtureRefreshFuture = Future.wait(
      fixtures
          .where((f) => (f.matchId?.trim() ?? '').isNotEmpty)
          .map((f) => widget.fixtureRepo
              .refreshLiveScores(matchId: f.matchId!.trim())
              .catchError((_) {})),
    );
    final roundStatsFuture = _fetchRoundStats();

    // 2. Wait for BOTH — fixture scores must be updated before we
    //    determine isLive (which checks quarterText on fixtures)
    await fixtureRefreshFuture;
    final roundStats = await roundStatsFuture;

    if (!mounted) return;

    // 3. Apply stats — fixture quarterText is now current so isLive is correct
    if (roundStats.isNotEmpty) {
      _applyLiveStats(roundStats.values.toList());
      final tableState = _punterTableKey.currentState;
      if (tableState != null && mounted) {
        final dynamic dyn = tableState;
        dyn.applyLiveStatsToTable(_currentStatsByPlayerId);
      }
      if (mounted) setState(() {});
    }

    // 4. Run completion checks now that fixture scores are updated
    if (!mounted) return;
    await _checkRoundCompletion(); // ⭐ async
    _finaliseFridayPairsWinner();
    _checkAndCompleteWeekendQuadsRound();

    // 5. Final setState to update fixture cards
    if (mounted) setState(() {});


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
    // ------------------------------------------------------------
  // ROUND COMPLETION + WEEKEND QUADS COMPLETION
  // ------------------------------------------------------------
  Future<void> _checkRoundCompletion() async {
  final fixtures = widget.fixtureRepo.fixturesForSeasonRound(
    widget.season,
    widget.round,
  );

  if (fixtures.isEmpty) return;

  final allComplete = fixtures.every((f) => f.complete);
  if (!allComplete) return;

  // ⭐ Stop live polling so we don't overwrite final results
  _liveTimer?.cancel();

  // ⭐ Final stats refresh
  final roundStats = await _fetchRoundStats();

  if (roundStats.isNotEmpty) {
    _applyLiveStats(roundStats.values.toList());
  }

  // ⭐ Sort ONLY for leaderboard
  

  // ⭐ Build final punter results for backend
  final punterResults = widget.fantasyService.buildCompletedRoundResults(
    selections: _selections,
    statsByPlayerId: _currentStatsByPlayerId,
  );

  // ⭐ Save completed round results to backend
  await widget.roundCompletionService.saveRoundResults(
    season: widget.season,
    round: widget.round ?? 0,
    gameType: widget.gameType,
    punters: punterResults,
  );

  // ⭐ Mark completed locally + save snapshot
  widget.roundCompletionService.markCompleted(widget.round);
  await _saveSnapshot();

  setState(() => _isCompleted = true);

  debugPrint(
    "✅ Round completed: season=${widget.season}, round=${widget.round}, gameType=${widget.gameType}",
  );
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

    widget.championshipService.addRound(month, _selections,
        roundNumber: widget.round ?? 0);
    _saveSnapshot();

    debugPrint("🏆 Weekend Quads completed for $month");
  }

  // ------------------------------------------------------------
  // FIXTURE FILTERING (custom_pairs removed)
  // ------------------------------------------------------------
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

      // ⭐ custom_pairs removed (CP‑B)
      // custom_builder + custom_game use ALL fixtures
      case "custom_builder":
      case "custom_game":
        return all;

      default:
        return all;
    }
  }

  // ------------------------------------------------------------
  // LABEL HELPERS
  // ------------------------------------------------------------
  String _monthName(int m) {
    const names = [
      "January","February","March","April","May","June",
      "July","August","September","October","November","December"
    ];
    return names[m - 1];
  }

  String _quarterLabel(AflFixture f) {
    if (f.complete) return "FT";
    if ((f.quarterText ?? '').isNotEmpty) return f.quarterText!;
    return "";
  }

  String _timeLabel(AflFixture f) {
    if (f.complete) return "FT";
    if (f.timeText.isNotEmpty) return f.timeText;

    // Pre-game: convert the stored UTC time (parsed from AEST spreadsheet)
    // to the device's local timezone so punters in WA, SA etc see local time.
    if (f.date != null) {
      final local = f.date!.toLocal();
      final h = local.hour;
      final m = local.minute;
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final ampm = h < 12 ? 'am' : 'pm';
      final minStr = m.toString().padLeft(2, '0');
      return '$hour12.${minStr}$ampm';
    }

    if ((f.time ?? '').isNotEmpty) return f.time!;
    return "--:--";
  }

  String _metaText(AflFixture f) {
    if (f.complete) return "FT";
    final q = _quarterLabel(f);
    final t = _timeLabel(f);
    if (q.isEmpty && t.isEmpty) return "";
    if (q.isEmpty) return t;
    if (t.isEmpty) return q;
    return "$q • $t";
  }

  String _gameTypeLabel() {
    switch (widget.gameType) {
      case "thursday_pairs": return "Thursday Pairs";
      case "friday_pairs": return "Friday Pairs";
      case "saturday_pairs": return "Saturday Pairs";
      case "sunday_pairs": return "Sunday Pairs";
      case "monday_pairs": return "Monday Pairs";
      case "weekend_quads": return "Weekend Quads";
      case "custom_builder": return "Custom Builder";
      case "custom_game": return "Custom Game";
      default: return widget.gameType;
    }
  }

  /// All standard game types available for navigation
  static const List<Map<String, String>> _navGameTypes = [
    {"key": "thursday_pairs",  "label": "Thursday Pairs"},
    {"key": "friday_pairs",    "label": "Friday Pairs"},
    {"key": "saturday_pairs",  "label": "Saturday Pairs"},
    {"key": "sunday_pairs",    "label": "Sunday Pairs"},
    {"key": "monday_pairs",    "label": "Monday Pairs"},
    {"key": "weekend_quads",   "label": "Weekend Quads"},
  ];

  /// Builds the AppBar title: [Game Type ▼]  ◀  [Round ▼]  ▶
  Widget _buildAppBarTitle(bool compact) {
    final allRounds = widget.fixtureRepo.allRoundsForSeason(widget.season);
    final currentRound = widget.round ?? 0;
    final currentIndex = allRounds.indexOf(currentRound);
    // Guard: if current round not in list, disable navigation
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < allRounds.length - 1;

    final labelSize = compact ? 12.0 : 14.0;
    final iconSize = compact ? 16.0 : 18.0;
    final btnPad = compact ? 2.0 : 4.0;

    // Only show standard game types in the dropdown (not custom)
    final isCustom = widget.gameType == "custom_builder" ||
        widget.gameType == "custom_game";

    return Row(
      children: [
        // ── Game type dropdown ──────────────────────────────
        if (isCustom)
          Flexible(
            child: Text(
              _gameTypeLabel(),
              style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _navGameTypes.any((g) => g["key"] == widget.gameType)
                  ? widget.gameType
                  : null,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
              dropdownColor: const Color(0xFF1A1A2E),
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              items: _navGameTypes.map((g) {
                return DropdownMenuItem<String>(
                  value: g["key"],
                  child: Text(
                    g["label"]!,
                    style: TextStyle(
                      fontSize: labelSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null && type != widget.gameType) {
                  _navigateTo(round: currentRound, gameType: type);
                }
              },
            ),
          ),

        // ── Round navigation ────────────────────────────────
        IconButton(
          icon: Icon(Icons.chevron_left, size: iconSize),
          padding: EdgeInsets.all(btnPad),
          constraints: const BoxConstraints(),
          tooltip: hasPrev ? RoundHelper.label(allRounds[currentIndex - 1]) : null,
          onPressed: (hasPrev && currentIndex >= 1)
              ? () => _navigateTo(
                  round: allRounds[currentIndex - 1],
                  gameType: widget.gameType)
              : null,
        ),

        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: currentRound,
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
            dropdownColor: const Color(0xFF1A1A2E),
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            items: allRounds.map((r) {
              return DropdownMenuItem<int>(
                value: r,
                child: Text(
                  RoundHelper.label(r),
                  style: TextStyle(
                    fontSize: labelSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (r) {
              if (r != null && r != currentRound) {
                _navigateTo(round: r, gameType: widget.gameType);
              }
            },
          ),
        ),

        IconButton(
          icon: Icon(Icons.chevron_right, size: iconSize),
          padding: EdgeInsets.all(btnPad),
          constraints: const BoxConstraints(),
          tooltip: hasNext ? RoundHelper.label(allRounds[currentIndex + 1]) : null,
          onPressed: (hasNext && currentIndex >= 0 && currentIndex + 1 < allRounds.length)
              ? () => _navigateTo(
                  round: allRounds[currentIndex + 1],
                  gameType: widget.gameType)
              : null,
        ),
      ],
    );
  }

  /// Navigate to any combination of round + game type.
  void _navigateTo({required int round, required String gameType}) {
    _liveTimer?.cancel();
    _syncTimer?.cancel();

    // ⭐ Save current selections to cache before leaving
    // Only cache if we have real data (punter names or picks)
    final cache = widget.gameDataCache;
    final cacheKey = "${widget.season}-${widget.round}-${widget.gameType}";
    if (cache != null) cache.setSelections(cacheKey, _selections);

    // For custom games, pass selectedFixtureIds through so they persist
    // when navigating between rounds or back to the same game type.
    final fixtureIds = widget.selectedFixtureIds;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          season: widget.season,
          round: round,
          gameType: gameType,
          selections: const [],
          fixtureRepo: widget.fixtureRepo,
          playerRepo: widget.playerRepo,
          fantasyService: widget.fantasyService,
          championshipService: widget.championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService: widget.userRoleService,
          gameDataCache: widget.gameDataCache,
          selectedFixtureIds: fixtureIds,
        ),
      ),
    );
  }

  Map<String, dynamic> _mapStats(AflPlayerMatchStats s) {
  return {
    "playerId": s.player?.id,
    "playerName": s.player?.name,
    "team": s.team,

    // DO NOT read guernsey from stats — it does not exist
    // guernsey is injected later by _enrichStatsWithPlayerData

    "Player": s.player?.name ?? "Unknown",
    "AF": s.fantasyPoints ?? 0,
    "K": s.kicks ?? 0,
    "HB": s.handballs ?? 0,
    "D": s.disposals ?? 0,
    "M": s.marks ?? 0,
    "T": s.tackles ?? 0,
    "HO": s.hitouts ?? 0,
    "FF": s.freesFor ?? 0,
    "FA": s.freesAgainst ?? 0,
    "G": s.goals ?? 0,
    "B": s.behinds ?? 0,
    "TOG": s.timeOnGroundPercentage ?? 0,
  };
}

void _enrichStatsWithPlayerData(List<Map<String, dynamic>> rows) {
  for (final row in rows) {
    final id = row["playerId"] ?? row["id"];
    if (id == null) continue;

    // ⭐ Correct method for your PlayerRepository
    final p = widget.playerRepo.getById(id, widget.season);
    if (p == null) continue;

    row["guernseyNumber"] = p.guernseyNumber;
    row["team"] = p.club;        // MELB, ESS, etc.
    row["playerName"] = p.name;  // ensures consistent formatting
  }
}

  // ------------------------------------------------------------
  // MAIN BUILD
  // ------------------------------------------------------------
  @override
Widget build(BuildContext context) {
  // ⭐ Do not build table until BOTH players AND snapshot are loaded
  if (_loadingPlayers || !_snapshotLoaded) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: CircularProgressIndicator()),
    );
  }


    final allFixtures = _fixturesForGameType();

    var fixtures = allFixtures;
    if (widget.selectedFixtureIds != null &&
        widget.selectedFixtureIds!.isNotEmpty) {
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
          titleSpacing: 4,
          title: _buildAppBarTitle(isLandscapePhone),
          actions: [
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              tooltip: 'Screenshot mode',
              onPressed: _openScreenshotMode,
            ),
          ],
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

  // ------------------------------------------------------------
  // FIXTURE STRIP
  // ------------------------------------------------------------
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

  // ------------------------------------------------------------
  // FRIDAY PAIRS TRIGGER
  // ------------------------------------------------------------
  void _handleFridayPairsTrigger(AflFixture f) {
    if (widget.gameType != "friday_pairs") return;
    if (_fridayWinnerSelected) return;

    final isLive = (f.quarterText ?? '').isNotEmpty && !f.complete;
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
  }

  // ------------------------------------------------------------
  // FIXTURE CARD
  // ------------------------------------------------------------
  Widget _buildFixtureCard(AflFixture f) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final selected = f == _selectedFixture;
    _handleFridayPairsTrigger(f);

    final homeScore = f.homeScore;
    final awayScore = f.awayScore;
    final homeWinning = homeScore > awayScore;
    final awayWinning = awayScore > homeScore;

    final quarterLabel = _quarterLabel(f);
    final isLive = !f.complete && quarterLabel.isNotEmpty;

    final metaText = _metaText(f);

    final scoreBaseStyle = TextStyle(
      fontSize: isLandscapePhone ? 12 : 13,
      fontWeight: FontWeight.w500,
      color: cs.onSurface,
    );

    final metaStyle = TextStyle(
      fontSize: isLandscapePhone ? 10 : 11,
      fontWeight: FontWeight.w500,
      color: isLive ? Colors.red.shade400 : Colors.grey.shade400,
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


Future<void> _forceApplyStats() async {
  final tableState = _punterTableKey.currentState;
  if (tableState != null) {
    final dynamic dyn = tableState;
    dyn.applyLiveStatsToTable(_currentStatsByPlayerId);
  }

  if (mounted) setState(() {});
}


  // ------------------------------------------------------------
  // FIXTURE TAP → STATS OVERLAY
  // ------------------------------------------------------------
  Future<void> _onFixtureTap(AflFixture f) async {
  setState(() => _selectedFixture = f);

  final matchId = f.matchId?.trim();
  if (matchId == null || matchId.isEmpty) return;

  final homeTeam = f.homeTeam;
  final awayTeam = f.awayTeam;

  const columns = ["Player","AF","K","HB","D","M","T","HO","FF","FA","G","B","TOG"];

  // ⭐ For historical rounds, fetch full match stats from backend ONCE.
  // Live rounds use _currentStatsByPlayerId which auto-refreshes via the
  // _statsRefreshTick notifier passed into the overlay.
  List<AflPlayerMatchStats>? historicalStats;
  if (_isCompleted) {
    try {
      historicalStats = await MatchStatsParser.fetchMatchStats(
        matchId,
        widget.playerRepo,
        widget.fixtureRepo,
      );
    } catch (_) {
      historicalStats = null;
    }
  }

  // Builds rows from the freshest stats source on every rebuild.
  // For completed rounds: uses the snapshot fetched above.
  // For live rounds: reads _currentStatsByPlayerId which is updated every
  // 5 seconds by _applyLiveStats.
  ({List<Map<String, dynamic>> left, List<Map<String, dynamic>> right}) buildRows() {
    final stats = historicalStats ?? _currentStatsByPlayerId.values.toList();
    final rowsA = stats.where((s) => s.player?.club == homeTeam).map(_mapStats).toList();
    final rowsB = stats.where((s) => s.player?.club == awayTeam).map(_mapStats).toList();
    _enrichStatsWithPlayerData(rowsA);
    _enrichStatsWithPlayerData(rowsB);
    return (left: rowsA, right: rowsB);
  }

  if (!mounted) return;

  showDialog<void>(
    context: context,
    builder: (_) => StatsOverlay(
      leftTitle: homeTeam,
      rightTitle: awayTeam,
      columns: columns,
      buildRows: buildRows,
      refreshTick: _statsRefreshTick,
      noStatsMessage: "No stats available yet",
    ),
  );
}
    // ------------------------------------------------------------
  // PUNTER CONTROLS (with Publish button for custom_builder)
  // ------------------------------------------------------------
  Widget _buildPunterControls() {
  final theme = Theme.of(context);

  return ClipRect(
    child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: _controlsCollapsed ? 32 : null,
    padding: EdgeInsets.symmetric(
      vertical: _controlsCollapsed ? 0 : (isLandscapePhone ? 2 : 4),
    ),
    child: Column(
      children: [
        // ------------------------------------------------------------
        // HEADER BAR (collapsible)
        // ------------------------------------------------------------
        InkWell(
          onTap: () => setState(() => _controlsCollapsed = !_controlsCollapsed),
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
                    setState(() => _leaderboardCollapsed = !_leaderboardCollapsed);
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

        // ------------------------------------------------------------
        // EXPANDED CONTROLS
        // ------------------------------------------------------------
        if (!_controlsCollapsed)
          Row(
            children: [
              // ------------------------------------------------------------
              // PUNTER COUNT DROPDOWN
              // ------------------------------------------------------------
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
                    items: [
                      ...List.generate(_maxPunterDropdown, (i) => i + 1)
                          .map((v) => DropdownMenuItem<int>(
                                value: v,
                                child: Text("$v"),
                              )),
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text("Custom…"),
                      ),
                    ],
                    onChanged: (widget.userRoleService.isAdmin && !_isSubmitted)
                        ? (value) async {
                            if (value == null) return;

                            if (value == -1) {
                              final controller = TextEditingController();

                              final custom = await showDialog<int>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Custom punter count"),
                                  content: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: "Enter number (e.g., 30)",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        final n = int.tryParse(
                                            controller.text.trim());
                                        Navigator.pop(context, n);
                                      },
                                      child: const Text("OK"),
                                    ),
                                  ],
                                ),
                              );

                              if (custom != null && custom > 0) {
                                setState(() {
                                  _punterCountManuallySet = true;
                                  _maxPunterDropdown = custom > 25 ? custom : 25;
                                  _visiblePunterCount = custom;

                                  while (_selections.length < custom) {
                                    _selections.add(
                                      PunterSelection.empty(
                                        punterNumber: _selections.length + 1,
                                        playersPerPunter:
                                            widget.selections.first.picks.length,
                                      ),
                                    );
                                  }
                                });

                                _saveSnapshot();
                              }

                              return;
                            }

                            setState(() {
                              _punterCountManuallySet = true;
                              _visiblePunterCount = value;

                              // Grow _selections to match chosen count
                              final playersPerPunter = _selections.isNotEmpty
                                  ? _selections.first.picks.length
                                  : (widget.gameType == "weekend_quads" ? 4 : 2);
                              while (_selections.length < value) {
                                _selections.add(
                                  PunterSelection.empty(
                                    punterNumber: _selections.length + 1,
                                    playersPerPunter: playersPerPunter,
                                  ),
                                );
                              }
                            });
                            // Save after setState so snapshot includes new rows
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _saveSnapshot();
                            });
                          }
                        : null,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ------------------------------------------------------------
              // TIMESTAMP LABEL
              // ------------------------------------------------------------
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withAlpha(64),
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

              const SizedBox(width: 12),

              // ------------------------------------------------------------
              // UPDATE BUTTON (admin only)
              // ------------------------------------------------------------
              if (widget.userRoleService.isAdmin)
                ElevatedButton(
                  onPressed: () async {
                    await _refreshLive(force: true); // fetch stats even for completed rounds
                    await _forceApplyStats();         // reapply to table
                    await _saveSnapshot();            // persist snapshot
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    "Update",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              if (widget.userRoleService.isAdmin)
                GestureDetector(
                  onTap: () => setState(() => _showAveragePreview = !_showAveragePreview),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showAveragePreview
                          ? Colors.orange.shade700
                          : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showAveragePreview ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showAveragePreview ? "AVG ON" : "AVG",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              // ------------------------------------------------------------
              // PUBLISH BUTTON (custom_builder only)
              // ------------------------------------------------------------
              if (isCustomBuilder && widget.userRoleService.isAdmin)
                ElevatedButton(
                  onPressed: _publishCustomGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    "Publish",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

              const Spacer(),
            ],
          ),
      ],
    ),
  ),
  ); // ClipRect
}



  // ------------------------------------------------------------
  // PUNTER TABLE + LEADERBOARD
  // ------------------------------------------------------------
  Widget _buildPunterAndLeaderboard({
  required List<AflPlayer> players,
  required List<PunterSelection> selections, // ← no longer used
}) {
  return Expanded(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);

        final picks = widget.gameType == "weekend_quads" ? 4 : 2;

        final leaderboardWidth = _leaderboardCollapsed
            ? UIDimensions.collapsedLeaderboardWidth
            : UIDimensions.rankColumnWidth +
                UIDimensions.punterNameColumnWidth +
                UIDimensions.totalColumnWidth;

        final int safeRound = widget.round ?? 0;

        if (_loadingPlayers) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_seasonPlayers == null || _seasonPlayers!.isEmpty) {
          return const Center(child: Text("Failed to load players"));
        }

        // Determine available players
        final seasonPlayers = _seasonPlayers!;
        List<AflPlayer> availablePlayers;

        if (isCustomBuilder || isCustomGame) {
          availablePlayers = (widget.overridePlayers?.isNotEmpty ?? false)
              ? widget.overridePlayers!
              : seasonPlayers;
        } else {
          final fixtures = _fixturesForGameType();
          final fixtureClubCodes =
              fixtures.expand((f) => [f.homeTeam, f.awayTeam]).toSet();

          availablePlayers = seasonPlayers
              .where((p) => p.club.isNotEmpty)
              .where((p) => fixtureClubCodes.contains(p.club))
              .toList();
        }

        final bool readOnly =
            !widget.userRoleService.isAdmin && !isCustomBuilder;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withAlpha(64),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------------------
              // ⭐ PUNTER TABLE
              // ------------------------------------------------------------
              Expanded(
                child: LayoutBuilder(
                  builder: (context, tableConstraints) {
                    // Mirror _minTableWidth from PunterSelectionTable so we
                    // know when to enable horizontal scrolling in portrait.
                    final isPortrait = MediaQuery.of(context).size.height >
                        MediaQuery.of(context).size.width;
                    final punterCol = isPortrait ? 60.0 : 62.0;
                    final pickCol = isPortrait ? 130.0 : 130.0;
                    final scoreCol = isPortrait ? 28.0 : 28.0;
                    final totalCol = isPortrait ? 36.0 : 36.0;
                    final minW = punterCol +
                        picks * (pickCol + scoreCol) +
                        totalCol;
                    final effectiveWidth =
                        tableConstraints.maxWidth < minW
                            ? minW
                            : tableConstraints.maxWidth;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: effectiveWidth,
                        child: PunterSelectionTable(
                          key: _punterTableKey,

                          gameType: widget.gameType,
                          season: widget.season,
                          round: safeRound,
                          tableWidth: null,
                          visiblePunterCount: _visiblePunterCount,
                          playersPerPunter: picks,
                          availablePlayers: availablePlayers,
                          isPlayerCompleted: _isPlayerFromCompletedFixture,

                          // ⭐ CRITICAL: use _selections (the live list)
                          selections: _selections,

                          isCompleted: _isCompleted,
                          readOnly: readOnly,
                          onChanged: (!readOnly)
                              ? () {
                                  _recomputeVisiblePunterCount();
                                  _saveSnapshot();
                                  setState(() {});
                                }
                              : null,
                          collapsed: _leaderboardCollapsed,
                          scrollController: _punterScrollController,
                          fantasyService: widget.fantasyService,
                          userRoleService: widget.userRoleService,
                          knownPunterNames: _knownPunterNames,
                          showAveragePreview: _showAveragePreview,
                          allPlayers: _seasonPlayers ?? [],
                          onTimestampChanged: (t) {
                            setState(() => _timestampLabel = t);
                          },
                          onLiveScoreUpdateSave: null,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ------------------------------------------------------------
              // ⭐ LEADERBOARD (must use SAME list)
              // ------------------------------------------------------------
              SizedBox(
                width: leaderboardWidth,
                child: LeaderboardPanel(
                  // ⭐ CRITICAL: use _selections, not the stale parameter
                  punters: _sortedSelections().take(_visiblePunterCount).toList(),
                  rowHeight: UIDimensions.rowHeight,
                  collapsed: _leaderboardCollapsed,
                  scrollController: _punterScrollController,
                  showAveragePreview: _showAveragePreview,
                  allPlayers: _seasonPlayers ?? [],
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

// ── Screenshot mode ─────────────────────────────────────────────────────────

  List<AflPlayer> _availablePlayers() {
    final seasonPlayers = _seasonPlayers;
    if (seasonPlayers == null || seasonPlayers.isEmpty) return [];
    if (isCustomBuilder || isCustomGame) {
      return (widget.overridePlayers?.isNotEmpty ?? false)
          ? widget.overridePlayers!
          : seasonPlayers;
    }
    final fixtures  = _fixturesForGameType();
    final clubCodes = fixtures.expand((f) => [f.homeTeam, f.awayTeam]).toSet();
    return seasonPlayers
        .where((p) => p.club.isNotEmpty)
        .where((p) => clubCodes.contains(p.club))
        .toList();
  }

  void _openScreenshotMode() {
    if (_seasonPlayers == null || _seasonPlayers!.isEmpty) return;
    ScreenshotOverlay.show(
      context,
      selections:         _selections,
      sortedSelections:   _sortedSelections(),
      visiblePunterCount: _visiblePunterCount,
      gameType:           widget.gameType,
      season:             widget.season,
      round:              widget.round ?? 0,
      availablePlayers:   _availablePlayers(),
      allPlayers:         _seasonPlayers ?? [],
      fantasyService:     widget.fantasyService,
      userRoleService:    widget.userRoleService,
      isPlayerCompleted:  _isPlayerFromCompletedFixture,
      showAveragePreview: _showAveragePreview,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  List<PunterSelection> _sortedSelections() {
  final list = List<PunterSelection>.from(_selections);
  if (_showAveragePreview) {
    final players = _seasonPlayers ?? [];
    list.sort((a, b) => b.avgScore(players).compareTo(a.avgScore(players)));
  } else {
    list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
  }
  return list;
}

  // ------------------------------------------------------------
  // MAIN CONTENT
  // ------------------------------------------------------------
  Widget _buildMainContent() {
    final allPlayers = (widget.overridePlayers?.isNotEmpty ?? false)
        ? widget.overridePlayers!
        : _seasonPlayers!;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPunterControls(),
          const SizedBox(height: 6),
          _buildPunterAndLeaderboard(
            players: allPlayers,
            selections: _selections,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ------------------------------------------------------------
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

    final playerClubs =
        seasonPlayers.map((p) => p.club.trim().toUpperCase()).toSet();

    final missingInPlayers = fixtureClubs.difference(playerClubs);
    final missingInFixtures = playerClubs.difference(fixtureClubs);


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