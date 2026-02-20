// ignore_for_file: unused_element

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../models/afl_player_match_stats.dart';
import '../services/punter_score_service.dart';
import '../services/user_role_service.dart';
import '../theme/team_colours_by_club.dart';
import '../constants/ui_dimensions.dart';

// ---------------------------------------------------------------------------
// SNAPSHOT MODELS
// ---------------------------------------------------------------------------

class _PickSnapshot {
  final String? playerId;
  final Map<String, dynamic>? stats;

  _PickSnapshot({
    required this.playerId,
    required this.stats,
  });
}

class _TableSnapshot {
  final List<String> punterNames;
  final List<List<_PickSnapshot>> picks;

  _TableSnapshot({
    required this.punterNames,
    required this.picks,
  });

  factory _TableSnapshot.fromSelections(List<PunterSelection> selections) {
    return _TableSnapshot(
      punterNames: selections.map((s) => s.punterName).toList(),
      picks: selections
          .map(
            (s) => s.picks
                .map(
                  (p) => _PickSnapshot(
                    playerId: p.player?.id,
                    stats: p.stats == null
                        ? null
                        : Map<String, dynamic>.from(p.stats!),
                  ),
                )
                .toList(),
          )
          .toList(),
    );
  }
}

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
  final String season;
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
    if (isPortraitPhone(context)) return 60;
    if (isLandscapePhone) return 70;
    return 90;
  }

  double get kPickColumnWidth {
    if (isPortraitPhone(context)) return 120;
    if (isLandscapePhone) return 140;
    return 185;
  }

  double get kPickScoreColumnWidth {
    if (isPortraitPhone(context)) return 30;
    if (isLandscapePhone) return 34;
    return 40;
  }

  double get kTotalColumnWidth {
    if (isPortraitPhone(context)) return 45;
    if (isLandscapePhone) return 50;
    return 60;
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

  // Snapshot history
  List<_TableSnapshot> _history = [];
  int _historyIndex = -1;

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
  void initState() {
    super.initState();
    _initControllers();
    _initFocusNodes();
    _loadSnapshotFromBackend();
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
  // PUBLIC: Save snapshot (called by GameViewScreen)
  // ---------------------------------------------------------------------------

  void saveSnapshot() {
    final snap = _TableSnapshot.fromSelections(widget.selections);
    _saveSnapshotToBackend(snap);
  }

  @override
  void didUpdateWidget(covariant PunterSelectionTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectionsChanged =
        !identical(oldWidget.selections, widget.selections);

    if (selectionsChanged) {
      _initControllers();
      _initFocusNodes();
      _saveSnapshot();
    }
  }
  // ---------------------------------------------------------------------------
// BUILD
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
    // ⭐ FIX: Do NOT share vertical scroll controller with leaderboard
    controller: ScrollController(),

    itemCount: visible.length,
    itemBuilder: (context, index) {
      try {
        final row = visible[index];
        final isStriped = index.isOdd;
        final invalid = _hasAnyGlobalDuplicate();

        final bg = invalid
            ? Colors.red.withAlpha(15)
            : isStriped
                ? cs.surfaceContainerHighest.withAlpha(64)
                : cs.surface;

        return Container(
          height: isPortraitPhone(context)
              ? 32
              : (isLandscapePhone ? 34 : UIDimensions.rowHeight),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withAlpha(153),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: kPunterColumnWidth,
                child: _punterCell(context, row),
              ),

              // Picks
              for (int i = 0; i < pickCount; i++) ...[
                SizedBox(
                  width: kPickColumnWidth,
                  child: i < row.picks.length
                      ? _buildPickCell(context, row, row.picks[i])
                      : const SizedBox(),
                ),
                SizedBox(
                  width: kPickScoreColumnWidth,
                  child: i < row.picks.length
                      ? _pickScoreCell(row.picks[i])
                      : const SizedBox(),
                ),
              ],

              SizedBox(
                width: kTotalColumnWidth,
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
            child: _headerCell(theme, "Score", alignCenter: true),
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
// Build conext
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
                // ⭐ Sticky header
                _buildTableHeader(
                  theme,
                  cs,
                  pickCount,
                  widget.tableWidth,
                  theme.textTheme.bodySmall?.fontSize ?? 12,
                ),
                const Divider(height: 1),

                // ⭐ Scrollable body
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
// PUNTER CELL
// ---------------------------------------------------------------------------

Widget _punterCell(BuildContext context, PunterSelection row) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final controller = _controllers[row.punterNumber] ??=
      TextEditingController(text: row.punterName);
  final focusNode = _punterFocusNodes[row.punterNumber] ??= FocusNode();

  if (!_punterListenerAdded.contains(row.punterNumber)) {
    _punterListenerAdded.add(row.punterNumber);

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (controller.text.trim() == "P${row.punterNumber}") {
          controller.clear();
        }
      } else {
        if (controller.text.trim().isEmpty) {
          controller.text = "P${row.punterNumber}";
        }
      }
    });
  }

  return Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: TextField(
      enabled: widget.userRoleService.isAdmin,
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

      // Auto-capitalise
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

        row.punterName = formatted;
        widget.onChanged?.call();
        _saveSnapshot();
      },

      // TAB / ENTER → next punter
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

Widget _buildRow(ThemeData theme, ColorScheme cs, PunterSelection row, int pickCount) {
  final index = row.punterNumber - 1;
  final isStriped = index.isOdd;

  final bg = isStriped
      ? cs.surfaceContainerHighest.withAlpha(64)
      : cs.surface;

  return Container(
    height: UIDimensions.rowHeight,
    decoration: BoxDecoration(
      color: bg,
      border: Border(
        bottom: BorderSide(
          color: cs.outlineVariant.withAlpha(153),
          width: 0.5,
        ),
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: kPunterColumnWidth,
          child: _punterCell(context, row),
        ),
        for (int i = 0; i < pickCount; i++) ...[
          SizedBox(
            width: kPickColumnWidth,
            child: i < row.picks.length
                ? _buildPickCell(context, row, row.picks[i])
                : const SizedBox(),
          ),
          SizedBox(
            width: kPickScoreColumnWidth,
            child: i < row.picks.length
                ? _pickScoreCell(row.picks[i])
                : const SizedBox(),
          ),
        ],
        SizedBox(
          width: kTotalColumnWidth,
          child: _totalCell(context, row),
        ),
      ],
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
    enabled: widget.userRoleService.isAdmin,

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
      dropdownSearchDecoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
      ),
    ),

    dropdownButtonProps: const DropdownButtonProps(
      icon: SizedBox.shrink(),
    ),

    clearButtonProps: const ClearButtonProps(
      isVisible: false,
    ),

    dropdownBuilder: (context, player) {
      final text = player == null ? hintText : player.fullName;
      final colours =
          player == null ? null : _getTeamColoursForPlayer(player);

      return Container(
        width: kPickColumnWidth,
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: colours == null
              ? null
              : BoxDecoration(
                  color: colours["bg"]?.withAlpha(230),
                  borderRadius: BorderRadius.circular(4),
                ),
          child: Text(
            text,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colours == null ? cs.onSurfaceVariant : colours["fg"],
            ),
          ),
        ),
      );
    },

    onChanged: (player) {
      setState(() {
        owner.picks[colIndex].player = player;
        owner.picks[colIndex].stats = null;
      });

      widget.onChanged?.call();
      _saveSnapshot();

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
      if (id == null) {
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

      // ⭐ Normalize all stats BEFORE assigning
      final af = s.fantasyPoints ?? 0;
      final k = s.kicks ?? 0;
      final hb = s.handballs ?? 0;
      final d = s.disposals ?? 0;
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

  setState(() {});

  widget.onLiveScoreUpdateSave?.call();
}


// ---------------------------------------------------------------------------
// SCORE CELL
// ---------------------------------------------------------------------------

Widget _pickScoreCell(PlayerPick pick) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      "${pick.fantasyPoints}",
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
  final cs = theme.colorScheme;

  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "${row.totalScore}",
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.primary,
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
        pick.player = null;
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

bool _isCurrentPick(PunterSelection row, PlayerPick pick) {
  final rowIndex = row.punterNumber - 1;
  final colIndex = pick.pickNumber - 1;

  final globalIndex = _globalPickNumberForCell(
    rowIndex: rowIndex,
    colIndex: colIndex,
  );

  int made = 0;
  for (final r in widget.selections) {
    for (final p in r.picks) {
      if (p.player != null) made++;
    }
  }

  return made + 1 == globalIndex;
}

int _globalPickNumberForCell({
  required int rowIndex,
  required int colIndex,
}) {
  final round = colIndex;
  final punters = _punterCount;

  if (round.isEven) {
    return round * punters + (rowIndex + 1);
  } else {
    return round * punters + (punters - rowIndex);
  }
}
// ---------------------------------------------------------------------------
// SNAPSHOT SAVE / RESTORE
// ---------------------------------------------------------------------------

void _saveSnapshot() {
  if (_historyIndex < _history.length - 1) {
    _history.removeRange(_historyIndex + 1, _history.length);
  }

  final snap = _TableSnapshot.fromSelections(widget.selections);
  _history.add(snap);
  _historyIndex = _history.length - 1;

  if (widget.userRoleService.isAdmin) {
    _saveSnapshotToBackend(snap);
  }
}

void _restoreSnapshot(int index) {
  if (index < 0 || index >= _history.length) return;

  final snap = _history[index];
  setState(() {
    _applySnapshot(snap);
    _historyIndex = index;
  });

  widget.onChanged?.call();
}

void _applySnapshot(_TableSnapshot snap) {
  for (int i = 0; i < widget.selections.length; i++) {
    final row = widget.selections[i];

    // ---- Safe punterName ----
    String safeName = "P${row.punterNumber}";
    if (i < snap.punterNames.length) {
      final name = snap.punterNames[i];
      if (name.isNotEmpty) {
        safeName = name;
      }
    }

    row.punterName = safeName;
    _controllers[row.punterNumber]?.text = safeName;

    // ---- Safe picks ----
    if (i >= snap.picks.length) {
      // No picks for this row → clear them
      for (final pick in row.picks) {
        pick.player = null;
        pick.stats = null;
      }
      continue;
    }

    final snapRow = snap.picks[i];

    for (int j = 0; j < row.picks.length; j++) {
      final pick = row.picks[j];

      if (j >= snapRow.length) {
        pick.player = null;
        pick.stats = null;
        continue;
      }

      final snapPick = snapRow[j];

      // ---- Safe player restore ----
      if (snapPick.playerId == null) {
        pick.player = null;
        pick.stats = null;
        continue;
      }

      final restored = widget.availablePlayers
          .where((p) => p.id == snapPick.playerId)
          .toList();

      if (restored.isEmpty) {
        pick.player = null;
        pick.stats = null;
      } else {
        pick.player = restored.first;
        pick.stats = snapPick.stats == null
            ? null
            : Map<String, dynamic>.from(snapPick.stats!);
      }
    }
  }
}



// ---------------------------------------------------------------------------
// SAVE SNAPSHOT TO BACKEND (Admins only)
// ---------------------------------------------------------------------------

Future<void> _saveSnapshotToBackend(_TableSnapshot snap) async {
  try {
    final url = Uri.parse(
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app/saveSelections",
    );

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "gameType": widget.gameType,
        "season": widget.season,
        "round": widget.round,
        "punterNames": snap.punterNames,
        "picks": snap.picks.map((row) {
          return row.map((p) {
            return {
              "playerId": p.playerId,
              "stats": p.stats,
            };
          }).toList();
        }).toList(),
      }),
    );

    final json = jsonDecode(res.body);

    if (json["lastUpdated"] != null) {
      _lastUpdated = json["lastUpdated"];
      widget.onTimestampChanged?.call(lastUpdatedLabel);
    }
  } catch (e) {
    debugPrint("❌ Failed to save selections: $e");
  }
}

// ---------------------------------------------------------------------------
// LOAD SNAPSHOT FROM BACKEND
// ---------------------------------------------------------------------------

Future<void> _loadSnapshotFromBackend() async {
  try {
    final url = Uri.https(
      "fantasy-pairs-and-weekend-quads-production.up.railway.app",
      "/loadSelections",
      {
        "gameType": widget.gameType,
        "season": widget.season,
        "round": widget.round.toString(),
      },
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      debugPrint("❌ loadSelections returned ${res.statusCode}");
      return;
    }

    final json = jsonDecode(res.body);
    if (json == null || json is! Map<String, dynamic>) {
      debugPrint("⚠️ loadSelections: response not a JSON map");
      return;
    }

    final data = json["data"];
    if (data == null) {
      debugPrint("⚠️ loadSelections: data field missing");
      return;
    }

    // Validate punterNames
    final punterNamesRaw = data["punterNames"];
    if (punterNamesRaw == null || punterNamesRaw is! List) {
      debugPrint("⚠️ loadSelections: punterNames missing or invalid");
      return;
    }

    final punterNames = punterNamesRaw
        .map((e) => e?.toString() ?? "")
        .toList();

    // Validate picks
    final picksRaw = data["picks"];
    if (picksRaw == null || picksRaw is! List) {
      debugPrint("⚠️ loadSelections: picks missing or invalid");
      return;
    }

    final picksJson = picksRaw.map<List<_PickSnapshot>>((row) {
      if (row is! List) return <_PickSnapshot>[];

      return row.map<_PickSnapshot>((p) {
        final playerId = p is Map && p["playerId"] != null
            ? p["playerId"] as String?
            : null;

        final stats = p is Map && p["stats"] is Map
            ? Map<String, dynamic>.from(p["stats"])
            : null;

        return _PickSnapshot(
          playerId: playerId,
          stats: stats,
        );
      }).toList();
    }).toList();

    final snap = _TableSnapshot(
      punterNames: punterNames,
      picks: picksJson,
    );

    setState(() {
      _applySnapshot(snap);
      _history = [snap];
      _historyIndex = 0;
    });

    widget.onChanged?.call();
  } catch (e) {
    debugPrint("❌ Failed to load selections: $e");
  }
}
}