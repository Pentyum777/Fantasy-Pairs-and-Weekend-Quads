import 'package:flutter/material.dart';
import '../helpers/round_helper.dart';

class RoundSelectionScreen extends StatelessWidget {
  final List<int?> rounds;
  final void Function(int? round) onRoundSelected;
  final Set<int> completedRounds;

  const RoundSelectionScreen({
    super.key,
    required this.rounds,
    required this.onRoundSelected,
    required this.completedRounds,
  });

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
  }

  Widget buildProTile({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    bool completed = false,
  }) {
    final bool mobile = isPortraitPhone(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mobile ? 14 : 20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: mobile ? 8 : 10,
            horizontal: mobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mobile ? 14 : 20),

            // ⭐ Correct alpha handling (non‑deprecated)
            color: completed
                ? Colors.grey.shade700.withAlpha(64)   // 0.25 opacity
                : Colors.grey.shade900.withAlpha(38),  // 0.15 opacity

            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(46),      // 0.18 opacity
                blurRadius: mobile ? 4 : 6,
                offset: const Offset(0, 3),
              ),
            ],

            border: Border.all(
              color: completed
                  ? Colors.grey.shade500
                  : Colors.grey.shade300.withAlpha(153), // 0.6 opacity
              width: mobile ? 1.1 : 1.6,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: mobile ? 11 : 15,
                color: completed
                    ? Colors.grey.shade300
                    : Colors.grey.shade100,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = isPortraitPhone(context);
    final items = rounds.map(RoundHelper.toToken).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Select Round"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mobile ? 3 : 5,
              mainAxisSpacing: mobile ? 10 : 12,
              crossAxisSpacing: mobile ? 10 : 12,
              childAspectRatio: mobile ? 2.0 : 2.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final token = items[i];
              final round = RoundHelper.fromToken(token);

              final isCompleted =
                  round != null && completedRounds.contains(round);

              return buildProTile(
                context: context,
                label: RoundHelper.label(round),
                completed: isCompleted,
                onTap: () => onRoundSelected(round),
              );
            },
          ),
        ),
      ),
    );
  }
}