import 'package:flutter/material.dart';
import '../utils/afl_club_codes.dart';
import '../theme/team_colours_by_club.dart';
import 'side_by_side_game_tables.dart';

class StatsOverlay extends StatefulWidget {
  final String leftTitle;
  final String rightTitle;

  final List<Map<String, dynamic>> leftRows;
  final List<Map<String, dynamic>> rightRows;

  /// Columns should be:
  /// ["Player","K","H","M","T","HO","FF","FA","G","B","TOG"]
  final List<String> columns;

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
  State<StatsOverlay> createState() => _StatsOverlayState();
}

class _StatsOverlayState extends State<StatsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>>? _prevLeftRows;
  List<Map<String, dynamic>>? _prevRightRows;

  static const Map<String, String> shortTeamNames = {
    "ADE": "Adelaide",
    "BRL": "Brisbane",
    "CAR": "Carlton",
    "COL": "Collingwood",
    "ESS": "Essendon",
    "FRE": "Fremantle",
    "GEE": "Geelong",
    "GCS": "Gold Coast",
    "GWS": "GWS",
    "HAW": "Hawthorn",
    "MELB": "Melbourne",
    "NTH": "North Melbourne",
    "PTA": "Port Adelaide",
    "RIC": "Richmond",
    "STK": "St Kilda",
    "SYD": "Sydney",
    "WCE": "West Coast",
    "WBD": "Western Bulldogs",
  };

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
  }

  @override
  void didUpdateWidget(covariant StatsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final leftChanged = widget.leftRows != _prevLeftRows;
    final rightChanged = widget.rightRows != _prevRightRows;

    if (leftChanged || rightChanged) {
      _fadeController.forward(from: 0);
    }

    _prevLeftRows = widget.leftRows;
    _prevRightRows = widget.rightRows;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color _teamBg(String code) =>
      TeamColoursByClub.colours[code]?["bg"] ?? Colors.grey.shade800;

  Color _teamFg(String code) =>
      TeamColoursByClub.colours[code]?["fg"] ?? Colors.white;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;

    final leftCode = AflClubCodes.normalize(widget.leftTitle);
    final rightCode = AflClubCodes.normalize(widget.rightTitle);

    final leftName = shortTeamNames[leftCode] ?? leftCode;
    final rightName = shortTeamNames[rightCode] ?? rightCode;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 1200 : size.width * 1.00,
          maxHeight: size.height * 0.96,
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Match Stats",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              if (widget.noStatsMessage != null)
                Expanded(
                  child: Center(
                    child: Text(
                      widget.noStatsMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SideBySideGameTables.buildSingleTable(
                                    context,
                                    leftName,
                                    widget.leftRows,
                                    widget.columns,
                                    compact: true,
                                    headerBg: _teamBg(leftCode),
                                    headerFg: _teamFg(leftCode),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SideBySideGameTables.buildSingleTable(
                                    context,
                                    rightName,
                                    widget.rightRows,
                                    widget.columns,
                                    compact: true,
                                    headerBg: _teamBg(rightCode),
                                    headerFg: _teamFg(rightCode),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                SideBySideGameTables.buildSingleTable(
                                  context,
                                  leftName,
                                  widget.leftRows,
                                  widget.columns,
                                  compact: true,
                                  headerBg: _teamBg(leftCode),
                                  headerFg: _teamFg(leftCode),
                                ),
                                const SizedBox(height: 6),
                                SideBySideGameTables.buildSingleTable(
                                  context,
                                  rightName,
                                  widget.rightRows,
                                  widget.columns,
                                  compact: true,
                                  headerBg: _teamBg(rightCode),
                                  headerFg: _teamFg(rightCode),
                                ),
                              ],
                            ),
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