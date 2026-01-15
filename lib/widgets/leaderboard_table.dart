import 'package:flutter/material.dart';
import '../models/punter_selection.dart';
import 'shared_table_row.dart';

class LeaderboardTable extends StatelessWidget {
  final List<PunterSelection> punters;
  final double rowHeight;

  const LeaderboardTable({
    super.key,
    required this.punters,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final sorted = [...punters]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Container(
      width: 32 + 70 + 36, // total compact width
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // HEADER
            Container(
              height: 26,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                border: Border(
                  bottom: BorderSide(
                    color: cs.primary.withOpacity(0.12),
                    width: 0.75,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _headerCell(theme, "P", 32, alignCenter: true),
                  _headerCell(theme, "Punter", 70, alignCenter: true),
                  _headerCell(theme, "T", 36, alignCenter: true),
                ],
              ),
            ),

            // ROWS
            Expanded(
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final p = sorted[index];
                  final isWinner = p.isPrizeWinner;

                  return Container(
                    color: isWinner
                        ? Colors.orange.withOpacity(0.25)
                        : Colors.transparent,
                    child: buildSharedTableRow(
                      context: context,
                      index: index,
                      rowHeight: rowHeight,
                      isInvalid: false,
                      leftCell: _rankCell(context, index),
                      middleCells: [
                        _punterNameCell(context, p),
                      ],
                      rightCell: _scoreCell(context, p),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER CELL
  // ---------------------------------------------------------------------------
  Widget _headerCell(
    ThemeData theme,
    String text,
    double width, {
    bool alignCenter = false,
  }) {
    return Container(
      width: width,
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POSITION CELL (P)
  // ---------------------------------------------------------------------------
  Widget _rankCell(BuildContext context, int index) {
    return Container(
      width: 32,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        "${index + 1}",
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PUNTER NAME CELL (LEFT‑ALIGNED)
  // ---------------------------------------------------------------------------
  Widget _punterNameCell(BuildContext context, PunterSelection p) {
    return Container(
      width: 70,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        p.punterName,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCORE CELL (T)
  // ---------------------------------------------------------------------------
  Widget _scoreCell(BuildContext context, PunterSelection p) {
    return Container(
      width: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        p.totalScore.toString(),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}