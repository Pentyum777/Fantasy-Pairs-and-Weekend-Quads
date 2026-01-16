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

  // Background striping + invalid highlight
  final Color bg = isInvalid
      ? Colors.red.withOpacity(0.06)
      : index.isOdd
          ? cs.surfaceVariant.withOpacity(0.25)
          : cs.surface;

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

    child: SizedBox(
      width: double.infinity,   // ensures full-width row
      height: rowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.max,   // correct pairing with infinity width
        children: [
          leftCell,
          ...middleCells,
          rightCell,
        ],
      ),
    ),
  );
}