import 'package:flutter/material.dart';

class RoundSelectionScreen extends StatelessWidget {
  final List<int> rounds;
  final void Function(int? round) onRoundSelected;

  /// NEW: pass in completed rounds
  final Set<int> completedRounds;

  const RoundSelectionScreen({
    super.key,
    required this.rounds,
    required this.onRoundSelected,
    required this.completedRounds,   // <-- NEW
  });

  @override
  Widget build(BuildContext context) {
    final items = rounds.map((r) => "R$r").toList();

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
              final round = int.parse(label.substring(1));

              final isCompleted = completedRounds.contains(round);

              return GestureDetector(
                onTap: () => onRoundSelected(round),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: isCompleted
                        ? Colors.grey.shade400        // <-- greyed out
                        : Theme.of(context)
                            .colorScheme
                            .surfaceVariant,
                    border: Border.all(
                      color: isCompleted
                          ? Colors.grey.shade600
                          : Theme.of(context)
                              .colorScheme
                              .primary,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    label,
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