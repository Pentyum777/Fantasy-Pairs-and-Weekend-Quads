import 'package:flutter/material.dart';
import '../models/punter_selection.dart';
import '../constants/ui_dimensions.dart';
import 'shared_table_row.dart';

class LeaderboardTable extends StatelessWidget {
  final List<PunterSelection> punters;
  final double rowHeight;
  final double totalWidth;

  // ⭐ Shared scroll controller for horizontal sync
  final ScrollController? scrollController;

  const LeaderboardTable({
    super.key,
    required this.punters,
    required this.rowHeight,
    required this.totalWidth,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final sorted = [...punters]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Container(
      width: totalWidth,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(38), // dark tile
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300.withAlpha(153),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(46),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),

        // ⭐ Horizontal scroll wrapper (header + body)
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: scrollController,

          child: SizedBox(
            width: totalWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // -------------------------
                // HEADER
                // -------------------------
                SizedBox(
                  width: totalWidth,
                  height: UIDimensions.headerHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(64),
                      border: Border(
                        bottom: BorderSide(
                          color: cs.primary.withAlpha(31),
                          width: 0.75,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: UIDimensions.rankColumnWidth,
                          child: _headerCell(theme, "P", alignCenter: true),
                        ),
                        SizedBox(
                          width: UIDimensions.punterNameColumnWidth,
                          child: _headerCell(theme, "Punter", alignCenter: true),
                        ),
                        SizedBox(
                          width: UIDimensions.totalColumnWidth,
                          child: _headerCell(theme, "T", alignCenter: true),
                        ),
                      ],
                    ),
                  ),
                ),

                // -------------------------
                // BODY
                // -------------------------
                SizedBox(
                  height: rowHeight * sorted.length,
                  child: ListView.builder(
                    itemCount: sorted.length,
                    physics: const NeverScrollableScrollPhysics(), // ⭐ vertical only
                    itemBuilder: (context, index) {
                      final p = sorted[index];

                      return buildSharedTableRow(
                        context: context,
                        index: index,
                        rowHeight: rowHeight,
                        totalWidth: totalWidth,
                        isInvalid: false,
                        isHighlighted: p.isPrizeWinner,
                        leftCell: _rankCell(context, index),
                        middleCells: [_punterNameCell(context, p)],
                        rightCell: _scoreCell(context, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // CELL BUILDERS
  // -------------------------

  Widget _headerCell(
    ThemeData theme,
    String text, {
    bool alignCenter = false,
  }) {
    return Container(
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2),
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

  Widget _rankCell(BuildContext context, int index) {
    return Container(
      width: UIDimensions.rankColumnWidth,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        "${index + 1}",
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _punterNameCell(BuildContext context, PunterSelection p) {
    return Container(
      width: UIDimensions.punterNameColumnWidth,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        p.punterName,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _scoreCell(BuildContext context, PunterSelection p) {
    return Container(
      width: UIDimensions.totalColumnWidth,
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