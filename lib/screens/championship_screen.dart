import 'package:flutter/material.dart';

import '../repositories/player_repository.dart';
import '../services/championship_service.dart';
import '../widgets/background_container.dart';

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
  String? _selectedMonth;
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
      if (months.isNotEmpty && _selectedMonth == null) {
        _selectedMonth = months.last; // default to most recent month
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.service.months;

    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Championship"),
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
          bottom: _loading || months.isEmpty
              ? null
              : TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: "Overall"),
                    Tab(text: "Monthly"),
                  ],
                ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : months.isEmpty
                ? const Center(
                    child: Text(
                      "No completed Weekend Quads rounds yet.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // ── OVERALL TAB ──────────────────────────────────
                      _PointsTable(
                        service: widget.service,
                        roundNumbers: null, // all rounds
                        title: "Overall Championship",
                      ),

                      // ── MONTHLY TAB ──────────────────────────────────
                      Column(
                        children: [
                          _MonthSelector(
                            months: months,
                            selected: _selectedMonth,
                            onChanged: (m) =>
                                setState(() => _selectedMonth = m),
                          ),
                          Expanded(
                            child: _selectedMonth == null
                                ? const SizedBox()
                                : _PointsTable(
                                    service: widget.service,
                                    roundNumbers: widget.service
                                        .roundNumbersForMonth(_selectedMonth!),
                                    title: "$_selectedMonth Championship",
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MONTH SELECTOR
// ─────────────────────────────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  final List<String> months;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _MonthSelector({
    required this.months,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text("Month:", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: selected,
            items: months
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POINTS TABLE
// ─────────────────────────────────────────────────────────────
class _PointsTable extends StatelessWidget {
  final ChampionshipService service;
  final List<int>? roundNumbers;
  final String title;

  const _PointsTable({
    required this.service,
    required this.roundNumbers,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rows = service.buildPointsTable(roundNumbers: roundNumbers);
    final rounds = service.sortedRoundNumbers(roundNumbers: roundNumbers);

    if (rows.isEmpty) {
      return Center(
        child: Text(
          "No data available",
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }

    const double rankW = 36;
    const double nameW = 110;
    const double roundW = 44;
    const double totalW = 52;

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );

    final boldStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w800,
    );

    Widget headerCell(String text, double width,
        {Alignment align = Alignment.center}) {
      return Container(
        width: width,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text, style: headerStyle, overflow: TextOverflow.ellipsis),
      );
    }

    Widget dataCell(String text, double width,
        {TextStyle? style, Alignment align = Alignment.center,
        Color? bg}) {
      return Container(
        width: width,
        alignment: align,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text, style: style ?? cellStyle,
            overflow: TextOverflow.ellipsis),
      );
    }

    // Fixed left columns (rank + name)
    final fixedHeader = Row(children: [
      headerCell("#", rankW),
      headerCell("Punter", nameW, align: Alignment.centerLeft),
    ]);

    // Scrollable right columns (rounds + total)
    final scrollHeader = Row(children: [
      ...rounds.map((r) => headerCell("R$r", roundW)),
      headerCell("Total", totalW),
    ]);

    // Build rows
    Widget buildRow(int index) {
      final row = rows[index];
      final isEven = index.isEven;
      final bg = isEven
          ? cs.surface
          : cs.surfaceVariant;

      final fixedPart = Row(children: [
        dataCell("${index + 1}", rankW, bg: bg),
        dataCell(row.punterName, nameW,
            align: Alignment.centerLeft, bg: bg),
      ]);

      final scrollPart = Row(children: [
        ...rounds.map((r) {
          final pts = row.pointsForRound(r);
          return dataCell(
            pts > 0 ? "$pts" : "–",
            roundW,
            style: pts > 0
                ? boldStyle?.copyWith(
                    color: _pointsColour(pts, cs))
                : cellStyle?.copyWith(color: cs.onSurface.withOpacity(0.4)),
            bg: bg,
          );
        }),
        dataCell("${row.total}", totalW,
            style: boldStyle, bg: bg),
      ]);

      return SizedBox(
        height: 32,
        child: Row(
          children: [
            fixedPart,
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: scrollPart,
              ),
            ),
          ],
        ),
      );
    }

    final scrollController = ScrollController();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 2,
        color: cs.surface,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 8),

              // Header
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  border: Border(
                    bottom: BorderSide(
                        color: cs.primary.withAlpha(60), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    fixedHeader,
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (_) => false,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          child: scrollHeader,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      scrollController.jumpTo(
                          notification.metrics.pixels);
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) => buildRow(i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Colour-codes championship points — gold/silver/bronze for top 3 scores.
  Color _pointsColour(int pts, ColorScheme cs) {
    if (pts == 25) return const Color(0xFFFFD700); // gold
    if (pts == 18) return const Color(0xFFC0C0C0); // silver
    if (pts == 15) return const Color(0xFFCD7F32); // bronze
    return cs.primary;
  }
}