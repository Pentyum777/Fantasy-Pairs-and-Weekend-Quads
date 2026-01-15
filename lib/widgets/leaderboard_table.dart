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
            // Header
            Container(
              height: 40,
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
                  _headerCell(theme, "Rank", 50, alignCenter: true),
                  _headerCell(theme, "Punter", 140),
                  _headerCell(theme, "Total", 60, alignCenter: true),
                ],
              ),
            ),

            // Rows
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

  Widget _headerCell(ThemeData theme, String text, double width,
      {bool alignCenter = false}) {
    return Container(
      width: width,
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _rankCell(BuildContext context, int index) {
    return Container(
      width: 50,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        "${index + 1}",
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _punterNameCell(BuildContext context, PunterSelection p) {
    return Container(
      width: 140,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        p.punterName,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _scoreCell(BuildContext context, PunterSelection p) {
    return Container(
      width: 60,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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