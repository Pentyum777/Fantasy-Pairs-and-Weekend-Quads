import 'package:flutter/material.dart';

/// Shared table row builder that guarantees identical column structure
/// between header rows and body rows.
///
/// IMPORTANT:
/// - leftCell must be a SizedBox(width: punterWidth)
/// - middleCells must contain alternating:
///     Expanded(child: pickCell)
///     SizedBox(width: scoreWidth, child: scoreCell)
/// - rightCell must be a SizedBox(width: totalWidth)
///
/// This ensures perfect alignment with the header row.
Widget buildSharedTableRow({
  required BuildContext context,
  required int index,
  required double rowHeight,
  required double totalWidth,
  required Widget leftCell,
  required List<Widget> middleCells,
  required Widget rightCell,
  required bool isInvalid,
  bool isHighlighted = false,
}) {
  final cs = Theme.of(context).colorScheme;

  final Color bg = isHighlighted
      ? Colors.amber.withAlpha(38)                     // 0.15 opacity
      : index.isOdd
          ? cs.surfaceContainerHighest.withAlpha(64)   // 0.25 opacity
          : cs.surface;

  return SizedBox(
    width: totalWidth,
    height: rowHeight,
    child: Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withAlpha(153),   // 0.6 opacity
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// FIXED-WIDTH LEFT COLUMN (Punter)
          leftCell,

          /// MIDDLE COLUMNS (Pick + Score pairs)
          ...middleCells,

          /// FIXED-WIDTH RIGHT COLUMN (Total)
          rightCell,
        ],
      ),
    ),
  );
}