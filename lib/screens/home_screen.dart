import 'package:flutter/material.dart';

import '../helpers/round_helper.dart';
import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/punter_score_service.dart';
import '../services/championship_service.dart';
import '../services/round_completion_service.dart';
import '../services/user_role_service.dart';
import '../services/game_data_cache.dart';
import '../services/scout_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_tile.dart';
import '../widgets/background_container.dart';

import 'game_view_screen.dart';
import 'custom_pairs_builder_screen.dart';
import 'championship_screen.dart';
import 'insights_screen.dart';
import 'scout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
/// Top-level shell.  Replaces the old Season → Round → GameType three-screen
/// push stack with a single screen that has:
///   • A compact season + round filter bar at the top of the Games tab
///   • A BottomNavigationBar with Games / Scout / Insights / Championship
///
/// All services are still injected from [main.dart] — no change to how data
/// flows; this is purely structural.
class HomeScreen extends StatefulWidget {
  final List<int> seasons;
  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;
  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;

  const HomeScreen({
    super.key,
    required this.seasons,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.fantasyService,
    required this.roundCompletionService,
    required this.userRoleService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Nav state ──────────────────────────────────────────────────────────────
  int _tabIndex = 0;

  // ── Selection state ────────────────────────────────────────────────────────
  late int _season;
  int? _round; // null = Pre-Season

  // ── Services (created once) ────────────────────────────────────────────────
  final GameDataCache        _gameDataCache       = GameDataCache();
  final ChampionshipService  _championshipService = ChampionshipService();
  final ScoutService         _scoutService        = ScoutService();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _season = widget.seasons.last; // default to most recent season
    _round  = _defaultRound();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int? _defaultRound() {
    final rounds = widget.fixtureRepo.allRoundsForSeason(_season);
    if (rounds.isEmpty) return null;
    // Default to the first incomplete round, or the last completed one
    final completed = widget.roundCompletionService.completedRounds;
    for (final r in rounds) {
      if (!completed.contains(r)) return r;
    }
    return rounds.last;
  }

  List<int?> _roundsForSeason(int season) {
    final rounds = <int?>[];
    if (widget.fixtureRepo.preseasonFixturesForSeason(season).isNotEmpty) {
      rounds.add(null);
    }
    rounds.addAll(widget.fixtureRepo.allRoundsForSeason(season));
    return rounds;
  }

  List<PunterSelection> _createEmptySelections(int playersPerPunter) {
    return List.generate(
      15,
      (i) => PunterSelection(
        punterNumber: i + 1,
        punterName:   '',
        picks: List.generate(
          playersPerPunter,
          (j) => PlayerPick(pickNumber: j + 1, player: null, stats: null),
        ),
      ),
    );
  }

  List<PunterSelection> _selectionsFor(String type) {
    final key = '$_season-$_round-$type';
    if (_gameDataCache.hasSelections(key)) return _gameDataCache.getSelections(key);
    final ppk = type == 'weekend_quads' ? 4 : 2;
    final list = _createEmptySelections(ppk);
    _gameDataCache.setSelections(key, list);
    return list;
  }

  String _defaultGameTypeForRound() {
    final fixtures = widget.fixtureRepo.fixturesForSeasonRound(_season, _round);
    if (fixtures.isEmpty) return 'weekend_quads';
    final days = fixtures.map((f) => f.date?.weekday).toSet();
    if (days.contains(DateTime.friday))   return 'friday_pairs';
    if (days.contains(DateTime.saturday)) return 'saturday_pairs';
    return 'weekend_quads';
  }

  // ── Game-type actions ──────────────────────────────────────────────────────

  void _openGame(String type) {
    if (type == 'custom_builder') {
      if (!widget.userRoleService.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admins only')),
        );
        return;
      }
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CustomPairsBuilderScreen(
          season:                _season,
          round:                 _round,
          fixtureRepo:           widget.fixtureRepo,
          playerRepo:            widget.playerRepo,
          fantasyService:        widget.fantasyService,
          championshipService:   _championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService:       widget.userRoleService,
          gameDataCache:         _gameDataCache,
        ),
      ));
      return;
    }

    if (type == 'custom_game') {
      final cacheKey   = '$_season-${_round ?? 0}-custom_game';
      final fixtureIds = _gameDataCache.hasFixtureIds(cacheKey)
          ? _gameDataCache.getFixtureIds(cacheKey)
          : null;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GameViewScreen(
          season:                _season,
          round:                 _round,
          gameType:              'custom_game',
          selections:            _selectionsFor('custom_game'),
          fixtureRepo:           widget.fixtureRepo,
          playerRepo:            widget.playerRepo,
          fantasyService:        widget.fantasyService,
          championshipService:   _championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService:       widget.userRoleService,
          gameDataCache:         _gameDataCache,
          selectedFixtureIds:    fixtureIds,
        ),
      ));
      return;
    }

    // Normal game types
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameViewScreen(
        season:                _season,
        round:                 _round,
        gameType:              type,
        selections:            _selectionsFor(type),
        fixtureRepo:           widget.fixtureRepo,
        playerRepo:            widget.playerRepo,
        fantasyService:        widget.fantasyService,
        championshipService:   _championshipService,
        roundCompletionService: widget.roundCompletionService,
        userRoleService:       widget.userRoleService,
        gameDataCache:         _gameDataCache,
      ),
    ));
  }

  void _openScout() {
    final gameType = _round == null ? 'weekend_quads' : _defaultGameTypeForRound();
    final drafted  = <String>{};
    for (final sel in _selectionsFor(gameType)) {
      for (final pick in sel.picks) {
        final pid = pick.player?.id;
        if (pid != null && pid.isNotEmpty) drafted.add(pid);
      }
    }
    final customKey      = '$_season-${_round ?? 0}-custom_game';
    final scoutFixtureIds = _gameDataCache.hasFixtureIds(customKey)
        ? _gameDataCache.getFixtureIds(customKey)
        : null;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScoutScreen(
        season:             _season,
        round:              _round,
        gameType:           gameType,
        fixtureRepo:        widget.fixtureRepo,
        playerRepo:         widget.playerRepo,
        scoutService:       _scoutService,
        userEmail:          widget.userRoleService.currentUser ?? '',
        draftedPlayerIds:   drafted,
        selectedFixtureIds: scoutFixtureIds,
      ),
    ));
  }

  void _openInsights() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InsightsScreen(season: _season),
    ));
  }

  void _openChampionship() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChampionshipScreen(
        service:    _championshipService,
        playerRepo: widget.playerRepo,
        season:     _season,
      ),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isPortraitPhone(context);
    final wide   = Responsive.isWide(context);

    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: _buildBody(mobile, wide)),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return NavigationBar(
      selectedIndex: _tabIndex,
      onDestinationSelected: (i) {
        if (i == 1) { _openScout();       return; }
        if (i == 2) { _openInsights();    return; }
        if (i == 3) { _openChampionship(); return; }
        setState(() => _tabIndex = i);
      },
      destinations: const [
        NavigationDestination(
          icon:           Icon(Icons.sports_football_outlined),
          selectedIcon:   Icon(Icons.sports_football),
          label:          'Games',
        ),
        NavigationDestination(
          icon:           Icon(Icons.search_outlined),
          selectedIcon:   Icon(Icons.search),
          label:          'Scout',
        ),
        NavigationDestination(
          icon:           Icon(Icons.bar_chart_outlined),
          selectedIcon:   Icon(Icons.bar_chart),
          label:          'Insights',
        ),
        NavigationDestination(
          icon:           Icon(Icons.emoji_events_outlined),
          selectedIcon:   Icon(Icons.emoji_events),
          label:          'Medal',
        ),
      ],
    );
  }

  Widget _buildBody(bool mobile, bool wide) {
    return Column(
      children: [
        _buildFilterBar(mobile),
        const Divider(height: 1),
        Expanded(child: _buildGameGrid(mobile, wide)),
      ],
    );
  }

  // ── Filter bar (season + round) ────────────────────────────────────────────

  Widget _buildFilterBar(bool mobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 12 : 20,
        vertical:   mobile ? 10 : 14,
      ),
      child: Row(
        children: [
          // App title / logo area
          Expanded(
            child: Text(
              'Fantasy Pairs',
              style: TextStyle(
                color:      AppTheme.textPrimary,
                fontSize:   mobile ? 18 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          // Season picker
          _FilterChip(
            label:   '$_season',
            onTap:   () => _showSeasonPicker(),
            mobile:  mobile,
          ),
          SizedBox(width: mobile ? 8 : 10),
          // Round picker
          _FilterChip(
            label:   RoundHelper.label(_round),
            onTap:   () => _showRoundPicker(),
            mobile:  mobile,
          ),
        ],
      ),
    );
  }

  void _showSeasonPicker() {
    showModalBottomSheet(
      context:       context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PickerSheet(
        title:    'Season',
        items:    widget.seasons.map((s) => '$s').toList(),
        selected: '$_season',
        onSelect: (val) {
          final s = int.parse(val);
          setState(() {
            _season = s;
            _round  = _defaultRound();
          });
        },
      ),
    );
  }

  void _showRoundPicker() {
    final rounds = _roundsForSeason(_season);
    final completed = widget.roundCompletionService.completedRounds;

    showModalBottomSheet(
      context:       context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PickerSheet(
        title:    'Round',
        items:    rounds.map(RoundHelper.label).toList(),
        selected: RoundHelper.label(_round),
        dimmed:   rounds
            .map((r) => r != null && completed.contains(r))
            .toList(),
        onSelect: (val) {
          // Reverse-map label → round value
          final idx = rounds.indexWhere((r) => RoundHelper.label(r) == val);
          if (idx >= 0) setState(() => _round = rounds[idx]);
        },
      ),
    );
  }

  // ── Game grid ──────────────────────────────────────────────────────────────

  static const List<_GameTileDef> _gameTiles = [
    _GameTileDef('thursday_pairs',  'Thursday Pairs',   Icons.calendar_today_outlined),
    _GameTileDef('friday_pairs',    'Friday Pairs',     Icons.calendar_today_outlined),
    _GameTileDef('saturday_pairs',  'Saturday Pairs',   Icons.calendar_today_outlined),
    _GameTileDef('sunday_pairs',    'Sunday Pairs',     Icons.calendar_today_outlined),
    _GameTileDef('monday_pairs',    'Monday Pairs',     Icons.calendar_today_outlined),
    _GameTileDef('weekend_quads',   'Weekend Quads',    Icons.grid_view_outlined),
    _GameTileDef('custom_builder',  'Custom Builder',   Icons.build_outlined,   adminOnly: true),
    _GameTileDef('custom_game',     'Custom Game',      Icons.tune_outlined),
  ];

  Widget _buildGameGrid(bool mobile, bool wide) {
    final isAdmin  = widget.userRoleService.isAdmin;
    final tiles    = _gameTiles
        .where((t) => !t.adminOnly || isAdmin)
        .toList();
    final cols     = wide ? 3 : 2;

    return GridView.builder(
      padding: EdgeInsets.all(mobile ? 12 : 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        mainAxisSpacing:  mobile ? 10 : 14,
        crossAxisSpacing: mobile ? 10 : 14,
        childAspectRatio: mobile ? 2.4 : 3.0,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return AppTile(
          label:  t.label,
          icon:   t.icon,
          onTap:  () => _openGame(t.type),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GameTileDef — simple data class for the grid
// ─────────────────────────────────────────────────────────────────────────────
class _GameTileDef {
  final String   type;
  final String   label;
  final IconData icon;
  final bool     adminOnly;

  const _GameTileDef(this.type, this.label, this.icon, {this.adminOnly = false});
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterChip — compact season/round selector button
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String   label;
  final VoidCallback onTap;
  final bool     mobile;

  const _FilterChip({
    required this.label,
    required this.onTap,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 10 : 14,
          vertical:   mobile ? 6  : 8,
        ),
        decoration: BoxDecoration(
          color:        AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color:      AppTheme.textPrimary,
                fontSize:   mobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: mobile ? 4 : 5),
            Icon(Icons.expand_more, size: mobile ? 14 : 16,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PickerSheet — modal bottom sheet for season / round selection
// ─────────────────────────────────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String         title;
  final List<String>   items;
  final String         selected;
  final List<bool>?    dimmed;
  final void Function(String) onSelect;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color:      AppTheme.textPrimary,
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          ListView.builder(
            shrinkWrap:  true,
            physics:     const NeverScrollableScrollPhysics(),
            itemCount:   items.length,
            itemBuilder: (_, i) {
              final item      = items[i];
              final isSelected = item == selected;
              final isDimmed   = dimmed != null && i < dimmed!.length && dimmed![i];

              return ListTile(
                dense:   true,
                title: Text(
                  item,
                  style: TextStyle(
                    color: isDimmed
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppTheme.primaryLight, size: 18)
                    : (isDimmed
                        ? const Icon(Icons.check_circle_outline,
                            color: AppTheme.textSecondary, size: 16)
                        : null),
                onTap: () {
                  Navigator.pop(context);
                  onSelect(item);
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
