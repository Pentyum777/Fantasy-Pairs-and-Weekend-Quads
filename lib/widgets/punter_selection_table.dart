import 'package:flutter/material.dart';
import '../models/afl_player.dart';
import '../models/punter_selection.dart';

class PunterSelectionTable extends StatelessWidget {
  final int punterCount;
  final int playersPerPunter;
  final List<AflPlayer> availablePlayers;
  final List<PunterSelection> selections;
  final VoidCallback onChanged;

  const PunterSelectionTable({
    super.key,
    required this.punterCount,
    required this.playersPerPunter,
    required this.availablePlayers,
    required this.selections,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DataTable(
            headingRowHeight: 28,
            dataRowMinHeight: 28,   // ✔ replaces deprecated dataRowHeight
            dataRowMaxHeight: 28,   // ✔ replaces deprecated dataRowHeight
            columnSpacing: 10,
            horizontalMargin: 4,
            columns: _buildColumns(),
            rows: _buildRows(context),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildLeaderboard(),
        ),
      ],
    );
  }

  List<DataColumn> _buildColumns() {
    final cols = <DataColumn>[
      const DataColumn(
        label: Text("Punter", style: TextStyle(fontSize: 11)),
      ),
    ];

    for (int i = 0; i < playersPerPunter; i++) {
      cols.add(
        DataColumn(
          label: Text("P${i + 1}", style: const TextStyle(fontSize: 11)),
        ),
      );
      cols.add(
        const DataColumn(
          label: Text("Player", style: TextStyle(fontSize: 11)),
        ),
      );
      cols.add(
        const DataColumn(
          label: Text("S", style: TextStyle(fontSize: 11)),
        ),
      );
    }

    cols.add(
      const DataColumn(
        label: Text("TOTAL", style: TextStyle(fontSize: 11)),
      ),
    );

    return cols;
  }

  List<DataRow> _buildRows(BuildContext context) {
    return List.generate(punterCount, (index) {
      final punter = selections[index];
      final cells = <DataCell>[];

      // Name field
      cells.add(
        DataCell(
          SizedBox(
            width: 80,
            height: 24,
            child: TextField(
              controller: TextEditingController(text: punter.name),
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              ),
              onChanged: (value) {
                punter.name = value;
                onChanged();
              },
            ),
          ),
        ),
      );

      int totalScore = 0;

      for (int slot = 0; slot < playersPerPunter; slot++) {
        final selected = punter.players[slot];
        final score = selected?.liveScore ?? 0;
        totalScore += score;

        // Slot number
        cells.add(
          DataCell(
            Text("${slot + 1}", style: const TextStyle(fontSize: 11)),
          ),
        );

        // Player autocomplete
        cells.add(
          DataCell(
            SizedBox(
              width: 110,
              height: 24,
              child: Autocomplete<AflPlayer>(
                initialValue: TextEditingValue(
                  text: selected?.name ?? "",
                ),
                optionsBuilder: (value) {
                  if (value.text.isEmpty) {
                    return const Iterable<AflPlayer>.empty();
                  }
                  return availablePlayers.where(
                    (p) => p.name.toLowerCase().contains(
                          value.text.toLowerCase(),
                        ),
                  );
                },
                displayStringForOption: (p) => p.name,
                onSelected: (p) {
                  punter.players[slot] = p;
                  onChanged();
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Score
        cells.add(
          DataCell(
            Text("$score", style: const TextStyle(fontSize: 11)),
          ),
        );
      }

      // Total score
      cells.add(
        DataCell(
          Text("$totalScore", style: const TextStyle(fontSize: 11)),
        ),
      );

      return DataRow(cells: cells);
    });
  }

  Widget _buildLeaderboard() {
    final totals = <MapEntry<String, int>>[];

    for (int i = 0; i < punterCount; i++) {
      final punter = selections[i];
      final total = punter.players
          .map((p) => p?.liveScore ?? 0)
          .fold(0, (a, b) => a + b);

      totals.add(
        MapEntry(
          punter.name.isEmpty ? "P${i + 1}" : punter.name,
          total,
        ),
      );
    }

    totals.sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "LEADERBOARD",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: totals.length,
              itemBuilder: (context, index) {
                final entry = totals[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    "${index + 1}. ${entry.key} – ${entry.value}",
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}