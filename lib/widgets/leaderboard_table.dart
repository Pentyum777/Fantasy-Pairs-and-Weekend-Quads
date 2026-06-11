import 'package:flutter/material.dart';
import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import '../constants/ui_dimensions.dart';

class LeaderboardTable extends StatelessWidget {
  final List<PunterSelection> punters;
  final double rowHeight;
  final double totalWidth;
  final ScrollController? scrollController;

  // ⭐ NEW — allows LeaderboardPanel to override text color
  final Color? textColorOverride;

  final bool showAveragePreview;
  final List<AflPlayer> allPlayers;

  const LeaderboardTable({
    super.key,
    required this.punters,
    required this.rowHeight,
    required this.totalWidth,
    this.scrollController,
    this.textColorOverride,
    this.showAveragePreview = false,
    this.allPlayers = const [],
  });

  // ⭐ REQUIRED — this is what your file was missing
  @override
  Widget build(BuildContext context) {
    // This widget does not render anything directly.
    // LeaderboardPanel calls buildHeader() and buildBodyRow().
    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: totalWidth,
      height: UIDimensions.headerHeight,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withAlpha(96),
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
    );
  }

  // ---------------------------------------------------------------------------
  // BODY ROW (used by LeaderboardPanel)
  // ---------------------------------------------------------------------------
  Widget buildBodyRow(BuildContext context, int index) {
    final p = punters[index];

    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          _rankCell(context, index),
          _punterNameCell(context, p),
          _scoreCell(context, p),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CELL BUILDERS
  // ---------------------------------------------------------------------------

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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }

  Widget _punterNameCell(BuildContext context, PunterSelection p) {
    final color = textColorOverride ??
        Theme.of(context).textTheme.bodySmall?.color;

    return Container(
      width: UIDimensions.punterNameColumnWidth,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        p.punterName,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
            ),
      ),
    );
  }

  Widget _scoreCell(BuildContext context, PunterSelection p) {
    final isAvg = showAveragePreview;
    final score = isAvg
        ? p.avgScore(allPlayers)
        : (p.picks.isEmpty ? p.liveScore : p.totalScore);

    final color = isAvg ? Colors.black : (textColorOverride ?? Theme.of(context).textTheme.bodySmall?.color);

    return Container(
      width: UIDimensions.totalColumnWidth,
      alignment: Alignment.center,
      padding: EdgeInsets.zero,
      child: Container(
        padding: isAvg
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
            : EdgeInsets.zero,
        decoration: isAvg
            ? BoxDecoration(
                color: Colors.orange.shade400.withOpacity(0.70),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Text(
          score.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}