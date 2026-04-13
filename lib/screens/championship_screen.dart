import 'package:flutter/material.dart';

import '../models/punter_selection.dart';
import '../repositories/player_repository.dart';
import '../services/championship_service.dart';
import '../widgets/leaderboard_table.dart';
import '../constants/ui_dimensions.dart';
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

class _ChampionshipScreenState extends State<ChampionshipScreen> {
  String? _selectedMonth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Always reload from the backend so we pick up any rounds completed
    // in previous sessions — not just the current one.
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
        _selectedMonth = months.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.service.months;

    final List<PunterSelection> overallLeaderboard =
        widget.service.overallLeaderboard;

    final List<PunterSelection> monthlyLeaderboard = _selectedMonth == null
        ? []
        : widget.service.monthlyLeaderboard(_selectedMonth!);

    final double leaderboardWidth = UIDimensions.rankColumnWidth +
        UIDimensions.punterNameColumnWidth +
        UIDimensions.totalColumnWidth;

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
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month selector
                        Row(
                          children: [
                            Text(
                              "Month:",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: _selectedMonth,
                              items: months
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedMonth = value);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Side-by-side leaderboards
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Overall Championship
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Overall Championship",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: LeaderboardTable(
                                        punters: overallLeaderboard,
                                        rowHeight: UIDimensions.rowHeight,
                                        totalWidth: leaderboardWidth,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Monthly Championship
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedMonth == null
                                          ? "Monthly Championship"
                                          : "$_selectedMonth Championship",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: LeaderboardTable(
                                        punters: monthlyLeaderboard,
                                        rowHeight: UIDimensions.rowHeight,
                                        totalWidth: leaderboardWidth,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}