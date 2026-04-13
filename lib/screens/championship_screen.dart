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

class _ChampionshipScreenState extends State<ChampionshipScreen> {
  String? _selectedMonth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      if (months.isNotEmpty && _selectedMonth == null) {
        _selectedMonth = months.last;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = widget.service.months;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Championship"),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Reload from server",
              onPressed: () {
                setState(() => _loading = true);
                _loadData();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : months.isEmpty
              ? Center(
                  child: Text(
                    "No completed Weekend Quads rounds yet.",
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // ── SHARED TITLE ROW ────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Overall title (flex 3)
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Overall Championship",
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Monthly title + month dropdown (flex 2)
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Text(
                                  _selectedMonth == null
                                      ? "Monthly Championship"
                                      : "$_selectedMonth Championship",
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Text("Month:",
                                    style: theme.textTheme.labelMedium),
                                const SizedBox(width: 6),
                                DropdownButton<String>(
                                  value: _selectedMonth,
                                  isDense: true,
                                  items: months
                                      .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _selectedMonth = v);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ── TABLES SIDE BY SIDE ──────────────────────────
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT: OVERALL
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
                            // RIGHT: MONTHLY
                            Expanded(
                              flex: 2,
                              child: _selectedMonth == null
                                  ? const SizedBox()
                                  : _PointsTable(
                                      service: widget.service,
                                      roundNumbers: widget.service
                                          .roundNumbersForMonth(_selectedMonth!),
                                      title: "",
                                      scrollable: false,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── POINTS LEGEND ────────────────────────────────
                      _PointsLegend(),
                    ],
                  ),
                ),
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
  final bool scrollable; // true = horizontal scroll for many rounds

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
    // Sync header and body horizontal scroll
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

    final rows = widget.service.buildPointsTable(
        roundNumbers: widget.roundNumbers);
    final rounds = widget.service.sortedRoundNumbers(
        roundNumbers: widget.roundNumbers);

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) _title(theme),
          if (widget.title.isNotEmpty) const SizedBox(height: 8),
          Text("No data available",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
        ],
      );
    }

    const double rankW = 32;
    const double nameW = 100;
    const double roundW = 42;
    const double totalW = 48;
    const double rowH = 30;
    const double headerH = 26;

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    final boldStyle =
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800);

    // ── helpers ──────────────────────────────────────────────
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
      if (pts == 25) return const Color(0xFFFFAA00); // gold
      if (pts == 18) return const Color(0xFF9E9E9E); // silver
      if (pts == 15) return const Color(0xFFCD7F32); // bronze
      return cs.primary;
    }

    // ── fixed columns (rank + name) ───────────────────────────
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

    // ── scrollable columns (rounds + total) ──────────────────
    double scrollWidth =
        rounds.length * roundW + totalW;

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

    // ── build ─────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(theme),
        const SizedBox(height: 6),

        // Header row
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
                        physics:
                            const NeverScrollableScrollPhysics(),
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

  Widget _title(ThemeData theme) => Text(
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _positions.map((e) {
          final isTop3 = e.value >= 15;
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
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                "${e.value}",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
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