import 'dart:async';
import 'package:flutter/material.dart';

import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/scout_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sort column enum
// ─────────────────────────────────────────────────────────────────────────────
enum ScoutSort { af, k, hb, d, m, t, tog }

extension ScoutSortExt on ScoutSort {
  String get label {
    switch (this) {
      case ScoutSort.af:  return 'AF';
      case ScoutSort.k:   return 'K';
      case ScoutSort.hb:  return 'HB';
      case ScoutSort.d:   return 'D';
      case ScoutSort.m:   return 'M';
      case ScoutSort.t:   return 'T';
      case ScoutSort.tog: return 'TOG%';
    }
  }

  int value(PlayerSeasonStats s) {
    switch (this) {
      case ScoutSort.af:  return s.afAvg;
      case ScoutSort.k:   return s.kAvg;
      case ScoutSort.hb:  return s.hbAvg;
      case ScoutSort.d:   return s.dAvg;
      case ScoutSort.m:   return s.mAvg;
      case ScoutSort.t:   return s.tAvg;
      case ScoutSort.tog: return s.togAvg;
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

  /// Player IDs already drafted in the current game
  final Set<String> draftedPlayerIds;

  const ScoutScreen({
    super.key,
    required this.season,
    required this.round,
    required this.gameType,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.scoutService,
    required this.draftedPlayerIds,
  });

  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<PlayerSeasonStats> _allStats = [];
  Map<String, PlayerFlagEntry> _flags = {};
  Set<String> _namedSquadIds = {};
  bool _teamsAnnounced = false;
  Set<String> _fetchedDraftedIds = {};
  Timer? _draftedPollTimer;
  Map<String, Map<String, dynamic>> _vsOpponentStats = {};
  String _upcomingOpponent = '';

  // Filters
  String? _teamFilter;
  String _gameTypeFilter = '';
  bool _namedOnly = false;
  bool _hideDrafted = false;
  bool _hideFlagged = false;
  String _search = '';
  ScoutSort _sort = ScoutSort.af;

  final _searchCtrl = TextEditingController();

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _gameTypeFilter = widget.gameType;
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _draftedPollTimer?.cancel();
    super.dispose();
  }


  /// Shows a dialog with the AFL injury list URL and instructions
  void _showInjuryListDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AFL Injury List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visit the AFL injury list, then return here to manually flag players.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const SelectableText(
                'afl.com.au/matches/injury-list',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap any player in the Scout table to flag them as INJ, SUSP, REST or OUT.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
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

    // ⭐ Fetch drafted players from backend for ALL game types in this round
    // This ensures we get picks even if the local state isn't loaded
    final vsStats = await widget.scoutService.fetchVsOpponentStats(
      season: widget.season,
      round: widget.round ?? 0,
      gameType: _gameTypeFilter.isEmpty ? widget.gameType : _gameTypeFilter,
    );

    final drafted = await widget.scoutService.fetchDraftedPlayers(
      season: widget.season,
      round: widget.round ?? 0,
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

      setState(() {
        _allStats = stats;
        _flags = flags;
        _namedSquadIds = namedIds;
        _teamsAnnounced = announced;
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

      // Named squad filter
      if (_namedOnly && _teamsAnnounced) {
        if (!_namedSquadIds.contains(s.playerId)) return false;
      }

      // Hide drafted
      final allDrafted = {...widget.draftedPlayerIds, ..._fetchedDraftedIds};
      if (_hideDrafted && allDrafted.contains(s.playerId)) {
        return false;
      }

      // Hide flagged
      if (_hideFlagged && _flags.containsKey(s.playerId)) return false;

      // Search
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!s.playerName.toLowerCase().contains(q) &&
            !s.team.toLowerCase().contains(q)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => _sort.value(b).compareTo(_sort.value(a)));
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
          // Open AFL injury list instructions
          IconButton(
            icon: const Icon(Icons.medical_services_outlined),
            tooltip: 'View AFL injury list',
            onPressed: () => _showInjuryListDialog(),
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
          Text('vs Opp: ', style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600)),
          _legendDot(Colors.green[700]!, 'Above avg'),
          const SizedBox(width: 12),
          _legendDot(Colors.red[700]!, 'Below avg'),
          const SizedBox(width: 12),
          _legendDot(cs.onSurface.withOpacity(0.5), 'Neutral'),
          const SizedBox(width: 12),
          Text('– = no data', style: theme.textTheme.labelSmall?.copyWith(
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
            ],
            itemLabel: _gameTypeLabel,
            value: _gameTypeFilter,
            onChanged: (v) {
              setState(() {
                _gameTypeFilter = v ?? '';
                _teamFilter = null;
                _vsOpponentStats = {};
                _upcomingOpponent = '';
              });
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
            onChanged: (v) => setState(() => _sort = v ?? ScoutSort.af),
          ),

          // Named only toggle
          if (_teamsAnnounced)
            FilterChip(
              label: const Text('Named squad (23+E)'),
              selected: _namedOnly,
              onSelected: (v) => setState(() => _namedOnly = v),
            ),

          // Hide drafted
          FilterChip(
            label: const Text('Hide drafted'),
            selected: _hideDrafted,
            onSelected: (v) => setState(() => _hideDrafted = v),
          ),

          // Hide flagged
          FilterChip(
            label: const Text('Hide flagged'),
            selected: _hideFlagged,
            onSelected: (v) => setState(() => _hideFlagged = v),
          ),

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

    // Fixed columns: # + name + team
    Widget fixedHeader() => Row(children: [
      hCell('#', numW),
      hCell('Player', nameW, align: Alignment.centerLeft),
      hCell('Team', teamW),
    ]);

    // Scrollable columns
    Widget scrollHeader() => Row(children: [
      hCell('G', statW),
      hCell('AF', statW, col: ScoutSort.af),
      hCell('Best', statW),
      hCell('K', statW, col: ScoutSort.k),
      hCell('HB', statW, col: ScoutSort.hb),
      hCell('D', statW, col: ScoutSort.d),
      hCell('M', statW, col: ScoutSort.m),
      hCell('T', statW, col: ScoutSort.t),
      hCell('TOG%', statW, col: ScoutSort.tog),
      if (_upcomingOpponent.isNotEmpty)
        hCell('vs Opp', isPhone ? statW : statW + 10),
      hCell('Status', flagW),
    ]);

    Color rowBg(int i, PlayerSeasonStats s) {
      if (widget.draftedPlayerIds.contains(s.playerId)) {
        return cs.primary.withOpacity(0.08);
      }
      return i.isEven ? cs.surface : cs.surfaceVariant;
    }

    Widget buildRow(int i) {
      final s = rows[i];
      final bg = rowBg(i, s);
      final flag = _flags[s.playerId];
      final allDraftedRow = {...widget.draftedPlayerIds, ..._fetchedDraftedIds};
      final isDrafted = allDraftedRow.contains(s.playerId);
      final isNamed = _teamsAnnounced && _namedSquadIds.contains(s.playerId);
      final nameStyle = cellStyle?.copyWith(
        fontWeight: FontWeight.w600,
        color: flag != null ? flag.flag.colour : null,
        decoration: isDrafted ? TextDecoration.lineThrough : null,
      );

      return SizedBox(
        height: 30,
        child: Row(
          children: [
            // Fixed
            dCell('${i + 1}', numW, bg: bg),
            dCell(s.playerName, nameW,
                style: nameStyle, bg: bg,
                align: Alignment.centerLeft),
            dCell(s.team, teamW, bg: bg),
            // Scrollable
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
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
                // Vs Opponent
                if (_upcomingOpponent.isNotEmpty) _buildVsCell(s, isPhone ? statW : statW + 10, bg, cellStyle, cs),
                // Status cell
                GestureDetector(
                  onTap: () => _showFlagDialog(s),
                  child: Container(
                    width: flagW, height: 30,
                    alignment: Alignment.center,
                    color: bg,
                    child: _buildStatusChip(s, isNamed, isDrafted, flag),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    final headerScrollCtrl = ScrollController();
    final bodyScrollCtrl   = ScrollController();

    bodyScrollCtrl.addListener(() {
      if (headerScrollCtrl.hasClients) {
        headerScrollCtrl.jumpTo(bodyScrollCtrl.offset);
      }
    });

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
                  controller: headerScrollCtrl,
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification &&
                  n.metrics.axis == Axis.horizontal) {
                bodyScrollCtrl.jumpTo(n.metrics.pixels);
              }
              return false;
            },
            child: ListView.builder(
              itemCount: rows.length,
              itemExtent: 30,
              itemBuilder: (ctx, i) => buildRow(i),
            ),
          ),
        ),
      ],
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
    return Container(
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
    );
  }

  // ── Status chip ────────────────────────────────────────────────────────────
  Widget _buildStatusChip(PlayerSeasonStats s, bool isNamed,
      bool isDrafted, PlayerFlagEntry? flag) {
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
  String _gameTypeLabel(String type) {
    switch (type) {
      case 'thursday_pairs':  return 'Thursday Pairs';
      case 'friday_pairs':    return 'Friday Pairs';
      case 'saturday_pairs':  return 'Saturday Pairs';
      case 'sunday_pairs':    return 'Sunday Pairs';
      case 'monday_pairs':    return 'Monday Pairs';
      case 'weekend_quads':   return 'Weekend Quads';
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