import 'package:flutter/material.dart';
import '../constants/ui_dimensions.dart';
import '../models/punter_selection.dart';
import 'leaderboard_table.dart';

class LeaderboardPanel extends StatelessWidget {
  final List<PunterSelection> punters;
  final double rowHeight;
  final bool collapsed;
  final ScrollController? scrollController;
  final void Function(bool collapsed)? onCollapseChanged;

  const LeaderboardPanel({
    super.key,
    required this.punters,
    required this.rowHeight,
    required this.collapsed,
    this.scrollController,
    this.onCollapseChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const double collapsedWidth = 40.0;

    final double expandedWidth =
        UIDimensions.rankColumnWidth +
        UIDimensions.punterNameColumnWidth +
        UIDimensions.totalColumnWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: collapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(64),
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

        // ⭐ FIX: Leaderboard must fill available height so its ListView can scroll
        child: collapsed
            ? const SizedBox.shrink()
            : SizedBox.expand(
                child: LeaderboardTable(
                  punters: punters,
                  rowHeight: rowHeight,
                  totalWidth: expandedWidth,
                  scrollController: scrollController,
                ),
              ),
      ),
    );
  }
}