import 'package:flutter/material.dart';

/// Shared table row builder used by both PunterSelectionTable and LeaderboardTable.
/// Ensures pixel‑perfect alignment across both tables.
Widget buildSharedTableRow({
  required BuildContext context,
  required int index,
  required double rowHeight,
  required Widget leftCell,
  required List<Widget> middleCells,
  required Widget rightCell,
  required bool isInvalid,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  // Striping logic (leaderboard ignores invalid tint)
  Color bg;
  if (isInvalid) {
    bg = Colors.red.withOpacity(0.06);
  } else if (index.isOdd) {
    bg = cs.surfaceVariant.withOpacity(0.25);
  } else {
    bg = cs.surface;
  }

  return Container(
    height: rowHeight,
    decoration: BoxDecoration(
      color: bg,
      border: Border(
        bottom: BorderSide(
          color: cs.outlineVariant.withOpacity(0.6),
          width: 0.5,
        ),
      ),
    ),

    // ⭐ FIX: Constrain width so the row cannot expand wider than the parent
    child: SizedBox(
      width: double.infinity,   // forces row to respect parent width
      height: rowHeight,
      child: Row(
        children: [
          leftCell,
          ...middleCells,
          rightCell,
        ],
      ),
    ),
  );
}