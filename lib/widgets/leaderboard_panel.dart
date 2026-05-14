import 'package:flutter/material.dart';
import '../constants/ui_dimensions.dart';
import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import 'leaderboard_table.dart';

class LeaderboardPanel extends StatelessWidget {
  final List<PunterSelection> punters;
  final double rowHeight;
  final bool collapsed;
  final ScrollController? scrollController;
  final void Function(bool collapsed)? onCollapseChanged;
  final bool showAveragePreview;
  final List<AflPlayer> allPlayers;

  const LeaderboardPanel({
    super.key,
    required this.punters,
    required this.rowHeight,
    required this.collapsed,
    this.scrollController,
    this.onCollapseChanged,
    this.showAveragePreview = false,
    this.allPlayers = const [],
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
        color: theme.colorScheme.surfaceVariant.withAlpha(64),
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

        child: collapsed
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  SizedBox(
                    height: UIDimensions.headerHeight,
                    width: expandedWidth,
                    child: LeaderboardTable(
                      punters: punters,
                      rowHeight: rowHeight,
                      totalWidth: expandedWidth,
                      scrollController: scrollController,
                      showAveragePreview: showAveragePreview,
                      allPlayers: allPlayers,
                    ).buildHeader(context),
                  ),

                  const Divider(height: 1),

                  // BODY WITH SHADING
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: punters.length,
                      itemBuilder: (context, index) {
                        final p = punters[index];

                        final bool isCompleted = p.isCompletedPunter;

                        final Color bg = isCompleted
                            ? const Color.fromARGB(255, 82, 81, 81)
                                .withOpacity(0.80)
                            : (index.isOdd
                                ? theme.colorScheme.surfaceVariant.withAlpha(64)
                                : theme.colorScheme.surface);

                        return Container(
                          height: rowHeight,
                          color: bg,

                          // ⭐ Pass white text override to LeaderboardTable
                          child: LeaderboardTable(
                            punters: punters,
                            rowHeight: rowHeight,
                            totalWidth: expandedWidth,
                            scrollController: scrollController,
                            textColorOverride:
                                isCompleted ? Colors.white : null,
                            showAveragePreview: showAveragePreview,
                            allPlayers: allPlayers,
                          ).buildBodyRow(context, index),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}