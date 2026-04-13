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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── LEFT: OVERALL (horizontal scroll) ──────────
                      Expanded(
                        flex: 3,
                        child: _PointsTable(
                          service: widget.service,
                          roundNumbers: null,
                          title: "Overall Championship",
                          scrollable: true,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ── RIGHT: MONTHLY ──────────────────────────────
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Month selector
                            Row(
                              children: [
                                Text("Month:",
                                    style: theme.textTheme.labelMedium),
                                const SizedBox(width: 8),
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
                            const SizedBox(height: 8),
                            Expanded(
                              child: _selectedMonth == null
                                  ? const SizedBox()
                                  : _PointsTable(
                                      service: widget.service,
                                      roundNumbers: widget.service
                                          .roundNumbersForMonth(
                                              _selectedMonth!),
                                      title:
                                          "$_selectedMonth Championship",
                                      scrollable: false,
                                    ),
                            ),
                          ],
                        ),
                      ),
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
          _title(theme),
          const SizedBox(height: 8),
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