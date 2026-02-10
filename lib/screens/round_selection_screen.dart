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
    final items = rounds.map(RoundHelper.toToken).toList();

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
              final round = RoundHelper.fromToken(token);

              // ⭐ Null‑safe: only real rounds can be completed
              final isCompleted =
                  round != null && completedRounds.contains(round);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onRoundSelected(round),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isCompleted
                          ? Colors.grey.shade300
                          : Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: isCompleted
                            ? Colors.grey.shade500
                            : Theme.of(context).colorScheme.primary,
                        width: 1.6,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        RoundHelper.label(round),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isCompleted
                              ? Colors.grey.shade700
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
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