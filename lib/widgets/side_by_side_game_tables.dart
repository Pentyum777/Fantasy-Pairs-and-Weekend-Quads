import 'package:flutter/material.dart';

class SideBySideGameTables extends StatelessWidget {
  final String leftTitle;
  final String rightTitle;
  final List<Map<String, dynamic>> leftRows;
  final List<Map<String, dynamic>> rightRows;
  final List<String> columns;

  const SideBySideGameTables({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftRows,
    required this.rightRows,
    required this.columns,
  });

  static const double headerHeight = 40;
  static const double rowHeight = 32;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildTable(context, leftTitle, leftRows)),
        const SizedBox(width: 12),
        Expanded(child: _buildTable(context, rightTitle, rightRows)),
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> rows,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Title header
          Container(
            height: headerHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            color: cs.surfaceVariant,
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),

          const Divider(height: 1),

          // Column labels
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: cs.surfaceVariant,
            child: Row(
              children: columns
                  .map(
                    (c) => Expanded(
                      child: Text(
                        c,
                        style: theme.textTheme.labelSmall?.copyWith(
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

          // Data rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isStriped = index.isOdd;

            return Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: isStriped
                  ? cs.surfaceVariant.withAlpha(76)
                  : cs.surface,
              child: Row(
                children: columns
                    .map(
                      (c) => Expanded(
                        child: Text(
                          "${row[c]}",
                          style: theme.textTheme.bodySmall,
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