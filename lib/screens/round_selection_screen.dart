import 'package:flutter/material.dart';

class RoundSelectionScreen extends StatelessWidget {
  /// Main‑season rounds: 0–24
  final List<int> rounds;

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
    // Build identifiers: PS + R0–R24
    final List<String> items = [];

    // Always show Pre‑Season first if any preseason fixtures exist
    items.add("PS");

    // Add main‑season rounds as R0, R1, ..., R24
    items.addAll(rounds.map((r) => "R$r"));

    return Scaffold(
      appBar: AppBar(title: const Text("Select")),
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
              final label = items[i];

              final bool isPreseason = label == "PS";

              // For PS, round = null
              final int? round =
                  isPreseason ? null : int.parse(label.substring(1));

              final bool isCompleted =
                  !isPreseason && completedRounds.contains(round);

              return GestureDetector(
                onTap: () => onRoundSelected(round),
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
                    isPreseason ? "Pre‑Season" : label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? Colors.grey.shade800
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
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