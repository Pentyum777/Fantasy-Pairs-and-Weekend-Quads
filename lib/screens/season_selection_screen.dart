import 'package:flutter/material.dart';

class SeasonSelectionScreen extends StatelessWidget {
  final List<int> seasons;
  final void Function(int season) onSelect;

  const SeasonSelectionScreen({
    super.key,
    required this.seasons,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Season"),
        centerTitle: true,
      ),
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
              childAspectRatio: 4.2,
            ),
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),

                  onTap: () {
                    print("🟥 DEBUG: Season tile tapped → $season");

                    try {
                      print("🟥 DEBUG: Calling onSelect($season)...");
                      onSelect(season);
                      print("🟥 DEBUG: onSelect($season) completed without throwing.");
                    } catch (e, st) {
                      print("🟥 ERROR inside onSelect($season) → $e");
                      print(st);
                    }
                  },

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "$season",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
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
