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
  final double tableWidth;

  final int visiblePunterCount;
  final int playersPerPunter;
  final List<AflPlayer> availablePlayers;
  final List<PunterSelection> selections;
  final bool isCompleted;
  final bool readOnly;
  final bool collapsed;
  final ScrollController? scrollController;

  final String gameType;
  final int season;
  final int round;

  final void Function()? onChanged;
  final void Function(String time)? onTimestampChanged;
  final VoidCallback? onLiveScoreUpdateSave;

  final UserRoleService userRoleService;
  final PunterScoreService fantasyService;

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
    required this.readOnly,
    required this.collapsed,
    required this.scrollController,
    required this.userRoleService,
    required this.fantasyService,
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
    if (isPortraitPhone(context)) return 55;
    if (isLandscapePhone) return 60;
    return 70;
  }

  double get kPickColumnWidth {
    if (isPortraitPhone(context)) return 280;
    if (isLandscapePhone) return 300;
    return 185;
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
  final Set<int> _punterListenerAdded = {};
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
    _horizontalController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // INIT HELPERS
  // ---------------------------------------------------------------------------

  void _initControllers() {
    for (final row in widget.selections) {
      _controllers[row.punterNumber] ??=
          TextEditingController(text: row.punterName);
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

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: widget.tableWidth,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth,
                maxWidth: widget.tableWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sticky header
                  _buildTableHeader(
                    theme,
                    cs,
                    pickCount,
                    widget.tableWidth,
                    theme.textTheme.bodySmall?.fontSize ?? 12,
                  ),
                  const Divider(height: 1),

                  // Scrollable body
                  Expanded(
                    child: ListView.builder(
                      controller: ScrollController(),
                      itemCount: visibleRows.length,
                      itemBuilder: (context, index) {
                        return _buildRow(
                          theme,
                          cs,
                          visibleRows[index],
                          pickCount,
                        );
                      },
                    ),
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

    final bg = isStriped
        ? cs.surfaceVariant.withAlpha(64)
        : cs.surface;

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
  final cs = theme.colorScheme;

  // ------------------------------------------------------------
  // FIX: Controller must always reflect the actual punterName
  // ------------------------------------------------------------
  final controller = _controllers[row.punterNumber] ??=
      TextEditingController(text: row.punterName);

  // If snapshot restored a name, ensure controller matches it
  if (controller.text != row.punterName) {
    controller.text = row.punterName;
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  final focusNode = _punterFocusNodes[row.punterNumber] ??= FocusNode();

  if (!_punterListenerAdded.contains(row.punterNumber)) {
    _punterListenerAdded.add(row.punterNumber);

    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        // ------------------------------------------------------------
        // FIX: Do NOT overwrite restored names with P#
        // Only apply default if user truly left it blank
        // ------------------------------------------------------------
        if (controller.text.trim().isEmpty) {
          controller.text = "P${row.punterNumber}";
          row.punterName = controller.text;
        }
      }
    });
  }

  return Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(left: 1),
    child: TextField(
      enabled: widget.userRoleService.isAdmin && !widget.readOnly,
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.left,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
        hintText: "P${row.punterNumber}",
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),

      onChanged: (value) {
        final formatted = value.isEmpty
            ? value
            : value[0].toUpperCase() + value.substring(1);

        if (formatted != value) {
          controller.value = controller.value.copyWith(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }

        // ------------------------------------------------------------
        // FIX: This is the ONLY place punterName should ever update
        // ------------------------------------------------------------
        row.punterName = formatted;
        widget.onChanged?.call();
      },

      onEditingComplete: () {
        final nextIndex = row.punterNumber + 1;
        final nextNode = _punterFocusNodes[nextIndex];

        if (nextNode != null) {
          FocusScope.of(context).requestFocus(nextNode);
        } else {
          FocusScope.of(context).unfocus();
        }
      },
    ),
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
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final globalPickNumber = _globalPickNumberForCell(
      rowIndex: visualRowIndex,
      colIndex: colIndex,
    );

    final hintText = "P$globalPickNumber";

    final pickKey = "${row.punterNumber}_${pick.pickNumber}";
    _pickFocusNodes.putIfAbsent(pickKey, () => FocusNode());

    return DropdownSearch<AflPlayer>(
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

      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),

      dropdownButtonProps: const DropdownButtonProps(
        icon: SizedBox.shrink(),
      ),

      clearButtonProps: const ClearButtonProps(isVisible: false),

      // Compact, text-hugging team-colour chip
      dropdownBuilder: (context, player) {
        final safeName = (player?.fullName ?? "").trim();
        final text = safeName.isEmpty ? hintText : safeName;
        final colours =
            player == null ? null : _getTeamColoursForPlayer(player);

        return Container(
          width: kPickColumnWidth,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Team-colour chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: colours == null
                    ? null
                    : BoxDecoration(
                        color: colours["bg"]!.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                child: IntrinsicWidth(
                  child: Text(
                    text,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colours == null
                          ? cs.onSurfaceVariant
                          : colours["fg"],
                    ),
                  ),
                ),
              ),

              // Clear button (admins only, not readOnly)
              if (widget.userRoleService.isAdmin &&
                  !widget.readOnly &&
                  player != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      owner.picks[colIndex].player = null;
                      owner.picks[colIndex].stats = null;
                    });

                    widget.onChanged?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.clear,
                      size: 16,
                      color: cs.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },

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
    );
  }
  // ---------------------------------------------------------------------------
  // APPLY LIVE STATS TO PICKS (called by GameViewScreen)
  // ---------------------------------------------------------------------------

  void applyLiveStatsToTable(Map<String, AflPlayerMatchStats> statsById) {
  for (final selection in widget.selections) {
    for (final pick in selection.picks) {
      final id = pick.player?.id;

      // No player selected
      if (id == null || id.isEmpty) {
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
        continue;
      }

      final s = statsById[id];

      // No stats yet for this player
      if (s == null) {
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
        continue;
      }

      // Normalize all stats BEFORE assigning
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

  // ⭐ Update timestamp label in GameViewScreen
  final now = DateTime.now();
  final formatted = "${now.hour.toString().padLeft(2, '0')}:"
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

    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.zero,
      child: Text(
        "${pick.fantasyPoints ?? 0}",
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
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
          color: Colors.black.withOpacity(0.20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "${row.totalScore}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
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