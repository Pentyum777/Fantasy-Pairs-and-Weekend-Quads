import 'package:flutter/material.dart';
import '../widgets/team_logo.dart';

class SingleTeamStatsTable extends StatefulWidget {
  final List<String> teamCodes;
  final Map<String, List<Map<String, dynamic>>> teamRows;
  final List<String> columns;

  const SingleTeamStatsTable({
    super.key,
    required this.teamCodes,
    required this.teamRows,
    required this.columns,
  });

  @override
  State<SingleTeamStatsTable> createState() => _SingleTeamStatsTableState();
}

class _SingleTeamStatsTableState extends State<SingleTeamStatsTable> {
  late String selectedTeam;

  static const double headerHeight = 40;
  static const double rowHeight = 32;

  @override
  void initState() {
    super.initState();
    selectedTeam = widget.teamCodes.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = widget.teamRows[selectedTeam] ?? [];

    return Column(
      children: [
        // -------------------------------------------------------------------
        // TEAM LOGO SWITCHER (tap to toggle between the two teams)
        // -------------------------------------------------------------------
        GestureDetector(
          onTap: () {
            final otherTeam =
                widget.teamCodes.firstWhere((t) => t != selectedTeam);
            setState(() => selectedTeam = otherTeam);
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 40,
              child: TeamLogo(
                selectedTeam,
                size: 40,
              ),
            ),
          ),
        ),

        // -------------------------------------------------------------------
        // TABLE CONTAINER
        // -------------------------------------------------------------------
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // -------------------------------------------------------------
              // TITLE HEADER (shows team code)
              // -------------------------------------------------------------
              Container(
                height: headerHeight,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                color: cs.surfaceVariant,
                child: Text(
                  selectedTeam,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),

              const Divider(height: 1),

              // -------------------------------------------------------------
              // COLUMN LABELS
              // -------------------------------------------------------------
              Container(
                height: headerHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: cs.surfaceVariant,
                child: Row(
                  children: widget.columns
                      .map(
                        (c) => Expanded(
                          child: Text(
                            c,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const Divider(height: 1),

              // -------------------------------------------------------------
              // DATA ROWS
              // -------------------------------------------------------------
              ...rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final isStriped = index.isOdd;

                return Container(
                  height: rowHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: isStriped
                      ? cs.surfaceVariant.withAlpha(76)
                      : cs.surface,
                  child: Row(
                    children: widget.columns
                        .map(
                          (c) => Expanded(
                            child: Text(
                              "${row[c]}",
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}