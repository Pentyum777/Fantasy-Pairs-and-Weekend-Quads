import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/afl_club_codes.dart';
import '../theme/team_colours_by_club.dart';
import 'side_by_side_game_tables.dart';

class StatsOverlay extends StatefulWidget {
  final String leftTitle;
  final String rightTitle;

  /// Columns should be:
  /// ["Player","K","H","M","T","HO","FF","FA","G","B","TOG"]
  final List<String> columns;

  /// Returns the latest left/right rows. Called on first build and again
  /// every time [refreshTick] changes value.
  final ({List<Map<String, dynamic>> left, List<Map<String, dynamic>> right}) Function() buildRows;

  /// Bumped by the parent screen whenever stats are refreshed. The overlay
  /// listens to this and re-pulls rows via [buildRows].
  final ValueListenable<int>? refreshTick;

  final String? noStatsMessage;

  const StatsOverlay({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.columns,
    required this.buildRows,
    this.refreshTick,
    this.noStatsMessage,
  });

  @override
  State<StatsOverlay> createState() => _StatsOverlayState();
}

class _StatsOverlayState extends State<StatsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late List<Map<String, dynamic>> _leftRows;
  late List<Map<String, dynamic>> _rightRows;

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

    final initial = widget.buildRows();
    _leftRows = initial.left;
    _rightRows = initial.right;

    widget.refreshTick?.addListener(_onRefreshTick);
  }

  void _onRefreshTick() {
    if (!mounted) return;
    final fresh = widget.buildRows();
    setState(() {
      _leftRows = fresh.left;
      _rightRows = fresh.right;
    });
    _fadeController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant StatsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshTick != widget.refreshTick) {
      oldWidget.refreshTick?.removeListener(_onRefreshTick);
      widget.refreshTick?.addListener(_onRefreshTick);
    }
  }

  @override
  void dispose() {
    widget.refreshTick?.removeListener(_onRefreshTick);
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
              if (widget.noStatsMessage != null && _leftRows.isEmpty && _rightRows.isEmpty)
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
                                    _leftRows,
                                    widget.columns,
                                    compact: true,
                                    headerBg: _teamBg(leftCode),
                                    headerFg: _teamFg(leftCode),
                                    playerFormatter: _formatPlayerName,
                                    statColumnWidth: 32,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SideBySideGameTables.buildSingleTable(
                                    context,
                                    rightName,
                                    _rightRows,
                                    widget.columns,
                                    compact: true,
                                    headerBg: _teamBg(rightCode),
                                    headerFg: _teamFg(rightCode),
                                    playerFormatter: _formatPlayerName,
                                    statColumnWidth: 32,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                SideBySideGameTables.buildSingleTable(
                                  context,
                                  leftName,
                                  _leftRows,
                                  widget.columns,
                                  compact: true,
                                  headerBg: _teamBg(leftCode),
                                  headerFg: _teamFg(leftCode),
                                  playerFormatter: _formatPlayerName,
                                  statColumnWidth: 32,
                                ),
                                const SizedBox(height: 6),
                                SideBySideGameTables.buildSingleTable(
                                  context,
                                  rightName,
                                  _rightRows,
                                  widget.columns,
                                  compact: true,
                                  headerBg: _teamBg(rightCode),
                                  headerFg: _teamFg(rightCode),
                                  playerFormatter: _formatPlayerName,
                                  statColumnWidth: 32,
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

  /// Robust formatter: "<guernsey> <surname>"
  /// Falls back gracefully if fields are missing.
  String _formatPlayerName(Map<String, dynamic> row) {
  // Extract full name
  final fullName =
      (row["playerName"] ?? row["Player"] ?? row["name"] ?? "").toString().trim();

  // Extract guernsey
  final guernseyRaw =
      row["guernseyNumber"] ?? row["Guernsey"] ?? row["jumper"] ?? "";
  final guernsey = guernseyRaw.toString().trim();

  if (fullName.isEmpty) {
    return guernsey.isEmpty ? "" : guernsey;
  }

  // Split name
  final parts = fullName.split(RegExp(r"\s+"));
  final surname = parts.isNotEmpty ? parts.last : fullName;
  final firstName = parts.length > 1 ? parts.first : "";

  // Initial
  final initial = firstName.isNotEmpty ? "${firstName[0]}." : "";

  // Detect duplicate surnames across both tables
  final allRows = [..._leftRows, ..._rightRows];
  final surnameCount = allRows.where((r) {
    final n = (r["playerName"] ?? r["Player"] ?? r["name"] ?? "").toString();
    return n.trim().endsWith(" $surname");
  }).length;

  final needsInitial = surnameCount > 1;
  final displayName = needsInitial ? "$initial $surname" : surname;

  // Return a STRING — formatting happens in the table widget
  if (guernsey.isNotEmpty && guernsey != "0") {
    return "$guernsey $displayName";
  }

  return displayName;
}
    }