import 'package:flutter/material.dart';

import '../models/punter_selection.dart';
import '../services/championship_service.dart';
import '../widgets/leaderboard_table.dart';

class ChampionshipScreen extends StatefulWidget {
  final ChampionshipService service;

  const ChampionshipScreen({
    super.key,
    required this.service,
  });

  @override
  State<ChampionshipScreen> createState() => _ChampionshipScreenState();
}

class _ChampionshipScreenState extends State<ChampionshipScreen> {
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();

    final months = widget.service.months;
    if (months.isNotEmpty) {
      _selectedMonth = months.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.service.months;

    final List<PunterSelection> overallLeaderboard =
        widget.service.overallLeaderboard;

    final List<PunterSelection> monthlyLeaderboard = _selectedMonth == null
        ? []
        : widget.service.monthlyLeaderboard(_selectedMonth!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Championship"),
      ),
      body: Padding(
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
                    setState(() {
                      _selectedMonth = value;
                    });
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
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LeaderboardTable(
                            punters: overallLeaderboard,
                            rowHeight: 34,
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
                              : "${_selectedMonth!} Championship",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LeaderboardTable(
                            punters: monthlyLeaderboard,
                            rowHeight: 34,
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
    );
  }
}