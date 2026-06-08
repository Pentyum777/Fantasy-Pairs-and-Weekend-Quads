// ignore_for_file: unused_element



import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';


import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../models/afl_player_match_stats.dart';
import '../services/punter_score_service.dart';
import '../services/user_role_service.dart';
import '../theme/team_colours_by_club.dart';
import '../constants/ui_dimensions.dart';

// ---------------------------------------------------------------------------
// MAIN WIDGET
// ---------------------------------------------------------------------------

class PunterSelectionTable extends StatefulWidget {
  final double? tableWidth;

  final int visiblePunterCount;
  final int playersPerPunter;
  final List<AflPlayer> availablePlayers;
  final List<PunterSelection> selections;
  final bool isCompleted;
  final bool readOnly;
  final bool collapsed;
  final ScrollController? scrollController;
  final bool Function(AflPlayerMatchStats stats) isPlayerCompleted;

  final String gameType;
  final int season;
  final int round;

  final void Function()? onChanged;
  final void Function(String time)? onTimestampChanged;
  final VoidCallback? onLiveScoreUpdateSave;

  final UserRoleService userRoleService;
  final PunterScoreService fantasyService;
  final List<String> knownPunterNames;
  final bool showAveragePreview;
  final List<AflPlayer> allPlayers;

  const PunterSelectionTable({
    super.key,
    required this.gameType,
    required this.season,
    required this.round,
    required this.tableWidth,
    required this.visiblePunterCount,
    required this.playersPerPunter,
    required this.availablePlayers,
    required this.selections,
    required this.isCompleted,
    required this.isPlayerCompleted,

    required this.readOnly,
    required this.collapsed,
    required this.scrollController,
    required this.userRoleService,
    required this.fantasyService,
    this.knownPunterNames = const [],
    this.showAveragePreview = false,
    this.allPlayers = const [],
    this.onChanged,
    this.onTimestampChanged,
    this.onLiveScoreUpdateSave,
  });

  @override
  State<PunterSelectionTable> createState() => _PunterSelectionTableState();
}

// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------

class _PunterSelectionTableState extends State<PunterSelectionTable> {
  final ScrollController _verticalController = ScrollController();
final ScrollController _horizontalController = ScrollController();

  bool get isLandscapePhone {
    final size = MediaQuery.of(context).size;
    return size.width > size.height && size.width < 900;
  }

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
  }

  int get _punterCount => widget.visiblePunterCount;

  // Responsive column widths
  double get kPunterColumnWidth {
    if (isPortraitPhone(context)) return 70;
    if (isLandscapePhone) return 80;
    return 90;
  }

  double get kPickColumnWidth {
    if (isPortraitPhone(context)) return 280;
    if (isLandscapePhone) return 300;
    return 160;
  }

  double get kPickScoreColumnWidth {
    if (isPortraitPhone(context)) return 26;
    if (isLandscapePhone) return 30;
    return 36;
  }

  double get kTotalColumnWidth {
    if (isPortraitPhone(context)) return 40;
    if (isLandscapePhone) return 45;
    return 55;
  }

  double _minTableWidth(int pickCount) {
    return kPunterColumnWidth +
        pickCount * (kPickColumnWidth + kPickScoreColumnWidth) +
        kTotalColumnWidth;
  }

  // Focus + Controllers
  final Map<String, FocusNode> _pickFocusNodes = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _punterFocusNodes = {};
  
  final Map<String, FocusNode> _searchFocusNodes = {};

  int? _lastUpdated;

  String get lastUpdatedLabel {
    if (_lastUpdated == null) return "Never";

    final dt = DateTime.fromMillisecondsSinceEpoch(_lastUpdated!);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');

    return "$hh:$mm:$ss";
  }

  @override
void dispose() {
  _verticalController.dispose();
  _horizontalController.dispose();
  super.dispose();
}

  // ---------------------------------------------------------------------------
  // INIT HELPERS
  // ---------------------------------------------------------------------------

  void _initControllers() {
  for (final row in widget.selections) {
    final controller = _controllers[row.punterNumber];
    if (controller == null) {
      _controllers[row.punterNumber] =
          TextEditingController(text: row.punterName);
    } else {
      // ⭐ Keep controller text in sync with updated names
      if (controller.text != row.punterName) {
        controller.text = row.punterName;
      }
    }
  }
}

  void _initFocusNodes() {
  for (final row in widget.selections) {
    _punterFocusNodes[row.punterNumber] ??= FocusNode();
  }
}

  // ---------------------------------------------------------------------------
  // BUILD BODY
  // ---------------------------------------------------------------------------

  Widget _buildBody(
    ThemeData theme,
    ColorScheme cs,
    List<PunterSelection> visible,
    int pickCount,
    double tableWidth,
    double fontSize,
  ) {
    return ListView.builder(
      controller: ScrollController(),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        try {
          final row = visible[index];
          final isStriped = index.isOdd;
          final invalid = _hasAnyGlobalDuplicate();

          final bg = invalid
              ? Colors.red.withOpacity(0.10)
              : isStriped
                  ? Colors.black.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04);

          return Container(
            height: UIDimensions.rowHeight,
            decoration: BoxDecoration(
              color: bg,
                          ),
            child: Row(
              children: [
                // Punter column
                Container(
                  width: kPunterColumnWidth,
                  decoration: BoxDecoration(
                    
                  ),
                  child: _punterCell(context, row),
                ),

                // Picks + Scores
                for (int i = 0; i < pickCount; i++) ...[
                  // Pick column
                  Container(
                    width: kPickColumnWidth,
                    decoration: BoxDecoration(
                                          ),
                    child: i < row.picks.length
                        ? _buildPickCell(context, row, row.picks[i])
                        : const SizedBox(),
                  ),

                  // Score column
                  Container(
                    width: kPickScoreColumnWidth,
                    decoration: BoxDecoration(
                      
                    ),
                    child: i < row.picks.length
                        ? _pickScoreCell(row.picks[i])
                        : const SizedBox(),
                  ),
                ],

                // Total column
                Container(
                  width: kTotalColumnWidth,
                  decoration: BoxDecoration(
                    
                  ),
                  child: _totalCell(context, row),
                ),
              ],
            ),
          );
        } catch (e, st) {
          print("❌ TABLE ROW ERROR at index $index → $e");
          print(st);
          return const SizedBox.shrink();
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildTableHeader(
    ThemeData theme,
    ColorScheme cs,
    int pickCount,
    double tableWidth,
    double fontSize,
  ) {
    return SizedBox(
      height: isPortraitPhone(context) ? 34 : UIDimensions.headerHeight,
      child: Row(
        children: [
          SizedBox(
            width: kPunterColumnWidth,
            child: _headerCell(theme, "Punter", alignCenter: true),
          ),
          for (int i = 0; i < pickCount; i++) ...[
            SizedBox(
              width: kPickColumnWidth,
              child: _headerCell(theme, "Pick ${i + 1}", alignCenter: true),
            ),
            SizedBox(
              width: kPickScoreColumnWidth,
              child: _headerCell(theme, "S", alignCenter: true),
            ),
          ],
          SizedBox(
            width: kTotalColumnWidth,
            child: _headerCell(theme, "Total", alignCenter: true),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    ThemeData theme,
    String text, {
    bool alignCenter = false,
  }) {
    return Container(
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: alignCenter ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final pickCount = widget.playersPerPunter;
  final minWidth = _minTableWidth(pickCount);

  final visibleRows =
      widget.selections.take(widget.visiblePunterCount).toList();

  return Scrollbar(
    controller: _verticalController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _verticalController,
      scrollDirection: Axis.vertical,

      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,

        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,

          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              maxWidth: double.infinity,
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTableHeader(
                  theme,
                  cs,
                  pickCount,
                  minWidth,
                  theme.textTheme.bodySmall?.fontSize ?? 12,
                ),

                const Divider(height: 1),

                // Vertical scroll is handled by the outer SingleChildScrollView
                Column(
                  children: [
                    for (final row in visibleRows)
                      _buildRow(
                        theme,
                        cs,
                        row,
                        pickCount,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}


  // ---------------------------------------------------------------------------
  // ROW (used by build + debug version you pasted)
// ---------------------------------------------------------------------------

  Widget _buildRow(
    ThemeData theme,
    ColorScheme cs,
    PunterSelection row,
    int pickCount,
  ) {
    final index = row.punterNumber - 1;
    final isStriped = index.isOdd;

    final isRowCompleted = row.isCompletedPunter == true;
    final bg = isRowCompleted
        ? Colors.grey.withOpacity(0.60)
        : (isStriped
            ? Colors.white.withOpacity(0.07)
            : Colors.black.withOpacity(0.25));

    return Container(
      height: UIDimensions.rowHeight,
      decoration: BoxDecoration(
        color: bg,
        
      ),
      child: Row(
        children: [
          // Punter column
          Container(
            width: kPunterColumnWidth,
            decoration: BoxDecoration(
              
            ),
            child: _punterCell(context, row),
          ),

          // Picks + Scores
          for (int i = 0; i < pickCount; i++) ...[
            // Pick column
            Container(
              width: kPickColumnWidth,
              decoration: BoxDecoration(
                              ),
              child: i < row.picks.length
                  ? _buildPickCell(context, row, row.picks[i])
                  : const SizedBox(),
            ),

            // Score column
            Container(
              width: kPickScoreColumnWidth,
              decoration: BoxDecoration(
                
              ),
              child: i < row.picks.length
                  ? _pickScoreCell(row.picks[i])
                  : const SizedBox(),
            ),
          ],

          // Total column
          Container(
            width: kTotalColumnWidth,
            decoration: BoxDecoration(
                         ),
            child: _totalCell(context, row),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PUNTER CELL
  // ---------------------------------------------------------------------------

  Widget _punterCell(BuildContext context, PunterSelection row) {
    final theme = Theme.of(context);
    final isEditable = widget.userRoleService.isAdmin && !widget.readOnly;

    final controller = _controllers[row.punterNumber] ??=
        TextEditingController(text: row.punterName);

    final focusNode = _punterFocusNodes[row.punterNumber] ??= FocusNode();

    // Keep controller in sync with model
    if (controller.text != row.punterName) {
      controller.text = row.punterName;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 1),
      child: TextField(
        enabled: isEditable,
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.left,
        textCapitalization: TextCapitalization.characters,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
          hintText: "",
        ),
        onChanged: (value) {
          final upper = value.toUpperCase();
          if (upper != value) {
            controller.value = controller.value.copyWith(
              text: upper,
              selection: TextSelection.collapsed(offset: upper.length),
            );
          }
          row.punterName = upper;
          widget.onChanged?.call();
        },
        onSubmitted: (_) {
          row.punterName = controller.text.trim();
          widget.onChanged?.call();
          // Move focus to next row
          final nextNode = _punterFocusNodes[row.punterNumber + 1];
          if (nextNode != null) {
            FocusScope.of(context).requestFocus(nextNode);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        onEditingComplete: () {
          row.punterName = controller.text.trim();
          widget.onChanged?.call();
          // Move focus to next row
          final nextNode = _punterFocusNodes[row.punterNumber + 1];
          if (nextNode != null) {
            FocusScope.of(context).requestFocus(nextNode);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }

  void _showPunterPicker(
    BuildContext context,
    PunterSelection row,
    TextEditingController controller,
    List<String> allNames,
  ) {
    // Names already used in this round (exclude current row)
    final usedNames = widget.selections
        .where((s) => s.punterNumber != row.punterNumber)
        .map((s) => s.punterName.trim().toUpperCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    // Filter out already-used names
    final available =
        allNames.where((n) => !usedNames.contains(n.toUpperCase())).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String filter = "";
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = filter.isEmpty
                ? available
                : available
                    .where((n) =>
                        n.toUpperCase().contains(filter.toUpperCase()))
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Search / new name input
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Search or type new name...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                        onChanged: (v) => setSheetState(() => filter = v),
                        onSubmitted: (v) {
                          // Allow typing a brand new name
                          final newName = v.trim();
                          if (newName.isNotEmpty) {
                            final formatted = newName[0].toUpperCase() +
                                newName.substring(1);
                            row.punterName = formatted;
                            controller.text = formatted;
                            widget.onChanged?.call();
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // "Clear" option
                      if (row.punterName.isNotEmpty)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.clear, size: 18, color: Colors.red),
                          title: const Text("Clear name",
                              style: TextStyle(color: Colors.red, fontSize: 14)),
                          onTap: () {
                            row.punterName = "";
                            controller.text = "";
                            widget.onChanged?.call();
                            Navigator.pop(ctx);
                          },
                        ),
                      const Divider(height: 1),
                      // List of known names
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final name = filtered[i];
                            final isCurrent = name == row.punterName;
                            return ListTile(
                              dense: true,
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isCurrent ? Colors.blue : null,
                                ),
                              ),
                              trailing: isCurrent
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.blue)
                                  : null,
                              onTap: () {
                                row.punterName = name;
                                controller.text = name;
                                widget.onChanged?.call();
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  // ---------------------------------------------------------------------------
  // PICK CELL (Dropdown)
  // ---------------------------------------------------------------------------

  Widget _buildPickCell(
  BuildContext context,
  PunterSelection row,
  PlayerPick pick,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final visualRowIndex = row.punterNumber - 1;
  final colIndex = pick.pickNumber - 1;
  final owner = row;

  // ✅ Only treat as completed if there IS a player
  final bool isCompleted = pick.player != null && pick.isCompleted == true;

  // ⭐ OUTER background (full cell) - no shading
  const Color bgColor = Colors.transparent;

  // Build globalTaken set
  final globalTaken = <String>{};
  for (final r in widget.selections) {
    for (int i = 0; i < r.picks.length; i++) {
      final p = r.picks[i].player;
      if (p == null) continue;
      if (identical(r, owner) && i == colIndex) continue;
      globalTaken.add(p.id);
    }
  }

  final selectedPlayer = owner.picks[colIndex].player;
  final allPlayers = widget.availablePlayers;

  final filteredPlayers = allPlayers
      .where((p) {
        final isTaken = globalTaken.contains(p.id);
        final isCurrent = p == selectedPlayer;
        return !isTaken || isCurrent;
      })
      .toList()
    ..sort((a, b) => b.fantasyScore.compareTo(a.fantasyScore));

  final globalPickNumber = _globalPickNumberForCell(
    rowIndex: visualRowIndex,
    colIndex: colIndex,
  );

  final hintText = "P$globalPickNumber";

  final pickKey = "${row.punterNumber}_${pick.pickNumber}";
  _pickFocusNodes.putIfAbsent(pickKey, () => FocusNode());

  // ── Variables that were previously inside dropdownBuilder — moved to method scope
  final safeName = (selectedPlayer?.fullName ?? "").trim();
  final text = safeName.isEmpty ? hintText : safeName;

  final colours = selectedPlayer == null ? null : _getTeamColoursForPlayer(selectedPlayer);
  final teamBg = colours?["bg"];
  final Color chipBg = isCompleted
      ? Colors.grey.withOpacity(0.60)
      : (teamBg != null
          ? teamBg.withOpacity(0.85)
          : Colors.white.withOpacity(0.12));
  final Color chipFg = isCompleted ? Colors.white : (colours?["fg"] ?? Colors.white);

  final bool isTouchDevice = MediaQuery.of(context).size.shortestSide < 1200;
  final bool canClear = widget.userRoleService.isAdmin && !widget.readOnly && selectedPlayer != null;

  void clearPick() {
    setState(() {
      owner.picks[colIndex].player = null;
      owner.picks[colIndex].stats = null;
    });
    widget.onChanged?.call();
  }

  final chip = Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: chipBg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: IntrinsicWidth(
      child: Text(
        text,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.1,
        ).copyWith(color: chipFg),
      ),
    ),
  );

  // Centred chip overlay — sits on top of the invisible DropdownSearch
  final chipOverlay = Center(
    child: canClear && isTouchDevice
        ? GestureDetector(onLongPress: clearPick, child: chip)
        : IgnorePointer(child: chip),
  );

  return Stack(
    alignment: Alignment.center,
    children: [
      Container(color: bgColor),
      Opacity(
        opacity: 0.0,
        child: DropdownSearch<AflPlayer>(
      selectedItem: selectedPlayer,
      items: filteredPlayers,
      itemAsString: (p) => p.fullName,
      enabled: widget.userRoleService.isAdmin && !widget.readOnly,

      popupProps: PopupProps.menu(
        constraints: BoxConstraints(
          minWidth: kPickColumnWidth,
          maxWidth: kPickColumnWidth,
        ),
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          autofocus: true,
          focusNode: _searchFocusNodes[pickKey] ??= FocusNode(),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 50), () {
              _searchFocusNodes[pickKey]?.requestFocus();
            });
          },
          decoration: const InputDecoration(
            hintText: "Search player...",
            isDense: true,
          ),
        ),
      ),

      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),

      dropdownButtonProps: const DropdownButtonProps(
        icon: SizedBox.shrink(),
      ),

      clearButtonProps: const ClearButtonProps(isVisible: false),

      dropdownBuilder: (context, player) => const SizedBox.shrink(),

      onChanged: (player) {
        setState(() {
          owner.picks[colIndex].player = player;
          owner.picks[colIndex].stats = null;
        });

        widget.onChanged?.call();

        final picks = row.picks;
        final isLastPickInRow = colIndex == picks.length - 1;

        if (!isLastPickInRow) {
          final nextPick = picks[colIndex + 1];
          final nextKey = "${row.punterNumber}_${nextPick.pickNumber}";
          final nextNode = _pickFocusNodes[nextKey];

          if (nextNode != null) {
            FocusScope.of(context).requestFocus(nextNode);
            return;
          }
        }

        final nextPunterIndex = row.punterNumber + 1;
        final nextPunterNode = _punterFocusNodes[nextPunterIndex];

        if (nextPunterNode != null) {
          FocusScope.of(context).requestFocus(nextPunterNode);
        } else {
          FocusScope.of(context).unfocus();
        }
      },
    ),
      ), // close Opacity
      // Centred chip overlay
      chipOverlay,
      // X button — desktop only
      if (canClear && !isTouchDevice)
        Positioned(
          right: 2,
          child: GestureDetector(
            onTap: clearPick,
            child: Icon(Icons.clear, size: 14, color: cs.error),
          ),
        ),
    ],
  );
}


  // ---------------------------------------------------------------------------
  // APPLY LIVE STATS TO PICKS (called by GameViewScreen)
  // ---------------------------------------------------------------------------

  void applyLiveStatsToTable(Map<String, AflPlayerMatchStats> statsById) {
  for (final selection in widget.selections) {
    bool allCompleted = true; // Track full-row completion

    for (final pick in selection.picks) {
      final id = pick.player?.id;

      // No player selected
      if (id == null || id.isEmpty) {
        pick.isCompleted = false;
        pick.isLive = false; // ⭐ ensure not live
        pick.fantasyPoints = 0;
        pick.stats = {
          "AF": 0,
          "K": 0,
          "HB": 0,
          "D": 0,
          "M": 0,
          "T": 0,
          "G": 0,
          "B": 0,
        };
        allCompleted = false;
        continue;
      }

      // Lookup stats for this player
      final s = statsById[id];

      // No stats → future game, not started, or round already completed
      // ⭐ If the round is completed, keep existing scores rather than zeroing them
      if (s == null) {
        if (widget.isCompleted) {
          // Round is done — don't overwrite scores we already have from the snapshot
          pick.isCompleted = true;
          pick.isLive = false;
          allCompleted = allCompleted && (pick.fantasyPoints ?? 0) > 0;
        } else {
          pick.isCompleted = false;
          pick.isLive = false;
          pick.fantasyPoints = 0;
          pick.stats = {
            "AF": 0,
            "K": 0,
            "HB": 0,
            "D": 0,
            "M": 0,
            "T": 0,
            "G": 0,
            "B": 0,
          };
          allCompleted = false;
        }
        continue;
      }

      // Stats exist → completed or in-progress game
      pick.isCompleted = s.isCompletedGame;
      pick.isLive = s.isLiveGame; // ⭐ FIXED

      if (!pick.isCompleted) {
        allCompleted = false;
      }

      // Normalise stats safely
      final af = s.fantasyPoints ?? 0;
      final k = s.kicks ?? 0;
      final hb = s.handballs ?? 0;
      final d = s.disposals ?? (k + hb);
      final m = s.marks ?? 0;
      final t = s.tackles ?? 0;
      final g = s.goals ?? 0;
      final b = s.behinds ?? 0;

      pick.fantasyPoints = af;

      pick.stats = {
        "AF": af,
        "K": k,
        "HB": hb,
        "D": d,
        "M": m,
        "T": t,
        "G": g,
        "B": b,
      };
    }

    // Store full-row completion flag
    selection.isCompletedPunter = allCompleted;

    // Recalculate punter total
    selection.liveScore = widget.fantasyService.calculatePunterScore(
      selection: selection,
      liveStatsByPlayerId: statsById,
    );
  }

  // Rebuild table UI
  setState(() {});

  // Notify GameViewScreen to save snapshot (admin only)
  widget.onLiveScoreUpdateSave?.call();

  // Update timestamp label in GameViewScreen
  final now = DateTime.now();
  final formatted =
      "${now.hour.toString().padLeft(2, '0')}:"
      "${now.minute.toString().padLeft(2, '0')}:"
      "${now.second.toString().padLeft(2, '0')}";

  widget.onTimestampChanged?.call(formatted);
}


  // ---------------------------------------------------------------------------
  // SCORE CELL
  // ---------------------------------------------------------------------------

  Widget _pickScoreCell(PlayerPick pick) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  // ── Average Preview Mode ──────────────────────────────────────────────────
  if (widget.showAveragePreview && pick.player != null) {
    final avg = widget.allPlayers
        .where((p) => p.id == pick.player!.id)
        .map((p) => p.fantasyScore)
        .firstOrNull ?? pick.player!.fantasyScore;

    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.orange.shade400.withOpacity(0.70), // dark amber
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "$avg",
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  final bool isCompleted = pick.player != null && pick.isCompleted == true;
  final bool isLive = pick.isLive == true;

  // ⭐ Determine background colour
  Color bg;
  Color fg = Colors.black;

  if (isCompleted) {
    bg = Colors.grey.withOpacity(0.60);
  } else if (isLive) {
    bg = Colors.green.withOpacity(0.45);   // ⭐ live highlight
  } else {
    bg = Colors.transparent;
    fg = cs.onSurface;                     // normal text
  }

  return Container(
    alignment: Alignment.center,
    padding: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      "${pick.fantasyPoints ?? 0}",
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: fg,
      ),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    ),
  );
}

  // ---------------------------------------------------------------------------
  // TOTAL CELL
  // ---------------------------------------------------------------------------

  Widget _totalCell(BuildContext context, PunterSelection row) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: widget.showAveragePreview
              ? Colors.orange.shade400.withOpacity(0.70)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.showAveragePreview
              ? "${row.avgScore(widget.allPlayers)}"
              : "${row.totalScore}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEAM COLOURS
  // ---------------------------------------------------------------------------

  Map<String, Color> _getTeamColoursForPlayer(AflPlayer? player) {
    if (player == null || player.club.isEmpty) {
      return {
        "bg": Colors.transparent,
        "fg": Colors.black87,
      };
    }
    final map = TeamColoursByClub.colours[player.club];
    if (map == null) {
      return {
        "bg": Colors.transparent,
        "fg": Colors.black87,
      };
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // GLOBAL VALIDATION
  // ---------------------------------------------------------------------------

  void _cleanInvalidSelectionsGlobal() {
    final validIds = widget.availablePlayers.map((p) => p.id).toSet();

    for (final row in widget.selections) {
      for (final pick in row.picks) {
        final p = pick.player;
        if (p != null && !validIds.contains(p.id)) {
          pick.player = AflPlayer(
            id: "UNKNOWN",
            name: "Unknown",
            club: "UNK",
            guernseyNumber: 0,
            season: widget.season,
            fantasyScore: 0,
          );
          pick.stats = null;
        }
      }
    }
  }

  bool _hasAnyGlobalDuplicate() {
    final seen = <String>{};

    for (final row in widget.selections) {
      for (final pick in row.picks) {
        final p = pick.player;
        if (p == null) continue;

        if (seen.contains(p.id)) return true;
        seen.add(p.id);
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // SNAKE DRAFT LOGIC
  // ---------------------------------------------------------------------------

  // Tracks the authoritative current pick number (1-based)
  int currentGlobalPick = 1;

  bool _isCurrentPick(PunterSelection row, PlayerPick pick) {
    final rowIndex = row.punterNumber - 1;
    final colIndex = pick.pickNumber - 1;

    final globalIndex = _globalPickNumberForCell(
      rowIndex: rowIndex,
      colIndex: colIndex,
    );

    return currentGlobalPick == globalIndex;
  }

  int _globalPickNumberForCell({
    required int rowIndex,
    required int colIndex,
  }) {
    final round = colIndex;
    final punters = _punterCount;

    // Snake draft logic
    if (round.isEven) {
      return round * punters + (rowIndex + 1);
    } else {
      return round * punters + (punters - rowIndex);
    }
  }
}