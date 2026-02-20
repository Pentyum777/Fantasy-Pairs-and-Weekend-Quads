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

    // ⭐ FIX: Give the body a concrete height so it always renders
    final double bodyHeight = rowHeight * sorted.length;

    return Container(
      width: totalWidth,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(64),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),

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
                      color: cs.surfaceContainerHighest.withAlpha(96),
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
                // BODY (fixed height)
                // -------------------------
                SizedBox(
                  height: bodyHeight,
                  child: ListView.builder(
                    itemCount: sorted.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final p = sorted[index];

                      return Container(
                        height: rowHeight,
                        color: cs.surfaceContainerHighest.withAlpha(
                          index.isEven ? 32 : 20,
                        ),
                        child: buildSharedTableRow(
                          context: context,
                          index: index,
                          rowHeight: rowHeight,
                          totalWidth: totalWidth,
                          isInvalid: false,
                          isHighlighted: p.isPrizeWinner,
                          leftCell: _rankCell(context, index),
                          middleCells: [_punterNameCell(context, p)],
                          rightCell: _scoreCell(context, p),
                        ),
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