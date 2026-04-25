import 'package:flutter/material.dart';

class SideBySideGameTables extends StatelessWidget {
  final String leftTitle;
  final String rightTitle;
  final List<Map<String, dynamic>> leftRows;
  final List<Map<String, dynamic>> rightRows;

  /// Columns should be:
  /// ["Player","K","H","M","T","HO","FF","FA","G","B","TOG"]
  final List<String> columns;

  /// Optional formatter for player name (returns a STRING)
  final String Function(Map<String, dynamic>)? playerFormatter;

  /// Optional stat column width override
  final double statColumnWidth;

  const SideBySideGameTables({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftRows,
    required this.rightRows,
    required this.columns,
    this.playerFormatter,
    this.statColumnWidth = 32,
  });

  static const double headerHeight = 32;
  static const double rowHeight = 26;

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
          // Team header
          Container(
            height: headerHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 2),
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

          // Column headers
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            color: cs.surfaceVariant,
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
                        width: statColumnWidth,
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

          // Data rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isStriped = index.isOdd;

            return Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              color: isStriped
                  ? cs.surfaceVariant.withAlpha(76)
                  : cs.surface,
              child: Row(
                children: columns.map((c) {
                  final isPlayer = c == "Player";

                  if (isPlayer) {
                    final raw = playerFormatter != null
                        ? playerFormatter!(row)
                        : "${row[c]}";

                    final parts = raw.split(" ");
                    final hasGuernsey =
                        parts.isNotEmpty && int.tryParse(parts.first) != null;

                    return Expanded(
                      child: hasGuernsey
                          ? Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: "${parts.first} ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: parts.skip(1).join(" "),
                                  ),
                                ],
                              ),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            )
                          : Text(
                              raw,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                    );
                  }

                  return SizedBox(
                    width: statColumnWidth,
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

  // ---------------------------------------------------------------------------
  // STATIC VERSION USED BY StatsOverlay
  // ---------------------------------------------------------------------------

  static Widget buildSingleTable(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> rows,
    List<String> columns, {
    bool compact = false,
    Color? headerBg,
    Color? headerFg,

    /// NEW
    String Function(Map<String, dynamic>)? playerFormatter,

    /// NEW
    double statColumnWidth = 32,

    /// Optional per-cell highlight colours, keyed by playerId then column.
    /// Used for live-update flashes (green = increased, red = decreased).
    Map<String, Map<String, Color>>? cellHighlights,
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
          // Team header
          Container(
            height: compact ? 28 : headerHeight,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
            alignment: Alignment.centerLeft,
            color: headerBg ?? cs.surfaceVariant,
            child: Text(title, style: headerStyle),
          ),

          const Divider(height: 1),

          // Column headers
          Container(
            height: compact ? 26 : headerHeight,
            padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
            color: headerBg ?? cs.surfaceVariant,
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
                        width: statColumnWidth,
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

          // Data rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isStriped = index.isOdd;

            return Container(
              height: compact ? 24 : rowHeight,
              padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
              color: isStriped
                  ? cs.surfaceVariant.withAlpha(76)
                  : cs.surface,
              child: Row(
                children: columns.map((c) {
                  final isPlayer = c == "Player";

                  if (isPlayer) {
  final display = playerFormatter != null
      ? playerFormatter(row)
      : "${row[c]}";

  // Split into guernsey + name
  final parts = display.split(" ");
  final hasGuernsey = parts.isNotEmpty && int.tryParse(parts.first) != null;

  if (hasGuernsey) {
    final guernsey = parts.first;              // no !
    final name = parts.skip(1).join(" ");      // no !

    return Expanded(
      child: Row(
        children: [
          // ⭐ Fixed-width guernsey box for perfect alignment
          SizedBox(
            width: 26,
            child: Text(
              guernsey,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          const SizedBox(width: 4),

          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Fallback: no guernsey
  return Expanded(
    child: Text(
      display,
      style: theme.textTheme.bodySmall,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );
}



                  final highlight = cellHighlights?[row["playerId"]?.toString() ?? ""]?[c];
                  return Container(
                    width: statColumnWidth,
                    decoration: highlight != null
                        ? BoxDecoration(
                            color: highlight,
                            borderRadius: BorderRadius.circular(3),
                          )
                        : null,
                    alignment: Alignment.center,
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