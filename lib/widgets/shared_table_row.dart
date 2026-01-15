import 'package:flutter/material.dart';

Widget buildSharedTableRow({
  required BuildContext context,
  required int index,
  required double rowHeight,
  required Widget leftCell,
  required List<Widget> middleCells,
  required Widget rightCell,
  required bool isInvalid,
}) {
  final cs = Theme.of(context).colorScheme;

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

    // ⭐ THIS IS THE FIX ⭐
    child: SizedBox(
      width: double.infinity, // forces row to respect parent width
      height: rowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min, // prevents expansion
        children: [
          leftCell,
          ...middleCells,
          rightCell,
        ],
      ),
    ),
  );
}