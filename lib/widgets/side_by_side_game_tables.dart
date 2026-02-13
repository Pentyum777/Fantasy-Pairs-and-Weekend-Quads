import 'package:flutter/material.dart';

class SideBySideGameTables extends StatelessWidget {
  final String leftTitle;
  final String rightTitle;
  final List<Map<String, dynamic>> leftRows;
  final List<Map<String, dynamic>> rightRows;

  /// Columns should be:
  /// ["Player","K","H","M","T","HO","FF","FA","G","B","TOG"]
  final List<String> columns;

  const SideBySideGameTables({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftRows,
    required this.rightRows,
    required this.columns,
  });

  static const double headerHeight = 32;
  static const double rowHeight = 26;
  static const double statColWidth = 40;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildTable(context, leftTitle, leftRows)),
        const SizedBox(width: 6),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: headerHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.centerLeft,
            color: cs.surfaceContainerHighest,
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: columns.map((c) {
                final isPlayer = c == "Player";
                return isPlayer
                    ? Expanded(
                        child: Text(
                          c,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : SizedBox(
                        width: statColWidth,
                        child: Text(
                          c,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isStriped = index.isOdd;

            return Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              color: isStriped
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.30)
                  : cs.surface,
              child: Row(
                children: columns.map((c) {
                  final isPlayer = c == "Player";
                  return isPlayer
                      ? Expanded(
                          child: Text(
                            "${row[c]}",
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        )
                      : SizedBox(
                          width: statColWidth,
                          child: Text(
                            "${row[c]}",
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Widget buildSingleTable(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> rows,
    List<String> columns, {
    bool compact = false,
    Color? headerBg,
    Color? headerFg,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final headerStyle = TextStyle(
      fontSize: compact ? 12 : 15,
      fontWeight: FontWeight.bold,
      color: headerFg ?? cs.onSurfaceVariant,
    );

    final cellStyle = TextStyle(
      fontSize: compact ? 11 : 13,
      height: 1.1,
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: compact ? 28 : headerHeight,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
            alignment: Alignment.centerLeft,
            color: headerBg ?? cs.surfaceContainerHighest,
            child: Text(title, style: headerStyle),
          ),
          const Divider(height: 1),
          Container(
            height: compact ? 26 : headerHeight,
            padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
            color: headerBg ?? cs.surfaceContainerHighest,
            child: Row(
              children: columns.map((c) {
                final isPlayer = c == "Player";
                return isPlayer
                    ? Expanded(
                        child: Text(
                          c,
                          style: headerStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : SizedBox(
                        width: statColWidth,
                        child: Text(
                          c,
                          style: headerStyle,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isStriped = index.isOdd;

            return Container(
              height: compact ? 24 : rowHeight,
              padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
              color: isStriped
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.30)
                  : cs.surface,
              child: Row(
                children: columns.map((c) {
                  final isPlayer = c == "Player";
                  return isPlayer
                      ? Expanded(
                          child: Text(
                            "${row[c]}",
                            style: cellStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        )
                      : SizedBox(
                          width: statColWidth,
                          child: Text(
                            "${row[c]}",
                            style: cellStyle,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
