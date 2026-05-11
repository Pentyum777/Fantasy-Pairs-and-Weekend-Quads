import 'dart:async';
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

  /// playerId → (column → highlight colour). Cleared after a short delay.
  Map<String, Map<String, Color>> _leftHighlights = {};
  Map<String, Map<String, Color>> _rightHighlights = {};
  Timer? _highlightTimer;

  /// Stat columns that should never flash — non-numeric or always-changing.
  static const _noFlashCols = {"Player", "playerId", "playerName", "team", "guernsey"};

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
    final newLeftHL = _diffRows(_leftRows, fresh.left);
    final newRightHL = _diffRows(_rightRows, fresh.right);

    setState(() {
      _leftRows = fresh.left;
      _rightRows = fresh.right;
      // Merge new highlights with any still-active ones (last write wins per cell)
      newLeftHL.forEach((pid, cols) {
        _leftHighlights.putIfAbsent(pid, () => {}).addAll(cols);
      });
      newRightHL.forEach((pid, cols) {
        _rightHighlights.putIfAbsent(pid, () => {}).addAll(cols);
      });
    });

    // Clear highlights after 1.5s
    if (newLeftHL.isNotEmpty || newRightHL.isNotEmpty) {
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _leftHighlights = {};
          _rightHighlights = {};
        });
      });
    }
  }

  /// Returns highlight map for changed numeric cells.
  /// Green = increase, red = decrease.
  Map<String, Map<String, Color>> _diffRows(
    List<Map<String, dynamic>> oldRows,
    List<Map<String, dynamic>> newRows,
  ) {
    final result = <String, Map<String, Color>>{};
    final oldById = {
      for (final r in oldRows)
        if (r["playerId"] != null) r["playerId"].toString(): r,
    };

    for (final row in newRows) {
      final pid = row["playerId"]?.toString();
      if (pid == null) continue;
      final oldRow = oldById[pid];
      if (oldRow == null) continue;

      for (final entry in row.entries) {
        if (_noFlashCols.contains(entry.key)) continue;
        final newVal = entry.value;
        final oldVal = oldRow[entry.key];
        if (newVal is! num || oldVal is! num) continue;
        if (newVal == oldVal) continue;

        final colour = newVal > oldVal
            ? Colors.green.withOpacity(0.45)
            : Colors.red.withOpacity(0.45);
        result.putIfAbsent(pid, () => {})[entry.key] = colour;
      }
    }
    return result;
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
    _highlightTimer?.cancel();
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
    // Side-by-side only on tablets and desktops (width >= 900)
    // Phones in landscape (~700px) still stack vertically
    final isWide = size.width >= 900;
    // Narrower stat columns on small screens
    final statWidth = size.width < 600 ? 24.0 : 32.0;

    final leftCode = AflClubCodes.normalize(widget.leftTitle);
    final rightCode = AflClubCodes.normalize(widget.rightTitle);

    final leftName = shortTeamNames[leftCode] ?? leftCode;
    final rightName = shortTeamNames[rightCode] ?? rightCode;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 600 ? 2 : 6,
        vertical: size.width < 600 ? 4 : 8,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 1200 : size.width * 1.00,
          maxHeight: size.height * 0.96,
        ),
        child: Padding(
          padding: EdgeInsets.all(size.width < 600 ? 2 : 3),
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
                                    statColumnWidth: statWidth,
                                    cellHighlights: _leftHighlights,
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
                                    statColumnWidth: statWidth,
                                    cellHighlights: _rightHighlights,
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
                                  statColumnWidth: statWidth,
                                  cellHighlights: _leftHighlights,
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
                                  statColumnWidth: statWidth,
                                  cellHighlights: _rightHighlights,
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