import 'package:flutter/material.dart';
import 'side_by_side_game_tables.dart';

class StatsOverlay extends StatelessWidget {
  final String leftTitle;
  final String rightTitle;
  final List<Map<String, dynamic>> leftRows;
  final List<Map<String, dynamic>> rightRows;
  final List<String> columns;

  /// Optional message when no stats exist.
  final String? noStatsMessage;

  const StatsOverlay({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftRows,
    required this.rightRows,
    required this.columns,
    this.noStatsMessage,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;

    // ------------------------------------------------------------
    // AUTO-DETECT EMPTY STATS
    // ------------------------------------------------------------
    final bool noStats =
        (leftRows.isEmpty && rightRows.isEmpty);

    final String message =
        noStatsMessage ?? "No stats available for this match.";

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 900 : size.width * 0.95,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header row with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Match Stats",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------------------
              // EMPTY STATE
              // ------------------------------------------------------------
              if (noStats)
                Expanded(
                  child: Center(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                )

              // ------------------------------------------------------------
              // NORMAL TABLE RENDERING
              // ------------------------------------------------------------
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SideBySideGameTables.buildSingleTable(
                                  context,
                                  leftTitle,
                                  leftRows,
                                  columns,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SideBySideGameTables.buildSingleTable(
                                  context,
                                  rightTitle,
                                  rightRows,
                                  columns,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              SideBySideGameTables.buildSingleTable(
                                context,
                                leftTitle,
                                leftRows,
                                columns,
                              ),
                              const SizedBox(height: 16),
                              SideBySideGameTables.buildSingleTable(
                                context,
                                rightTitle,
                                rightRows,
                                columns,
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}