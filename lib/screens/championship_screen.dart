import 'package:flutter/material.dart';

import '../repositories/player_repository.dart';
import '../services/championship_service.dart';

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

  @override
  void initState() {
    super.initState();
    _bodyScroll.addListener(() {
      if (_headerScroll.hasClients) {
        _headerScroll.jumpTo(_bodyScroll.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
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
          child: ListView.builder(
            itemCount: rows.length,
            itemExtent: rowH,
            itemBuilder: (ctx, i) => Row(
              children: [
                fixedRow(i),
                Expanded(
                  child: widget.scrollable
                      ? SingleChildScrollView(
                          controller: _bodyScroll,
                          scrollDirection: Axis.horizontal,
                          child: scrollRow(i),
                        )
                      : scrollRow(i),
                ),
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