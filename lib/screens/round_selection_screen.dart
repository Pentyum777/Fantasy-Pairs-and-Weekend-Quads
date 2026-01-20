import 'package:flutter/material.dart';
import '../helpers/round_helper.dart';

class RoundSelectionScreen extends StatelessWidget {
  /// Main‑season rounds: null (PS), 0–24
  final List<int?> rounds;

  /// Callback receives:
  ///   - null → Pre‑Season (PS)
  ///   - int  → R0–R24
  final void Function(int? round) onRoundSelected;

  /// Completed main‑season rounds only
  final Set<int> completedRounds;

  const RoundSelectionScreen({
    super.key,
    required this.rounds,
    required this.onRoundSelected,
    required this.completedRounds,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 DIAGNOSTIC PRINT — shows exactly what the UI is receiving
    print("🔥 RoundSelectionScreen received rounds → $rounds");

    // Build tokens directly from the rounds list
    final List<String> items = rounds.map(RoundHelper.toToken).toList();

    // 🔥 NEW DIAGNOSTIC
print("🔥 ITEMS LIST → $items");


    return Scaffold(
      appBar: AppBar(title: const Text("Select Round")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final token = items[i];
              final int? round = RoundHelper.fromToken(token);
              final bool isPreseason = RoundHelper.isPreseason(round);

              final bool isCompleted =
                  !isPreseason && completedRounds.contains(round);

              // 🔥 DIAGNOSTIC PRINT — shows exactly which tile is wrong
              print(
                "RoundSelectionScreen → token='$token'  parsedRound=$round  isPreseason=$isPreseason",
              );

              return GestureDetector(
                onTap: () {
                  onRoundSelected(round);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: isCompleted
                        ? Colors.grey.shade400
                        : Theme.of(context).colorScheme.surfaceVariant,
                    border: Border.all(
                      color: isCompleted
                          ? Colors.grey.shade600
                          : Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    RoundHelper.label(round),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? Colors.grey.shade800
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}