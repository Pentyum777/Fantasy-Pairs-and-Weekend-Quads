import 'package:flutter/material.dart';
import '../constants/ui_dimensions.dart';
import '../models/punter_selection.dart';
import 'leaderboard_table.dart';

class LeaderboardPanel extends StatefulWidget {
  final List<PunterSelection> punters;
  final double rowHeight;
  final void Function(bool collapsed)? onCollapseChanged;

  const LeaderboardPanel({
    super.key,
    required this.punters,
    required this.rowHeight,
    this.onCollapseChanged,
  });


  @override
  State<LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<LeaderboardPanel> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Width when collapsed (just the toggle button)
    const double collapsedWidth = 32.0;

    // Width when expanded (compact leaderboard width)
    final double expandedWidth =
        UIDimensions.rankColumnWidth +
        UIDimensions.punterNameColumnWidth +
        UIDimensions.totalColumnWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _collapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.6),
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
            // COLLAPSE BUTTON ABOVE THE TABLE
            Container(
              height: 32,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: Icon(
                  _collapsed ? Icons.chevron_right : Icons.chevron_left,
                  color: cs.primary,
                ),
                onPressed: () {
  setState(() => _collapsed = !_collapsed);
  widget.onCollapseChanged?.call(_collapsed);
},
              ),
            ),

            // LEADERBOARD TABLE (perfectly aligned with punter table)
            if (!_collapsed)
              Expanded(
                child: LeaderboardTable(
                  punters: widget.punters,
                  rowHeight: widget.rowHeight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}