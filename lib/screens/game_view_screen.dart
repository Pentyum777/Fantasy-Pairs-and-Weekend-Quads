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
  debugPrint("---- Checking completion for ${s.player?.name} ----");
  debugPrint("Stats team (normalised) = '$team'");

  if (team.isEmpty) {
    debugPrint("❌ No team found in stats → NOT completed");
    return false;
  }

  for (final f in fixtures) {
    final home = AflClubCodes.normalize(f.homeTeam);
    final away = AflClubCodes.normalize(f.awayTeam);

    debugPrint(
      "Fixture: ${f.homeTeam} vs ${f.awayTeam} | complete=${f.complete} "
      "| home='$home' away='$away'"
    );

    if (f.complete && (team == home || team == away)) {
      debugPrint("✔ MATCH: $team belongs to a completed fixture");
      return true;
    }
  }

  debugPrint("✘ NO MATCH: $team did not match any completed fixture");
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
  final q = f.quarterText.toLowerCase().trim();

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

  // Restore cached stats immediately (shows last-known data with zero delay)
  if (cache != null && cache.hasStats(cacheKey)) {
    _currentStatsByPlayerId = cache.getStats(cacheKey);
  }

  // Restore cached players immediately (skips the async load)
  if (cache != null && cache.hasPlayers(widget.season)) {
    _seasonPlayers = cache.getPlayers(widget.season);
    _loadingPlayers = false;
    _recomputeVisiblePunterCount();
    _snapshotLoaded = true;

    // Only fetch fresh snapshot from network if we have no prior data
    final hasData = _selections.any((p) =>
        p.punterName.trim().isNotEmpty ||
        p.picks.any((pick) => pick.player != null));

    if (!hasData) {
      _loadSelectionsSnapshot().then((_) {
        _snapshotLoaded = true;
        if (mounted) setState(() {});
        _startLivePolling();
      });
    } else {
      // ⭐ Even when we skip the full snapshot load (data already cached),
      // fetch the current timestamp so the sync polling has a baseline.
      _fetchCurrentTimestamp().then((_) => _startLivePolling());
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seasonPlayers = [];
        _loadingPlayers = false;
      });
    }
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

        // ⭐ Track timestamp so we can detect remote changes
        final ts = (json["lastUpdated"] as num?)?.toInt() ?? 0;
        if (ts > 0) _lastKnownTimestamp = ts;

        // ⭐ For historical rounds, build stats map from snapshot data
        if (_isCompleted && _currentStatsByPlayerId.isEmpty) {
          _buildStatsFromSnapshot();
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
      s.isCompletedGame = true;
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
  final Map<String, AflPlayerMatchStats> map = {};

  for (final s in stats) {
  if (s.player == null) continue;

  // ⭐ ENRICH: ensure player object is fully populated
  final p = widget.playerRepo.getById(s.player!.id, widget.season);
  if (p != null) {
   
  }

  // Live + completed flags
  final completed = _isPlayerFromCompletedFixture(s);
  final live = _isPlayerInLiveFixture(s);

  s.isCompletedGame = completed;
  s.isLiveGame = live;

  map[s.player!.id] = s;
}

  _currentStatsByPlayerId = map;

  // ⭐ Write back to cache so returning to this game shows data instantly
  final cache = widget.gameDataCache;
  if (cache != null && map.isNotEmpty) {
    final key = "${widget.season}-${widget.round}-${widget.gameType}";
    cache.setStats(key, map);
  }
}

  void _applySnapshotToSelections(Map<String, dynamic> data) {
  // SAFETY: Do not restore snapshot until players are loaded
  if (_seasonPlayers == null || _seasonPlayers!.isEmpty) {
    debugPrint("⚠️ Players not loaded yet — delaying snapshot restore");
    return;
  }

  final punterNames = (data["punterNames"] as List<dynamic>? ?? [])
      .map((e) => e?.toString() ?? "")
      .toList();

  final picksJson = (data["picks"] as List<dynamic>? ?? []);

  // Determine required row count
  final snapshotRowCount = [
    punterNames.length,
    picksJson.length,
    15, // minimum default
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

  // Recompute visible punters
  _recomputeVisiblePunterCount();

  // Sync dropdown to real count
  _maxPunterDropdown = _visiblePunterCount;

  debugPrint("✅ Snapshot applied: visible=$_visiblePunterCount, maxDrop=$_maxPunterDropdown");
}

  void _recomputeVisiblePunterCount() {
  final usedCount = _selections.where((p) {
    final name = p.punterName.trim();
    final hasRealName = name.isNotEmpty;
    final hasPick = p.picks.any((pick) => pick.player != null);
    return hasRealName || hasPick;
  }).length;

  if (usedCount > 0) {
    _visiblePunterCount = usedCount;
  } else {
    _visiblePunterCount = 15;
  }

  // Always sync dropdown to real count
  _maxPunterDropdown = _visiblePunterCount;
}



Future<void> _saveSnapshot() async {
  try {
    final hasAny = _selections.any((p) {
      final name = p.punterName.trim();
      final hasRealName = name.isNotEmpty;
      final hasPick = p.picks.any((pick) => pick.player != null);
      return hasRealName || hasPick;
    });

    if (!hasAny) return;

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

    final Map<String, AflPlayerMatchStats> roundStats = {};

    for (final f in fixtures) {
      final matchId = f.matchId?.trim();
      if (matchId == null || matchId.isEmpty) continue;

      // ⭐ Correct: use your existing backend parser
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
    if (remoteTs > _lastKnownTimestamp && _lastKnownTimestamp > 0) {
      debugPrint("🔄 Remote changes detected — reloading selections");
      _lastKnownTimestamp = remoteTs; // update immediately to prevent re-trigger
      await _loadSelectionsSnapshot();
      if (mounted) setState(() {});
    }
  } catch (_) {
    // Silent fail — sync is best-effort
  }
}

Future<void> _refreshLive() async {
  if (_isCompleted) return; // ⭐ do not overwrite final results

  try {
    // 1. Refresh live scores for each fixture
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

    // 2. Run completion checks + special logic
    await _checkRoundCompletion(); // ⭐ async
    _finaliseFridayPairsWinner();
    _checkAndCompleteWeekendQuadsRound();

    // 3. Always fetch fresh stats
    final roundStats = await _fetchRoundStats();
    debugPrint("ROUND STATS COUNT = ${roundStats.length}");

    // 4. Apply completion flags + build stats map
    if (roundStats.isNotEmpty) {
      _applyLiveStats(roundStats.values.toList());
    }

    // 5. Push stats into the punter table
    final tableState = _punterTableKey.currentState;
    if (tableState != null && mounted) {
      final dynamic dyn = tableState;
      dyn.applyLiveStatsToTable(_currentStatsByPlayerId);
    }

 
    // 7. Rebuild UI
    setState(() {});
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
    if (f.quarterText.isNotEmpty) return f.quarterText;
    return "";
  }

  String _timeLabel(AflFixture f) {
    if (f.complete) return "FT";
    if (f.timeText.isNotEmpty) return f.timeText;
    if (f.time.isNotEmpty) return f.time;
    return "--:--";
  }

  String _metaText(AflFixture f) {
    if (f.complete) return "FT";
    final q = _quarterLabel(f);
    final t = _timeLabel(f);
    if (q.isEmpty) return t;
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
              icon: const Icon(Icons.arrow_drop_down, size: 14),
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w600,
              ),
              items: _navGameTypes.map((g) {
                return DropdownMenuItem<String>(
                  value: g["key"],
                  child: Text(g["label"]!,
                      style: TextStyle(fontSize: labelSize)),
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
            icon: const Icon(Icons.arrow_drop_down, size: 14),
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
            ),
            items: allRounds.map((r) {
              return DropdownMenuItem<int>(
                value: r,
                child: Text(RoundHelper.label(r),
                    style: TextStyle(fontSize: labelSize)),
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

  final stats = _currentStatsByPlayerId.values.toList();

  final homeTeam = f.homeTeam;
  final awayTeam = f.awayTeam;

  final rowsA =
      stats.where((s) => s.player?.club == homeTeam).map(_mapStats).toList();

  final rowsB =
      stats.where((s) => s.player?.club == awayTeam).map(_mapStats).toList();

  // ⭐ PATCH 2 — ENRICH ROWS WITH PLAYER DATA
  _enrichStatsWithPlayerData(rowsA);
  _enrichStatsWithPlayerData(rowsB);

  final noStats = rowsA.isEmpty && rowsB.isEmpty;

  const columns = [
    "Player","AF","K","HB","D","M","T","G","B",
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
    // ------------------------------------------------------------
  // PUNTER CONTROLS (with Publish button for custom_builder)
  // ------------------------------------------------------------
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
                                  _maxPunterDropdown = custom;
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

                            setState(() => _visiblePunterCount = value);
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
                    await _refreshLive();      // fetch latest stats
                    await _forceApplyStats();  // force reapply even if unchanged
                    await _saveSnapshot();     // persist snapshot
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
  );
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
                child: PunterSelectionTable(
                  key: _punterTableKey,

                  gameType: widget.gameType,
                  season: widget.season,
                  round: safeRound,
                  tableWidth: null,
                  visiblePunterCount: _visiblePunterCount,
                  playersPerPunter: picks,
                  availablePlayers: availablePlayers,
                  isPlayerCompleted: _isPlayerFromCompletedFixture,   // ⭐ HERE


                  // ⭐ CRITICAL: use _selections (the live list)
                  selections: _selections,

                  isCompleted: _isCompleted,
                  readOnly: readOnly,
                  onChanged: (!readOnly)
                      ? () {
                          _saveSnapshot();
                          setState(() {});
                        }
                      : null,
                  collapsed: _leaderboardCollapsed,
                  scrollController: _punterScrollController,
                  fantasyService: widget.fantasyService,
                  userRoleService: widget.userRoleService,
                  onTimestampChanged: (t) {
                    setState(() => _timestampLabel = t);
                  },
                  onLiveScoreUpdateSave: null,
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

List<PunterSelection> _sortedSelections() {
  final list = List<PunterSelection>.from(_selections);
  list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
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
  // AFL DATA VALIDATION (unchanged)
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