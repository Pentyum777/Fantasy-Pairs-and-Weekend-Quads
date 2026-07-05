import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

import '../repositories/player_repository.dart';
import '../services/championship_service.dart';

// Allows click-and-drag horizontal scrolling with a mouse, in addition to
// the default touch/stylus/trackpad support — needed for the Overall
// Championship table's round columns on desktop, where there was
// previously no way to trigger the scroll at all.
class _HorizontalDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class ChampionshipScreen extends StatefulWidget {
  final ChampionshipService service;
  final PlayerRepository playerRepo;
  final int season;

  const ChampionshipScreen({
    super.key,
    required this.service,
    required this.playerRepo,
    required this.season,
  });

  @override
  State<ChampionshipScreen> createState() => _ChampionshipScreenState();
}

class _ChampionshipScreenState extends State<ChampionshipScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedSeries;
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await widget.service.loadFromBackend(
      season: widget.season,
      playerRepo: widget.playerRepo,
      gameType: "weekend_quads",
    );
    if (!mounted) return;
    final months = widget.service.months;
    setState(() {
      _loading = false;
      if (months.isNotEmpty && _selectedSeries == null) {
        _selectedSeries = months.first; // default to Series 1
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;
    final months = widget.service.months;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Monthly Medal"),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          if (!_loading && _selectedSeries != null)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: "Snapshot",
              onPressed: () => _MedalSnapshotOverlay.show(
                context,
                service: widget.service,
                selectedSeries: _selectedSeries!,
              ),
            ),
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Reload",
              onPressed: () {
                setState(() => _loading = true);
                _loadData();
              },
            ),
        ],
        // On portrait show tabs to switch between Overall / Monthly
        bottom: (!_loading && months.isNotEmpty && !isWide)
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Overall"),
                  Tab(text: "Monthly Medal"),
                ],
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : months.isEmpty
              ? Center(
                  child: Text("No completed Weekend Quads rounds yet.",
                      style: theme.textTheme.bodyMedium),
                )
              : Column(
                  children: [
                    Expanded(
                      child: isWide
                          ? _wideLayout(theme, months)
                          : _portraitLayout(theme, months),
                    ),
                    _PointsLegend(),
                  ],
                ),
    );
  }

  // ── WIDE LAYOUT (tablet/desktop) — side by side ────────────
  Widget _wideLayout(ThemeData theme, List<String> months) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text("Overall Championship",
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Text(
                      _selectedSeries == null
                          ? "Monthly Medal"
                          : "$_selectedSeries · Monthly Medal",
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text("Medal:", style: theme.textTheme.labelMedium),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _selectedSeries,
                      isDense: true,
                      items: months
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedSeries = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tables
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _PointsTable(
                    service: widget.service,
                    roundNumbers: null,
                    title: "",
                    scrollable: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _selectedSeries == null
                      ? const SizedBox()
                      : _PointsTable(
                          service: widget.service,
                          roundNumbers: widget.service
                              .roundNumbersForSeries(_selectedSeries!),
                          title: "",
                          scrollable: false,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PORTRAIT LAYOUT (phone) — tabbed ──────────────────────
  Widget _portraitLayout(ThemeData theme, List<String> months) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Overall tab
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _PointsTable(
            service: widget.service,
            roundNumbers: null,
            title: "Overall Championship",
            scrollable: true,
          ),
        ),

        // Monthly tab
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month selector
              Row(
                children: [
                  Text("Medal:", style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedSeries,
                    isDense: true,
                    items: months
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSeries = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _selectedSeries == null
                    ? const SizedBox()
                    : _PointsTable(
                        service: widget.service,
                        roundNumbers: widget.service
                            .roundNumbersForSeries(_selectedSeries!),
                        title: "$_selectedSeries · Monthly Medal",
                        scrollable: false,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POINTS TABLE
// ─────────────────────────────────────────────────────────────
class _PointsTable extends StatefulWidget {
  final ChampionshipService service;
  final List<int>? roundNumbers;
  final String title;
  final bool scrollable;

  const _PointsTable({
    required this.service,
    required this.roundNumbers,
    required this.title,
    required this.scrollable,
  });

  @override
  State<_PointsTable> createState() => _PointsTableState();
}

class _PointsTableState extends State<_PointsTable> {
  final _headerScroll = ScrollController();
  final _bodyScroll = ScrollController();

  // Fixed (rank/name) column and scrollable (rounds/total) column are
  // rendered as two separate vertical lists so the horizontal scroll of
  // the rounds columns can be ONE single widget (see below). These two
  // controllers keep their vertical position in sync with each other.
  final _leftVScroll = ScrollController();
  final _rightVScroll = ScrollController();
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _bodyScroll.addListener(() {
      if (_headerScroll.hasClients) {
        _headerScroll.jumpTo(_bodyScroll.offset);
      }
    });
    _leftVScroll.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_rightVScroll.hasClients) _rightVScroll.jumpTo(_leftVScroll.offset);
      _syncingV = false;
    });
    _rightVScroll.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_leftVScroll.hasClients) _leftVScroll.jumpTo(_rightVScroll.offset);
      _syncingV = false;
    });
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
    _leftVScroll.dispose();
    _rightVScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 600;

    final rows = widget.service.buildPointsTable(
        roundNumbers: widget.roundNumbers);
    final rounds = widget.service.sortedRoundNumbers(
        roundNumbers: widget.roundNumbers);

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            _titleWidget(theme),
            const SizedBox(height: 8),
          ],
          Text("No data available",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
        ],
      );
    }

    // Slightly narrower columns on phone
    final double rankW = isPhone ? 28 : 32;
    final double nameW = isPhone ? 80 : 100;
    final double roundW = isPhone ? 36 : 42;
    final double totalW = isPhone ? 42 : 48;
    const double rowH = 30;
    const double headerH = 28;

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final boldStyle = theme.textTheme.bodySmall
        ?.copyWith(fontWeight: FontWeight.w800);

    Widget hCell(String t, double w,
        {Alignment a = Alignment.center}) =>
        Container(
          width: w,
          height: headerH,
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(t,
              style: headerStyle, overflow: TextOverflow.ellipsis),
        );

    Widget dCell(String t, double w,
        {TextStyle? style,
        Alignment a = Alignment.center,
        Color? bg}) =>
        Container(
          width: w,
          height: rowH,
          alignment: a,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(t,
              style: style ?? cellStyle,
              overflow: TextOverflow.ellipsis),
        );

    Color rowBg(int i) =>
        i.isEven ? cs.surface : cs.surfaceVariant;

    Color ptColor(int pts) {
      if (pts == 25) return const Color(0xFFFFAA00);
      if (pts == 18) return const Color(0xFF9E9E9E);
      if (pts == 15) return const Color(0xFFCD7F32);
      return cs.primary;
    }

    Widget fixedHeader() => Row(children: [
          hCell("#", rankW),
          hCell("Punter", nameW, a: Alignment.centerLeft),
        ]);

    Widget fixedRow(int i) {
      final row = rows[i];
      final bg = rowBg(i);
      return Row(children: [
        dCell("${i + 1}", rankW, bg: bg),
        dCell(row.punterName, nameW,
            a: Alignment.centerLeft, bg: bg),
      ]);
    }

    final double scrollWidth = rounds.length * roundW + totalW;

    Widget scrollHeader() => SizedBox(
          width: scrollWidth,
          child: Row(children: [
            ...rounds.map((r) => hCell("R$r", roundW)),
            hCell("Total", totalW),
          ]),
        );

    Widget scrollRow(int i) {
      final row = rows[i];
      final bg = rowBg(i);
      return SizedBox(
        width: scrollWidth,
        child: Row(children: [
          ...rounds.map((r) {
            final pts = row.pointsForRound(r);
            return dCell(
              pts > 0 ? "$pts" : "–",
              roundW,
              style: pts > 0
                  ? boldStyle?.copyWith(color: ptColor(pts))
                  : cellStyle?.copyWith(
                      color: cs.onSurface.withOpacity(0.3)),
              bg: bg,
            );
          }),
          dCell("${row.total}", totalW, style: boldStyle, bg: bg),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          _titleWidget(theme),
          const SizedBox(height: 6),
        ],

        // Header
        Container(
          height: headerH,
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                  color: cs.primary.withAlpha(80), width: 1),
            ),
          ),
          child: Row(
            children: [
              fixedHeader(),
              Expanded(
                child: widget.scrollable
                    ? SingleChildScrollView(
                        controller: _headerScroll,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: scrollHeader(),
                      )
                    : scrollHeader(),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: widget.scrollable
              ? ScrollConfiguration(
                  // Desktop (mouse) users need drag-to-scroll enabled —
                  // by default Flutter only allows touch/stylus/trackpad.
                  behavior: _HorizontalDragScrollBehavior(),
                  child: Row(
                    children: [
                      // Fixed rank/punter column — its own vertical list,
                      // kept in sync with the scrollable column below.
                      SizedBox(
                        width: rankW + nameW,
                        child: ListView.builder(
                          controller: _leftVScroll,
                          itemCount: rows.length,
                          itemExtent: rowH,
                          itemBuilder: (ctx, i) => fixedRow(i),
                        ),
                      ),
                      // Scrollable rounds/total column — ONE horizontal
                      // scroll region for every row at once (previously
                      // each row had its own scroll view sharing a single
                      // controller, so dragging one row didn't move the
                      // others or the header).
                      Expanded(
                        child: Scrollbar(
                          controller: _bodyScroll,
                          thumbVisibility: true,
                          trackVisibility: true,
                          notificationPredicate: (_) => true,
                          child: SingleChildScrollView(
                            controller: _bodyScroll,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: scrollWidth,
                              child: ListView.builder(
                                controller: _rightVScroll,
                                itemCount: rows.length,
                                itemExtent: rowH,
                                itemBuilder: (ctx, i) => scrollRow(i),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemExtent: rowH,
                  itemBuilder: (ctx, i) => Row(
                    children: [
                      fixedRow(i),
                      Expanded(child: scrollRow(i)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _titleWidget(ThemeData theme) => Text(
        widget.title,
        style: theme.textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      );
}

// ─────────────────────────────────────────────────────────────
// POINTS LEGEND
// ─────────────────────────────────────────────────────────────
class _PointsLegend extends StatelessWidget {
  static const List<MapEntry<String, int>> _positions = [
    MapEntry("1st", 25),
    MapEntry("2nd", 18),
    MapEntry("3rd", 15),
    MapEntry("4th", 12),
    MapEntry("5th", 10),
    MapEntry("6th", 8),
    MapEntry("7th", 6),
    MapEntry("8th", 4),
    MapEntry("9th", 2),
    MapEntry("10th", 1),
  ];

  const _PointsLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: 8, vertical: isPhone ? 6 : 8),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        border: Border(
            top: BorderSide(color: cs.outline.withOpacity(0.2))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: isPhone ? 8 : 16,
        runSpacing: 4,
        children: _positions.map((e) {
          final color = e.value == 25
              ? const Color(0xFFFFAA00)
              : e.value == 18
                  ? const Color(0xFF9E9E9E)
                  : e.value == 15
                      ? const Color(0xFFCD7F32)
                      : cs.onSurface.withOpacity(0.7);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.key,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                "${e.value}",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDAL SNAPSHOT OVERLAY
//
// Full-screen modal that renders the Overall Championship table and the
// selected Monthly Medal table side by side, at natural (desktop) size,
// scaled to fit the device via FittedBox — same pattern as ScreenshotOverlay
// used for the punter selection table + leaderboard.
// ─────────────────────────────────────────────────────────────────────────────
class _MedalSnapshotOverlay extends StatelessWidget {
  final ChampionshipService service;
  final String selectedSeries;

  const _MedalSnapshotOverlay({
    required this.service,
    required this.selectedSeries,
  });

  static void show(
    BuildContext context, {
    required ChampionshipService service,
    required String selectedSeries,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: true,
      builder: (_) => _MedalSnapshotOverlay(
        service: service,
        selectedSeries: selectedSeries,
      ),
    );
  }

  // Natural (desktop) column widths — matches the non-phone branch of
  // _PointsTableState.build so the snapshot always renders at full detail
  // regardless of the device it's captured on.
  static const double _rankW = 32;
  static const double _nameW = 100;
  static const double _roundW = 42;
  static const double _totalW = 48;
  static const double _rowH = 30;
  static const double _headerH = 28;
  static const double _titleBlockH = 32; // title text + spacing, with buffer
  static const double _padding = 12.0;
  static const double _gap = 16.0;

  double _tableWidth(int roundCount) =>
      _rankW + _nameW + roundCount * _roundW + _totalW;

  double _tableHeight(int rowCount) =>
      _titleBlockH + _headerH + rowCount * _rowH;

  @override
  Widget build(BuildContext context) {
    final overallRows =
        service.buildPointsTable(roundNumbers: null);
    final overallRounds =
        service.sortedRoundNumbers(roundNumbers: null);

    final monthRoundNumbers = service.roundNumbersForSeries(selectedSeries);
    final monthRows =
        service.buildPointsTable(roundNumbers: monthRoundNumbers);

    final overallW = _tableWidth(overallRounds.length);
    final monthW = _tableWidth(monthRoundNumbers.length);
    final overallH = _tableHeight(overallRows.length);
    final monthH = _tableHeight(monthRows.length);

    final naturalW = overallW + _gap + monthW + _padding * 2;
    final naturalH =
        (overallH > monthH ? overallH : monthH) + _padding * 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: naturalW,
                  height: naturalH,
                  child: _buildContent(
                    context,
                    overallW,
                    overallH,
                    monthW,
                    monthH,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: _SnapshotCloseButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Pinch to zoom · tap ✕ to close',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    double overallW,
    double overallH,
    double monthW,
    double monthH,
  ) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(_padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: overallW,
            height: overallH,
            child: _PointsTable(
              service: service,
              roundNumbers: null,
              title: "Overall Championship",
              scrollable: false,
            ),
          ),
          const SizedBox(width: _gap),
          SizedBox(
            width: monthW,
            height: monthH,
            child: _PointsTable(
              service: service,
              roundNumbers: service.roundNumbersForSeries(selectedSeries),
              title: "$selectedSeries · Monthly Medal",
              scrollable: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SnapshotCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade900.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}