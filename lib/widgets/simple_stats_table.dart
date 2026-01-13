import 'package:flutter/material.dart';

class SimpleStatsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> columns;

  const SimpleStatsTable({
    super.key,
    required this.rows,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: cs.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: columns
                  .map(
                    (col) => Expanded(
                      child: Text(
                        col,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isStriped = index.isOdd;

            return Container(
              height: 32,
              color: isStriped
                  ? cs.surfaceVariant.withAlpha(76)
                  : cs.surface,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: columns
                    .map(
                      (col) => Expanded(
                        child: Text(
                          "${row[col]}",
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}