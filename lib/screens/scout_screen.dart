import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/scout_service.dart';

// Allows click-and-drag horizontal scrolling with a mouse, in addition to
// the default touch/stylus/trackpad support — needed for the stats table's
// round columns on desktop, where there was previously no way to trigger
// the scroll at all.
class _HorizontalDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Sort column enum
// ─────────────────────────────────────────────────────────────────────────────
enum ScoutSort { af, best, k, hb, d, m, t, tog, last, l3, vsOpp }

extension ScoutSortExt on ScoutSort {
  String get label {
    switch (this) {
      case ScoutSort.af:   return 'AF';
      case ScoutSort.best: return 'Best';
      case ScoutSort.k:    return 'K';
      case ScoutSort.hb:   return 'HB';
      case ScoutSort.d:    return 'D';
      case ScoutSort.m:    return 'M';
      case ScoutSort.t:    return 'T';
      case ScoutSort.tog:  return 'TOG%';
      case ScoutSort.last: return 'Last';
      case ScoutSort.l3:   return 'L3';
      case ScoutSort.vsOpp: return 'vs Opp';
    }
  }

  int value(PlayerSeasonStats s) {
    switch (this) {
      case ScoutSort.af:   return s.afAvg;
      case ScoutSort.best: return s.afBest;
      case ScoutSort.k:    return s.kAvg;
      case ScoutSort.hb:   return s.hbAvg;
      case ScoutSort.d:    return s.dAvg;
      case ScoutSort.m:    return s.mAvg;
      case ScoutSort.t:    return s.tAvg;
      case ScoutSort.tog:  return s.togAvg;
      case ScoutSort.last: return s.lastGame;
      case ScoutSort.l3:   return s.last3Avg;
      case ScoutSort.vsOpp: return 0; // handled separately
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScoutScreen
// ─────────────────────────────────────────────────────────────────────────────
class ScoutScreen extends StatefulWidget {
  final int season;
  final int? round;
  final String gameType;
  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final ScoutService scoutService;

  /// The email of the currently logged-in user. Used to scope persisted
  /// list selections and sort/filter preferences so each user sees only
  /// their own data.
  final String userEmail;

  /// Player IDs already drafted in the current game
  final Set<String> draftedPlayerIds;

  /// For custom_builder / custom_game: the specific match IDs selected.
  /// When provided, only players from these fixtures are shown.
  final List<String>? selectedFixtureIds;

  const ScoutScreen({
    super.key,
    required this.season,
    required this.round,
    required this.gameType,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.scoutService,
    required this.userEmail,
    required this.draftedPlayerIds,
    this.selectedFixtureIds,
  });

  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<PlayerSeasonStats> _allStats = [];
  Map<String, PlayerFlagEntry> _flags = {};
  Set<String> _namedSquadIds    = {};
  Set<String> _emergencySquadIds = {};
  bool _teamsAnnounced = false;
  Set<String> _fetchedDraftedIds = {};
  Timer? _draftedPollTimer;
  Map<String, Map<String, dynamic>> _vsOpponentStats = {};
  String _upcomingOpponent = '';
  List<Map<String, String>> _injuryList = [];
  List<Map<String, dynamic>> _teamLineups = [];

  // Filters
  String? _teamFilter;
  String _gameTypeFilter = '';
  bool _namedOnly = false;
  bool _hideDrafted = false;
  bool _hideFlagged = false;
  String _search = '';
  ScoutSort _sort = ScoutSort.af;

  /// Player IDs the user has ticked for the "Generate List" feature,
  /// in the order they were ticked. The first ticked player is rank 1, etc.
  /// Scoped per user + game type so each person's list is private and
  /// Weekend Quads selections don't bleed into Pairs views.
  final List<String> _selectedPlayerIds = <String>[];

  final _searchCtrl = TextEditingController();

  // ── Stats table scrolling ────────────────────────────────────────────────
  // Single shared horizontal controller for the header + all rows (the
  // rounds/stats columns), plus a synced pair of vertical controllers for
  // the fixed (rank/name/team) column vs. the scrollable stats column.
  // These must live on the State, not be recreated inside _buildTable() on
  // every rebuild, or scroll position resets every time a filter changes.
  final _tableHeaderHScroll = ScrollController();
  final _tableBodyHScroll = ScrollController();
  final _tableLeftVScroll = ScrollController();
  final _tableRightVScroll = ScrollController();
  bool _syncingTableV = false;

  // ── Per-user, per-game-type persistence key ────────────────────────────────
  /// Unique key that scopes all persisted scout prefs to the current user
  /// AND the active game type. Changing game type loads a fresh set of prefs.
  String get _prefKey {
    final safeEmail = widget.userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'scout_prefs__${safeEmail}__${widget.season}__$_gameTypeFilter';
  }

  /// Persist the current sort + filter prefs and selected player list for
  /// this user + game type.
  Future<void> _saveUserPrefs() async {
    await widget.scoutService.saveScoutPrefs(
      key: _prefKey,
      sort: _sort.name,
      hideDrafted: _hideDrafted,
      hideFlagged: _hideFlagged,
      selectedPlayerIds: List<String>.from(_selectedPlayerIds),
    );
  }

  /// Restore sort + filter prefs and selected player list for this user +
  /// game type. Safe to call before [_loadData] — falls back to defaults.
  Future<void> _loadUserPrefs() async {
    final prefs = await widget.scoutService.loadScoutPrefs(key: _prefKey);
    if (prefs == null) return;
    if (!mounted) return;
    setState(() {
      _sort = ScoutSort.values.firstWhere(
        (s) => s.name == (prefs['sort'] as String?),
        orElse: () => ScoutSort.af,
      );
      _hideDrafted = prefs['hideDrafted'] as bool? ?? false;
      _hideFlagged = prefs['hideFlagged'] as bool? ?? false;
      final ids = (prefs['selectedPlayerIds'] as List?)?.cast<String>() ?? [];
      _selectedPlayerIds
        ..clear()
        ..addAll(ids);
    });
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // If opened from a custom game, default filter to 'custom_game'
    // so the scout is immediately scoped to the selected fixtures.
    _gameTypeFilter = (widget.selectedFixtureIds?.isNotEmpty == true)
        ? 'custom_game'
        : widget.gameType;
    // Restore per-user, per-game-type sort/filter prefs and list selections
    // before kicking off the main data load so the UI is consistent.
    _loadUserPrefs().then((_) => _loadData());

    _tableBodyHScroll.addListener(() {
      if (_tableHeaderHScroll.hasClients) {
        _tableHeaderHScroll.jumpTo(_tableBodyHScroll.offset);
      }
    });
    _tableLeftVScroll.addListener(() {
      if (_syncingTableV) return;
      _syncingTableV = true;
      if (_tableRightVScroll.hasClients) {
        _tableRightVScroll.jumpTo(_tableLeftVScroll.offset);
      }
      _syncingTableV = false;
    });
    _tableRightVScroll.addListener(() {
      if (_syncingTableV) return;
      _syncingTableV = true;
      if (_tableLeftVScroll.hasClients) {
        _tableLeftVScroll.jumpTo(_tableRightVScroll.offset);
      }
      _syncingTableV = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _draftedPollTimer?.cancel();
    _tableHeaderHScroll.dispose();
    _tableBodyHScroll.dispose();
    _tableLeftVScroll.dispose();
    _tableRightVScroll.dispose();
    super.dispose();
  }


  /// Parses player names from AFL team lineup paste.
  /// Handles both "L. Cowan" abbreviated and "Jake Kolodjashnij" full name formats.
  ({Set<String> named, Set<String> emergency}) _parseSquadFromText(String text) {
    final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();

    final sectionLabels = {
      'full backs', 'half backs', 'centres', 'half forwards',
      'full forwards', 'followers', 'interchanges', 'emergencies',
      'interchange', 'emergency', 'ruck',
    };

    final emergencySections = {'emergencies', 'emergency'};
    final interchangeSections = {'interchanges', 'interchange'};
    // Sections that signal a new team has started — reset emergency flag
    final teamStartSections = {
      'full backs', 'half backs', 'centres', 'half forwards',
      'full forwards', 'followers',
    };
    bool inEmergency = false;
    bool inInterchange = false;
    int interchangeCount = 0;

    final candidateNames = <String>[];
    final emergencyNames = <String>[];

    for (final line in lines) {
      // Blank line = team boundary — reset flags
      if (line.isEmpty) { inEmergency = false; inInterchange = false; interchangeCount = 0; continue; }
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (sectionLabels.contains(line.toLowerCase())) {
        if (teamStartSections.contains(line.toLowerCase())) {
          inEmergency = false;
          inInterchange = false;
          interchangeCount = 0;
        } else if (interchangeSections.contains(line.toLowerCase())) {
          inEmergency = false;
          inInterchange = true;
          interchangeCount = 0;
        } else {
          inInterchange = false;
          inEmergency = emergencySections.contains(line.toLowerCase());
        }
        continue;
      }
      if (RegExp(r'^[A-Z][a-z]').hasMatch(line) ||
          RegExp(r'^[A-Z]\. [A-Z]').hasMatch(line)) {
        if (inEmergency) {
          emergencyNames.add(line);
        } else if (inInterchange) {
          // Only the first 4 interchange players are named squad —
          // the AFL teamsheet lists 8 in the interchange section but
          // the last 3 are emergencies printed before the "Emergencies"
          // header (they appear as interchange slots 6-8 in the paste).
          if (interchangeCount < 5) {
            candidateNames.add(line);
            interchangeCount++;
          } else {
            emergencyNames.add(line);
          }
        } else {
          candidateNames.add(line);
        }
      }
    }

    final matched = <String>{};

    for (final name in candidateNames) {
      if (RegExp(r'^[A-Z]\. ').hasMatch(name)) {
        // Abbreviated: "L. Cowan"
        final parts = name.split('. ');
        if (parts.length >= 2) {
          final initial  = parts[0].toUpperCase();
          final lastName = parts.sublist(1).join(' ').trim().toLowerCase();
          for (final s in _allStats) {
            final np = s.playerName.trim().split(' ');
            if (np.length < 2) continue;
            if (np.last.toLowerCase() == lastName &&
                np.first[0].toUpperCase() == initial) {
              matched.add(s.playerId);
              break;
            }
          }
        }
      } else {
        // Full name: "Jake Kolodjashnij" or "Bailey Williams"
        final parts     = name.trim().toLowerCase().split(' ');
        if (parts.length < 2) continue;
        final lastName  = parts.last;
        final firstName = parts.first;

        // Try exact first name match first, then fall back to initial only
        PlayerSeasonStats? exactMatch;
        PlayerSeasonStats? initialMatch;

        for (final s in _allStats) {
          final sp = s.playerName.trim().toLowerCase().split(' ');
          if (sp.length < 2) continue;
          if (sp.last != lastName) continue;
          if (sp.first == firstName) {
            exactMatch = s;
            break; // exact match wins immediately
          } else if (sp.first[0] == firstName[0] && initialMatch == null) {
            initialMatch = s;
          }
        }

        final best = exactMatch ?? initialMatch;
        if (best != null) matched.add(best.playerId);
      }
    }

    // Match emergencies with same logic
    final emergencyMatched = <String>{};
    for (final name in emergencyNames) {
      if (RegExp(r'^[A-Z]\. ').hasMatch(name)) {
        final parts = name.split('. ');
        if (parts.length >= 2) {
          final initial  = parts[0].toUpperCase();
          final lastName = parts.sublist(1).join(' ').trim().toLowerCase();
          for (final s in _allStats) {
            final np = s.playerName.trim().split(' ');
            if (np.length < 2) continue;
            if (np.last.toLowerCase() == lastName && np.first[0].toUpperCase() == initial) {
              emergencyMatched.add(s.playerId); break;
            }
          }
        }
      } else {
        final parts = name.trim().toLowerCase().split(' ');
        if (parts.length < 2) continue;
        PlayerSeasonStats? exactMatch;
        PlayerSeasonStats? initialMatch;
        for (final s in _allStats) {
          final sp = s.playerName.trim().toLowerCase().split(' ');
          if (sp.length < 2) continue;
          if (sp.last != parts.last) continue;
          if (sp.first == parts.first) { exactMatch = s; break; }
          else if (sp.first[0] == parts.first[0] && initialMatch == null) { initialMatch = s; }
        }
        final best = exactMatch ?? initialMatch;
        if (best != null) emergencyMatched.add(best.playerId);
      }
    }

    return (named: matched, emergency: emergencyMatched);
  }

  /// Shows dialog to paste AFL team lineup text
  void _showPasteSquadDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Named Squad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy the lineup from afl.com.au/matches/team-lineups and paste it below. Repeat for each team.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: paste one team at a time.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'L. Cowan\n23\nJ. Weitering\n...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final matched = _parseSquadFromText(ctrl.text);
              if (matched.named.isEmpty && matched.emergency.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No players matched — check the format')),
                );
                return;
              }
              final newIds      = {..._namedSquadIds, ...matched.named};
              final newEmergIds = {..._emergencySquadIds, ...matched.emergency};
              // Auto-clear injury/rest/test flags for named and emergency players
              final allNewIds = {...newIds, ...newEmergIds};
              final updatedFlags = Map<String, PlayerFlagEntry>.from(_flags)
                ..removeWhere((id, _) => allNewIds.contains(id));

              setState(() {
                _namedSquadIds     = newIds;
                _emergencySquadIds = newEmergIds;
                _teamsAnnounced    = true;
                _flags             = updatedFlags;
              });
              // Persist to backend so all devices see the squad
              widget.scoutService.saveNamedSquadIds(
                season: widget.season,
                round: widget.round ?? 0,
                gameType: widget.gameType,
                playerIds: newIds,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${matched.named.length + matched.emergency.length} players to named squad'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Add to Squad'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog summarising which teams have named their squad.
  void _showTeamLineupsDialog() {
    final available = _teamLineups.where((m) => m['available'] == true).toList();
    final pending   = _teamLineups.where((m) => m['available'] != true).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.format_list_numbered_outlined, size: 20),
            const SizedBox(width: 8),
            const Text('Team Lineups'),
            const Spacer(),
            Text(
              '${available.length}/${_teamLineups.length} named',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _teamLineups.isEmpty
              ? const Center(
                  child: Text(
                    'No lineup data available.\nTap Reload to try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  children: [
                    if (available.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Named ✓',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      ...available.map((m) {
                        final home = m['home'] as String? ?? '';
                        final away = m['away'] as String? ?? '';
                        final hc   = (m['homePlayers'] as List?)?.length ?? 0;
                        final ac   = (m['awayPlayers'] as List?)?.length ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$home vs $away',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '$hc + $ac players',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                    ],
                    if (pending.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Not yet named',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      ...pending.map((m) {
                        final home = m['home'] as String? ?? '';
                        final away = m['away'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                '$home vs $away',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Reload'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog with the live AFL injury list data.
  void _showInjuryListDialog() {
    // Group by team for display
    final Map<String, List<Map<String, String>>> byTeam = {};
    for (final entry in _injuryList) {
      final team = entry['team'] ?? 'Unknown';
      byTeam.putIfAbsent(team, () => []).add(entry);
    }
    final teams = byTeam.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.medical_services_outlined, size: 20),
            const SizedBox(width: 8),
            const Text('AFL Injury List'),
            const Spacer(),
            Text(
              '${_injuryList.length} players',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 480,
          child: _injuryList.isEmpty
              ? const Center(
                  child: Text(
                    'No injury data available.\nTap Reload to try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (ctx, i) {
                    final team = teams[i];
                    final entries = byTeam[team]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            team,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...entries.map((e) {
                          final rawFlag = e['flagType'] ?? 'INJ';
                          final flag = PlayerFlagExt.fromString(rawFlag) ?? PlayerFlag.inj;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Row(
                              children: [
                                // Flag chip
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: flag.colour.withOpacity(0.15),
                                    border: Border.all(color: flag.colour, width: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    flag.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: flag.colour,
                                    ),
                                  ),
                                ),
                                // Player name
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    e['playerName'] ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                // Injury / status
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    e['injury'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: flag.colour,
                                    ),
                                  ),
                                ),
                                // Timeline
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    e['estimatedReturn'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 8),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Reload'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Polls drafted players every 5 seconds so Scout updates
  /// automatically when a selection is made in a game view.
  void _startDraftedPolling() {
    _draftedPollTimer?.cancel();
    _draftedPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        final drafted = await widget.scoutService.fetchDraftedPlayers(
          season: widget.season,
          round: widget.round ?? 0,
          gameType: _gameTypeFilter.isNotEmpty ? _gameTypeFilter : widget.gameType,
        );
        if (mounted && drafted.length != _fetchedDraftedIds.length ||
            !drafted.every(_fetchedDraftedIds.contains)) {
          setState(() => _fetchedDraftedIds = drafted);
        }
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final stats = await widget.scoutService.fetchSeasonStats(widget.season);
    final flags = await widget.scoutService.fetchFlags(widget.season);
    final injuryList = await widget.scoutService.fetchInjuryList();
    final teamLineups = await widget.scoutService.fetchTeamLineups();

    // ⭐ Fetch drafted players from backend for ALL game types in this round
    // This ensures we get picks even if the local state isn't loaded
    final vsStats = await widget.scoutService.fetchVsOpponentStats(
      season: widget.season,
      round: widget.round ?? 0,
      gameType: _gameTypeFilter.isEmpty ? widget.gameType : _gameTypeFilter,
    );

    // Load persisted named squad from backend
    final savedSquadIds = await widget.scoutService.fetchNamedSquadIds(
      season: widget.season,
      round: widget.round ?? 0,
      gameType: widget.gameType,
    );

    final drafted = await widget.scoutService.fetchDraftedPlayers(
      season: widget.season,
      round: widget.round ?? 0,
      gameType: _gameTypeFilter.isNotEmpty ? _gameTypeFilter : widget.gameType,
    );

    // Fetch named squads for all fixtures in this round/game type
    Set<String> namedIds = {};
    bool announced = false;
    final fixtures = _fixturesForGameType(widget.gameType);
    for (final f in fixtures) {
      final mid = f.matchId?.trim();
      if (mid == null || mid.isEmpty) continue;
      final named = await widget.scoutService.fetchNamedSquad(mid);
      if (named.isNotEmpty) {
        namedIds.addAll(named);
        announced = true;
      }
    }

    if (mounted) {
      // Find the opponent for the current game type from fixture data
      String opponent = '';
      if (vsStats.isNotEmpty) {
        // Find first non-empty opponent from stats
        for (final v in vsStats.values) {
          final opp = v['opponent'] as String? ?? '';
          if (opp.isNotEmpty) { opponent = opp; break; }
        }
      }

      // ── Auto-populate named squad from team lineups page ─────────────────
      // The teamLineups endpoint now returns player IDs directly from the AFL CFS API.
      // Use those IDs instead of matching by name (which fails on name mismatches).
      final lineupNamedIds = <String>{};
      for (final lineupMatch in teamLineups) {
        if (lineupMatch['available'] != true) continue;
        final homeIds = (lineupMatch['homePlayerIds'] as List?)?.cast<String>() ?? [];
        final awayIds = (lineupMatch['awayPlayerIds'] as List?)?.cast<String>() ?? [];
        lineupNamedIds.addAll(homeIds);
        lineupNamedIds.addAll(awayIds);
      }

      // Merge persisted backend squad + AFL lineup squad + AFL API squad
      final mergedIds = <String>{...namedIds, ...savedSquadIds, ...lineupNamedIds};
      final mergedAnnounced = announced || savedSquadIds.isNotEmpty || lineupNamedIds.isNotEmpty;

      // Auto-flag players found on the AFL injury list.

      // Respects any existing manually-set flags — never overwrites them.
      // Uses the flagType field from the backend to pick the correct flag:
      //   "SUSP" → PlayerFlag.susp   (Suspension)
      //   "REST" → PlayerFlag.rest   (Conditioning, Managed, Test — close to return)
      //   "OUT"  → PlayerFlag.out    (Personal reasons, indefinite)
      //   "INJ"  → PlayerFlag.inj    (everything else)
      final updatedFlags = Map<String, PlayerFlagEntry>.from(flags);
      for (final entry in injuryList) {
        final injuredName = entry['playerName'] ?? '';
        if (injuredName.isEmpty) continue;
        // Find matching player by name (case-insensitive)
        final match = stats.where((s) =>
          s.playerName.trim().toLowerCase() == injuredName.trim().toLowerCase()
        ).firstOrNull;
        if (match != null && !updatedFlags.containsKey(match.playerId)) {
          final returnStr = entry['estimatedReturn'] ?? '';
          final rawFlag   = entry['flagType'] ?? 'INJ';
          final flag = PlayerFlagExt.fromString(rawFlag) ?? PlayerFlag.inj;
          updatedFlags[match.playerId] = PlayerFlagEntry(
            playerId: match.playerId,
            flag: flag,
            note: '${entry['injury'] ?? ''}'
                '${returnStr.isNotEmpty ? ' · $returnStr' : ''}',
          );
        }
      }

      // If a player is in the named squad, clear ALL injury flags —
      // being selected overrides any injury/rest/managed status.
      for (final playerId in mergedIds) {
        updatedFlags.remove(playerId);
      }

      setState(() {
        _allStats = stats;
        _flags = updatedFlags;
        _injuryList = injuryList;
        _teamLineups = teamLineups;
        _namedSquadIds = mergedIds;
        _teamsAnnounced = mergedAnnounced;
        _fetchedDraftedIds = drafted;
        _vsOpponentStats = vsStats;
        _upcomingOpponent = opponent;
        _loading = false;
        _startDraftedPolling();
      });
    }
  }

  // ── Fixture helpers ────────────────────────────────────────────────────────
  List<dynamic> _fixturesForGameType(String gameType) {
    final all = widget.fixtureRepo.fixturesForSeasonRound(
      widget.season, widget.round,
    );
    bool isDay(dynamic f, int weekday) =>
        f.date != null && f.date!.weekday == weekday;

    switch (gameType) {
      case 'thursday_pairs':
        return all.where((f) => isDay(f, DateTime.thursday)).toList();
      case 'friday_pairs':
        return all.where((f) => isDay(f, DateTime.friday)).toList();
      case 'saturday_pairs':
        return all.where((f) => isDay(f, DateTime.saturday)).toList();
      case 'sunday_pairs':
        return all.where((f) => isDay(f, DateTime.sunday)).toList();
      case 'monday_pairs':
        return all.where((f) => isDay(f, DateTime.monday)).toList();
      case 'weekend_quads':
        return all.where((f) =>
          !isDay(f, DateTime.thursday)).toList();
      case 'custom_game':
        // Filter to only the matches selected when the custom game was created
        final ids = widget.selectedFixtureIds;
        if (ids == null || ids.isEmpty) return all;
        return all.where((f) =>
          f.matchId != null && ids.contains(f.matchId)).toList();
      default:
        return all;
    }
  }

  Set<String> _teamsForGameType(String gameType) {
    final fixtures = _fixturesForGameType(gameType);
    final teams = <String>{};
    for (final f in fixtures) {
      if (f.homeTeam.isNotEmpty) teams.add(f.homeTeam);
      if (f.awayTeam.isNotEmpty) teams.add(f.awayTeam);
    }
    return teams;
  }

  // ── Filtered + sorted list ─────────────────────────────────────────────────
  List<PlayerSeasonStats> get _filtered {
    final gameTeams = _teamsForGameType(_gameTypeFilter);

    return _allStats.where((s) {
      // Must be in game type's teams
      if (gameTeams.isNotEmpty && !gameTeams.contains(s.team)) return false;

      // Team filter
      if (_teamFilter != null && s.team != _teamFilter) return false;

      // Named squad filter — show named AND emergencies
      if (_namedOnly && _teamsAnnounced) {
        if (!_namedSquadIds.contains(s.playerId) &&
            !_emergencySquadIds.contains(s.playerId)) return false;
      }

      // Hide drafted
      final activeGameType = _gameTypeFilter.isNotEmpty
          ? _gameTypeFilter
          : widget.gameType;
      final localDraftedForFilter = activeGameType == widget.gameType
          ? widget.draftedPlayerIds
          : <String>{};
      final allDrafted = {...localDraftedForFilter, ..._fetchedDraftedIds};
      if (_hideDrafted && allDrafted.contains(s.playerId)) {
        return false;
      }

      // Hide flagged — but never hide named or emergency players
      final isNamed = _teamsAnnounced && _namedSquadIds.contains(s.playerId);
      final isEmergencyFilter = _teamsAnnounced && _emergencySquadIds.contains(s.playerId);
      if (_hideFlagged && !isNamed && !isEmergencyFilter && _flags.containsKey(s.playerId)) return false;

      // Search
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!s.playerName.toLowerCase().contains(q) &&
            !s.team.toLowerCase().contains(q)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        if (_sort == ScoutSort.vsOpp) {
          final aVs = (_vsOpponentStats[a.playerName]?['avgVsOpponent'] as int?) ?? 0;
          final bVs = (_vsOpponentStats[b.playerName]?['avgVsOpponent'] as int?) ?? 0;
          return bVs.compareTo(aVs);
        }
        return _sort.value(b).compareTo(_sort.value(a));
      });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gameTeams = _teamsForGameType(_gameTypeFilter).toList()..sort();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Scout'),
        actions: [
          // Paste named squad
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Paste named squad',
            onPressed: () => _showPasteSquadDialog(),
          ),
          // Open AFL injury list
          IconButton(
            icon: const Icon(Icons.medical_services_outlined),
            tooltip: 'View AFL injury list',
            onPressed: () => _showInjuryListDialog(),
          ),
          // Show team lineups summary
          IconButton(
            icon: const Icon(Icons.format_list_numbered_outlined),
            tooltip: 'Team lineups',
            onPressed: () => _showTeamLineupsDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(theme, cs, gameTeams),
                const Divider(height: 1),
                _buildVsLegend(theme, cs),
                Expanded(child: _buildTable(theme, cs)),
              ],
            ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildVsLegend(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: cs.surfaceVariant.withOpacity(0.3),
      child: Row(
        children: [
          _legendDot(Colors.green[700]!, '>10% above avg'),
          const SizedBox(width: 12),
          _legendDot(Colors.red[700]!, '>10% below avg'),
          const SizedBox(width: 12),
          Text('(applies to vs Opp, Last & L3)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildFilters(ThemeData theme, ColorScheme cs, List<String> gameTeams) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.shortestSide < 600 ? 8 : 12,
        vertical:   MediaQuery.of(context).size.shortestSide < 600 ? 4 : 8,
      ),
      color: cs.surfaceVariant.withOpacity(0.5),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [

          // Game type dropdown
          _FilterChipDrop<String>(
            label: _gameTypeLabel(_gameTypeFilter),
            items: [
              'thursday_pairs', 'friday_pairs', 'saturday_pairs',
              'sunday_pairs', 'monday_pairs', 'weekend_quads',
              // Show Custom Game whenever fixture IDs are available,
              // regardless of the gameType this screen was opened with.
              if (widget.selectedFixtureIds?.isNotEmpty == true) 'custom_game',
            ],
            itemLabel: _gameTypeLabel,
            value: _gameTypeFilter,
            onChanged: (v) {
              setState(() {
                _gameTypeFilter = v ?? '';
                _teamFilter = null;
                _vsOpponentStats = {};
                _upcomingOpponent = '';
                _fetchedDraftedIds = {}; // Reset so new game type fetches fresh
                // Reset list selections and prefs — they will be restored
                // from the per-user, per-game-type store below.
                _selectedPlayerIds.clear();
                _sort = ScoutSort.af;
                _hideDrafted = false;
                _hideFlagged = false;
              });
              // Reload this user's prefs for the newly selected game type.
              _loadUserPrefs();
              // Restart polling for new game type
              _startDraftedPolling();
              widget.scoutService.fetchVsOpponentStats(
                season: widget.season,
                round: widget.round ?? 0,
                gameType: v ?? widget.gameType,
              ).then((vsStats) {
                if (mounted) setState(() {
                  _vsOpponentStats = vsStats;
                  if (vsStats.isNotEmpty) {
                    _upcomingOpponent = vsStats.values.first['opponent'] as String? ?? '';
                  }
                });
              });
            },
          ),

          // Team dropdown
          _FilterChipDrop<String?>(
            label: _teamFilter ?? 'All Teams',
            items: [null, ...gameTeams],
            itemLabel: (t) => t ?? 'All Teams',
            value: _teamFilter,
            onChanged: (v) => setState(() => _teamFilter = v),
          ),

          // Sort dropdown
          _FilterChipDrop<ScoutSort>(
            label: 'Sort: ${_sort.label}',
            items: ScoutSort.values,
            itemLabel: (s) => s.label,
            value: _sort,
            onChanged: (v) {
              setState(() => _sort = v ?? ScoutSort.af);
              _saveUserPrefs();
            },
          ),

          // Hide drafted
          FilterChip(
            label: const Text('Hide drafted'),
            selected: _hideDrafted,
            onSelected: (v) {
              setState(() => _hideDrafted = v);
              _saveUserPrefs();
            },
          ),

          // Hide flagged
          FilterChip(
            label: const Text('Hide flagged'),
            selected: _hideFlagged,
            onSelected: (v) {
              setState(() => _hideFlagged = v);
              _saveUserPrefs();
            },
          ),

          // Generate List — shows the ticked players in a copyable dialog
          ActionChip(
            avatar: const Icon(Icons.list_alt, size: 16),
            label: Text(
              _selectedPlayerIds.isEmpty
                  ? 'Generate List'
                  : 'Generate List (${_selectedPlayerIds.length})',
            ),
            onPressed: _selectedPlayerIds.isEmpty
                ? null
                : _showGenerateListDialog,
          ),

          // Named squad filter — only shown when squad has been pasted
          if (_teamsAnnounced) ...[
            FilterChip(
              label: Text('Hide unnamed (${_namedSquadIds.length})'),
              selected: _namedOnly,
              onSelected: (v) => setState(() => _namedOnly = v),
            ),

          ],

          // Search box
          SizedBox(
            width: MediaQuery.of(context).size.shortestSide < 600 ? 110 : 160,
            height: MediaQuery.of(context).size.shortestSide < 600 ? 28 : 32,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search player...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                suffixIcon: _search.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                        child: const Icon(Icons.clear, size: 16),
                      )
                    : const Icon(Icons.search, size: 16),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          // Count
          Text(
            '${_filtered.length} players',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────
  Widget _buildTable(ThemeData theme, ColorScheme cs) {
    final rows = _filtered;
    if (rows.isEmpty) {
      return Center(
        child: Text('No players match the current filters',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.5))),
      );
    }

    // Column widths
    // Responsive column widths — narrower on phone
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    final bool isPhone = shortestSide < 600;
    final bool isTablet = shortestSide < 900;

    final double numW  = isPhone ? 26.0 : 36.0;
    final double nameW = isPhone ? 100.0 : (isTablet ? 120.0 : 150.0);
    final double teamW = isPhone ? 36.0  : 50.0;
    final double statW = isPhone ? 34.0  : (isTablet ? 40.0 : 46.0);
    final double flagW = isPhone ? 44.0  : 56.0;

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700, letterSpacing: 0.2);
    final cellStyle = theme.textTheme.bodySmall;

    Widget hCell(String t, double w, {bool sortable = false, ScoutSort? col, Alignment align = Alignment.center}) =>
      GestureDetector(
        onTap: col != null ? () => setState(() => _sort = col) : null,
        child: Container(
          width: w, height: 26,
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: col != null && _sort == col
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: cs.primary, width: 2)))
              : null,
          child: Text(t, style: headerStyle, overflow: TextOverflow.ellipsis),
        ),
      );

    Widget dCell(String t, double w, {TextStyle? style, Color? bg,
        Alignment align = Alignment.center}) =>
      Container(
        width: w, height: 30,
        alignment: align,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(t, style: style ?? cellStyle,
            overflow: TextOverflow.ellipsis),
      );

    // Fixed columns: tick / # / name / team
    Widget fixedHeader() => Row(children: [
      // Master tickbox: tap to select/deselect all currently visible rows
      SizedBox(
        width: 32, height: 26,
        child: Checkbox(
          visualDensity: VisualDensity.compact,
          value: rows.isNotEmpty &&
              rows.every((s) => _selectedPlayerIds.contains(s.playerId)),
          tristate: true,
          onChanged: (v) {
            setState(() {
              final allSelected = rows.isNotEmpty &&
                  rows.every((s) => _selectedPlayerIds.contains(s.playerId));
              if (allSelected) {
                final visibleIds = rows.map((s) => s.playerId).toSet();
                _selectedPlayerIds.removeWhere(visibleIds.contains);
              } else {
                // Append any not-already-selected rows in their displayed order
                for (final s in rows) {
                  if (!_selectedPlayerIds.contains(s.playerId)) {
                    _selectedPlayerIds.add(s.playerId);
                  }
                }
              }
            });
            _saveUserPrefs();
          },
        ),
      ),
      hCell('#', numW),
      hCell('Player', nameW, align: Alignment.centerLeft),
      hCell('Team', teamW),
    ]);

    // Scrollable columns
    Widget scrollHeader() => Row(children: [
      hCell('G', statW),
      hCell('AF', statW, col: ScoutSort.af),
      hCell('Best', statW, col: ScoutSort.best),
      hCell('K', statW, col: ScoutSort.k),
      hCell('HB', statW, col: ScoutSort.hb),
      hCell('D', statW, col: ScoutSort.d),
      hCell('M', statW, col: ScoutSort.m),
      hCell('T', statW, col: ScoutSort.t),
      hCell('TOG%', statW, col: ScoutSort.tog),
      hCell('Last', statW, col: ScoutSort.last),
      hCell('L3', statW, col: ScoutSort.l3),
      
      
      if (_upcomingOpponent.isNotEmpty)
        hCell('vs Opp', isPhone ? statW : statW + 10, col: ScoutSort.vsOpp),
      hCell('Status', flagW),
    ]);

    Color rowBg(int i, PlayerSeasonStats s) {
      if (widget.draftedPlayerIds.contains(s.playerId)) {
        return cs.primary.withOpacity(0.08);
      }
      return i.isEven ? cs.surface : cs.surfaceVariant;
    }

    ({Widget fixed, Widget scroll}) buildRowParts(int i) {
      final s = rows[i];
      final bg = rowBg(i, s);
      final flag = _flags[s.playerId];
      // Only include locally-passed drafted IDs when the active filter
      // matches the game type this Scout was opened for — prevents quads
      // picks bleeding into friday pairs view and vice versa.
      final activeFilter = _gameTypeFilter.isNotEmpty
          ? _gameTypeFilter
          : widget.gameType;
      final localDrafted = activeFilter == widget.gameType
          ? widget.draftedPlayerIds
          : <String>{};
      final allDraftedRow = {...localDrafted, ..._fetchedDraftedIds};
      final isDrafted   = allDraftedRow.contains(s.playerId);
      final isNamed     = _teamsAnnounced && _namedSquadIds.contains(s.playerId);
      final isEmergency = _teamsAnnounced && _emergencySquadIds.contains(s.playerId);
      final nameStyle = cellStyle?.copyWith(
        fontWeight: FontWeight.w600,
        color: isDrafted
            ? (flag != null ? flag.flag.colour : Colors.white54)
            : (flag != null ? flag.flag.colour : null),
        decoration: isDrafted ? TextDecoration.lineThrough : null,
        decorationColor: isDrafted ? Colors.white54 : null,
        decorationThickness: isDrafted ? 2.0 : null,
      );

      final fixed = SizedBox(
        height: 30,
        child: Row(
          children: [
            // Per-row checkbox with rank number when selected
            Container(
              width: 32, height: 30, color: bg,
              alignment: Alignment.center,
              child: Builder(builder: (_) {
                final rank = _selectedPlayerIds.indexOf(s.playerId);
                final isSelected = rank >= 0;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPlayerIds.remove(s.playerId);
                      } else {
                        _selectedPlayerIds.add(s.playerId);
                      }
                    });
                    _saveUserPrefs();
                  },
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? cs.primary : cs.outline,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? Text(
                            '${rank + 1}',
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1.0,
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
            // Fixed
            dCell('${i + 1}', numW, bg: bg),
            dCell(s.playerName, nameW,
                style: nameStyle, bg: bg,
                align: Alignment.centerLeft),
            dCell(s.team, teamW, bg: bg),
          ],
        ),
      );

      final scroll = SizedBox(
        height: 30,
        child: Row(children: [
                dCell('${s.games}', statW, bg: bg),
                dCell('${s.afAvg}', statW,
                    style: cellStyle?.copyWith(fontWeight: FontWeight.w700),
                    bg: bg),
                dCell('${s.afBest}', statW, bg: bg),
                dCell('${s.kAvg}', statW, bg: bg),
                dCell('${s.hbAvg}', statW, bg: bg),
                dCell('${s.dAvg}', statW, bg: bg),
                dCell('${s.mAvg}', statW, bg: bg),
                dCell('${s.tAvg}', statW, bg: bg),
                dCell('${s.togAvg}%', statW, bg: bg),
                // Last game
                dCell(
                  s.lastGame > 0 ? '${s.lastGame}' : '–',
                  statW,
                  style: s.lastGame > 0
                      ? cellStyle?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: s.lastGame >= (s.afAvg * 1.1).round()
                              ? Colors.green[700]
                              : s.lastGame <= (s.afAvg * 0.9).round()
                                  ? Colors.red[700]
                                  : null,
                        )
                      : cellStyle?.copyWith(color: cs.onSurface.withOpacity(0.3)),
                  bg: bg,
                ),
                // Last 3 avg
                dCell(
                  s.last3Avg > 0 ? '${s.last3Avg}' : '–',
                  statW,
                  style: s.last3Avg > 0
                      ? cellStyle?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: s.last3Avg >= (s.afAvg * 1.1).round()
                              ? Colors.green[700]
                              : s.last3Avg <= (s.afAvg * 0.9).round()
                                  ? Colors.red[700]
                                  : null,
                        )
                      : cellStyle?.copyWith(color: cs.onSurface.withOpacity(0.3)),
                  bg: bg,
                ),

                // Vs Opponent
                if (_upcomingOpponent.isNotEmpty) _buildVsCell(s, isPhone ? statW : statW + 10, bg, cellStyle, cs),
                // Game log icon + Status cell + Note
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: flagW + 28,
                      height: 30,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game log button
                          SizedBox(
                            width: 24, height: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: Icon(Icons.bar_chart_rounded,
                                color: cs.onSurface.withOpacity(0.4)),
                              tooltip: 'Game log',
                              onPressed: () => _showGameLog(s),
                            ),
                          ),
                          const SizedBox(width: 2),
                          // Flag/status chip — long press star to remove from squad
                          GestureDetector(
                            onTap: () => _showFlagDialog(s),
                            onLongPress: isNamed ? () async {
                              final newIds = Set<String>.from(_namedSquadIds)
                                ..remove(s.playerId);
                              setState(() => _namedSquadIds = newIds);
                              await widget.scoutService.saveNamedSquadIds(
                                season: widget.season,
                                round: widget.round ?? 0,
                                gameType: widget.gameType,
                                playerIds: newIds,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${s.playerName} removed from squad'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } : null,
                            child: Container(
                              width: flagW, height: 30,
                              alignment: Alignment.center,
                              color: bg,
                              child: _buildStatusChip(s, isNamed, isEmergency, isDrafted, flag),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Note display — shown to right of status
                    if (flag?.note != null && flag!.note.trim().isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        height: 30,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          flag.note.trim(),
                          style: cellStyle?.copyWith(
                            fontSize: 10,
                            color: flag.flag.colour.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ]),
      );

      return (fixed: fixed, scroll: scroll);
    }

    // Natural width of the scrollable stat columns, so the single shared
    // horizontal scroll region knows its scrollable extent. Includes a
    // buffer for the optional per-row note text, which can extend slightly
    // past the last column for flagged players.
    final double scrollWidth = statW * 11 +
        (_upcomingOpponent.isNotEmpty ? (isPhone ? statW : statW + 10) : 0) +
        (flagW + 28) +
        120; // note buffer

    return Column(
      children: [
        // Header
        Container(
          height: 26,
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            border: Border(
              bottom: BorderSide(color: cs.primary.withOpacity(0.4), width: 1),
            ),
          ),
          child: Row(
            children: [
              fixedHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _tableHeaderHScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: scrollHeader(),
                ),
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ScrollConfiguration(
            behavior: _HorizontalDragScrollBehavior(),
            child: Row(
              children: [
                // Fixed rank/player/team column — its own vertical list,
                // kept in sync with the scrollable column below.
                SizedBox(
                  width: 32 + numW + nameW + teamW,
                  child: ListView.builder(
                    controller: _tableLeftVScroll,
                    itemCount: rows.length,
                    itemExtent: 30,
                    itemBuilder: (ctx, i) => buildRowParts(i).fixed,
                  ),
                ),
                // Scrollable stats column — ONE horizontal scroll region
                // covering every row at once. Previously each row had its
                // own scroll view with dragging disabled entirely and no
                // controller attached, so nothing could ever be scrolled,
                // and taps near it could misbehave inside the dead
                // gesture-arena participant.
                Expanded(
                  child: Scrollbar(
                    controller: _tableBodyHScroll,
                    thumbVisibility: true,
                    trackVisibility: true,
                    notificationPredicate: (_) => true,
                    child: SingleChildScrollView(
                      controller: _tableBodyHScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: scrollWidth,
                        child: ListView.builder(
                          controller: _tableRightVScroll,
                          itemCount: rows.length,
                          itemExtent: 30,
                          itemBuilder: (ctx, i) => buildRowParts(i).scroll,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Game log popup ───────────────────────────────────────────────────────────
  Future<void> _showGameLog(PlayerSeasonStats s) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final games = await widget.scoutService.fetchPlayerGameLog(
      season: widget.season,
      playerName: s.playerName,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(s.playerName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text(s.team,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        content: SizedBox(
          width: 340,
          child: games.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No game data available yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row
                    _gameLogRow('Rd', 'Opp', 'AF', 'K', 'HB', 'D', 'M', 'T', 'TOG', isHeader: true),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          children: games.map((g) => _gameLogRow(
                            'R${g.round}',
                            g.opponent.isNotEmpty ? g.opponent : '?',
                            '${g.score}',
                            '${g.kicks}',
                            '${g.handballs}',
                            '${g.disposals}',
                            '${g.marks}',
                            '${g.tackles}',
                            '${g.tog}%',
                            highlight: g.score,
                            avgScore: s.afAvg,
                          )).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Summary row
                    _gameLogRow(
                      'Avg',
                      '',
                      '${s.afAvg}',
                      '${s.kAvg}',
                      '${s.hbAvg}',
                      '${s.dAvg}',
                      '${s.mAvg}',
                      '${s.tAvg}',
                      '${s.togAvg}%',
                      isHeader: true,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _gameLogRow(
    String rd, String opp, String af, String k, String hb,
    String d, String m, String t, String tog, {
    bool isHeader = false,
    int highlight = 0,
    int avgScore = 0,
  }) {
    Color? afColor;
    if (!isHeader && highlight > 0 && avgScore > 0) {
      if (highlight >= (avgScore * 1.1).round()) afColor = Colors.green[700];
      else if (highlight <= (avgScore * 0.9).round()) afColor = Colors.red[700];
    }

    final style = TextStyle(
      fontSize: isHeader ? 11 : 12,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
    );

    Widget cell(String text, {double w = 36, Color? color}) => SizedBox(
      width: w,
      child: Text(text,
        textAlign: TextAlign.center,
        style: style.copyWith(color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        cell(rd,  w: 28),
        cell(opp, w: 36, color: isHeader ? null : Colors.grey[600]),
        cell(af,  w: 38, color: afColor),
        cell(k,   w: 30),
        cell(hb,  w: 30),
        cell(d,   w: 30),
        cell(m,   w: 30),
        cell(t,   w: 30),
        cell(tog, w: 38),
      ]),
    );
  }

  // ── Vs opponent cell ──────────────────────────────────────────────────────────
  Widget _buildVsCell(PlayerSeasonStats s, double w, Color bg,
      TextStyle? cellStyle, ColorScheme cs) {
    final vsData  = _vsOpponentStats[s.playerName];
    final vsAvg   = vsData?['avgVsOpponent'] as int? ?? 0;
    final vsGames = vsData?['gamesVs']       as int? ?? 0;

    if (vsGames == 0) {
      return Container(
        width: w, height: 30,
        alignment: Alignment.center,
        color: bg,
        child: Text('–',
          style: cellStyle?.copyWith(
            color: cs.onSurface.withOpacity(0.3))),
      );
    }

    // Colour: green if above season avg, red if below
    Color? textColor;
    if (vsAvg >= (s.afAvg * 1.1).round()) {
      textColor = Colors.green[700];
    } else if (vsAvg <= (s.afAvg * 0.9).round()) {
      textColor = Colors.red[700];
    }

    final opponent = vsData?['opponent'] as String? ?? '';
    return InkWell(
      onTap: () => _showVsOpponentScores(s, opponent),
      child: Container(
        width: w, height: 30,
        alignment: Alignment.center,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$vsAvg${opponent.isNotEmpty ? " v$opponent" : ""}',
              style: cellStyle?.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
                fontSize: 10,
              )),
            Text('($vsGames g)',
              style: cellStyle?.copyWith(
                fontSize: 9,
                color: cs.onSurface.withOpacity(0.5),
              )),
          ],
        ),
      ),
    );
  }

  // ── Vs opponent score breakdown popup ──────────────────────────────────────
  Future<void> _showVsOpponentScores(PlayerSeasonStats s, String opponent) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final result = await widget.scoutService.fetchVsOpponentScores(
      season: widget.season,
      round: widget.round ?? 0,
      playerName: s.playerName,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading

    final scores = (result['scores'] as List?) ?? [];
    final theme = Theme.of(context);

    // Compute average and best for the footer
    int avg = 0, best = 0;
    if (scores.isNotEmpty) {
      final values = scores.map((g) => (g['score'] as int?) ?? 0).toList();
      avg = (values.reduce((a, b) => a + b) / values.length).round();
      best = values.reduce((a, b) => a > b ? a : b);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text('${s.playerName} v $opponent',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text(s.team,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        content: SizedBox(
          width: 320,
          child: scores.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No historical games against this opponent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row
                    _vsScoreRow('Season', 'Rd', 'Team', 'AF', isHeader: true),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          children: scores.map((g) {
                            final season = g['season']?.toString() ?? '';
                            final round  = g['round'] != null ? 'R${g['round']}' : '';
                            final team   = (g['team'] as String?) ?? '';
                            final score  = (g['score'] as int?) ?? 0;
                            return _vsScoreRow(season, round, team, '$score');
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Footer with avg/best
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [
                            Text('Games', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            Text('${scores.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                          Column(children: [
                            Text('Avg', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            Text('$avg', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                          Column(children: [
                            Text('Best', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            Text('$best', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _vsScoreRow(String season, String round, String team, String score,
      {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: isHeader ? 11 : 12,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
      color: isHeader ? Colors.grey[700] : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(season, style: style)),
          SizedBox(width: 40, child: Text(round, style: style)),
          SizedBox(width: 60, child: Text(team, style: style)),
          Expanded(child: Text(score, textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }


  // ── Status chip ────────────────────────────────────────────────────────────
  Widget _buildStatusChip(PlayerSeasonStats s, bool isNamed,
      bool isEmergency, bool isDrafted, PlayerFlagEntry? flag) {
    if (flag != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: flag.flag.colour.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: flag.flag.colour, width: 1),
        ),
        child: Text(flag.flag.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: flag.flag.colour,
            )),
      );
    }
    if (isDrafted) {
      return const Icon(Icons.check_circle, size: 14, color: Colors.green);
    }
    if (isEmergency) {
      return const Icon(Icons.star, size: 14, color: Colors.blue);
    }
    if (isNamed) {
      return const Icon(Icons.star, size: 14, color: Color(0xFFFFAA00));
    }
    return const SizedBox.shrink();
  }

  // ── Flag dialog ────────────────────────────────────────────────────────────
  Future<void> _showFlagDialog(PlayerSeasonStats s) async {
    final existing = _flags[s.playerId];
    PlayerFlag? selected = existing?.flag;
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.playerName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flag options
              Wrap(
                spacing: 8,
                children: [
                  ...PlayerFlag.values.map((f) => ChoiceChip(
                    label: Text(f.label),
                    selected: selected == f,
                    selectedColor: f.colour.withOpacity(0.2),
                    onSelected: (v) =>
                        setLocal(() => selected = v ? f : null),
                  )),
                  // Clear option
                  if (existing != null)
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == false) {
      // Clear flag
      await widget.scoutService.clearFlag(
          season: widget.season, playerId: s.playerId);
      setState(() => _flags.remove(s.playerId));
    } else if (selected != null) {
      // Set flag
      await widget.scoutService.setFlag(
        season: widget.season,
        playerId: s.playerId,
        playerName: s.playerName,
        team: s.team,
        flag: selected!,
        note: noteCtrl.text,
      );
      setState(() => _flags[s.playerId] = PlayerFlagEntry(
            playerId: s.playerId,
            flag: selected!,
            note: noteCtrl.text,
          ));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  /// Builds a formatted, copyable list of the players the user has ticked
  /// in the order they were ticked, and shows it in a dialog with Copy.
  void _showGenerateListDialog() {
    // Look up player rows by ID, preserving the order they were ticked in
    final byId = {for (final s in _allStats) s.playerId: s};
    final selectedRows = _selectedPlayerIds
        .map((id) => byId[id])
        .whereType<PlayerSeasonStats>()
        .toList();

    final listText = StringBuffer();
    listText.writeln('Scout List — ${selectedRows.length} player'
        '${selectedRows.length == 1 ? '' : 's'}');
    listText.writeln('');
    for (var i = 0; i < selectedRows.length; i++) {
      final s = selectedRows[i];
      listText.writeln(
        '${i + 1}. ${s.playerName} (${s.team}) '
        '— AF avg ${s.afAvg}, L3 ${s.last3Avg}',
      );
    }

    final controller = TextEditingController(text: listText.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generated List'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            readOnly: true,
            maxLines: 14,
            minLines: 8,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onTap: () => controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            },
            child: const Text('Select All'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: controller.text));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selectedPlayerIds.clear());
              _saveUserPrefs();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear & Close'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _gameTypeLabel(String type) {
    switch (type) {
      case 'thursday_pairs':  return 'Thursday Pairs';
      case 'friday_pairs':    return 'Friday Pairs';
      case 'saturday_pairs':  return 'Saturday Pairs';
      case 'sunday_pairs':    return 'Sunday Pairs';
      case 'monday_pairs':    return 'Monday Pairs';
      case 'weekend_quads':   return 'Weekend Quads';
      case 'custom_builder':  return 'Custom Game';
      case 'custom_game':     return 'Custom Game';
      default: return type;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widget: filter chip with dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChipDrop<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final ValueChanged<T?> onChanged;

  const _FilterChipDrop({
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showMenu<T>(
          context: context,
          position: _buttonPosition(context),
          items: items
              .map((i) => PopupMenuItem<T>(
                    value: i,
                    child: Text(itemLabel(i)),
                  ))
              .toList(),
        );
        onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 14),
          ],
        ),
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
  }
}