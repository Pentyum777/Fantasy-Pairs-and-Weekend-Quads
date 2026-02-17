// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:http/http.dart' as http;

import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../theme/team_colours_by_club.dart';
import '../constants/ui_dimensions.dart';
import '../services/user_role_service.dart';

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
  final void Function()? onChanged;
  final bool readOnly;
  final bool collapsed;
  final ScrollController? scrollController;
  final String gameType;
  final String season;
final int round;
final void Function(String time)? onTimestampChanged;
  

  final UserRoleService userRoleService;

  const PunterSelectionTable({
  super.key,
  required this.gameType,
  required this.season,     // ⭐ ADD THIS
  required this.round,      // ⭐ ADD THIS
  required this.tableWidth,
  required this.visiblePunterCount,
  required this.playersPerPunter,
  required this.availablePlayers,
  required this.selections,
  required this.isCompleted,
  required this.readOnly,
  required this.onChanged,
  required this.collapsed,
  required this.scrollController,
  required this.onTimestampChanged,
  required this.userRoleService,
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
final Map<String, FocusNode> _pickFocusNodes = {};   // ⭐ Correct: String keys
final Map<int, TextEditingController> _controllers = {};
final Map<int, FocusNode> _punterFocusNodes = {};
final Set<int> _punterListenerAdded = {};

  List<_TableSnapshot> _history = [];
  int _historyIndex = -1;
  // ignore: unused_field
int? _lastUpdated;

  // Human‑readable timestamp for UI
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

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // INIT
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
  // BUILD
  // ---------------------------------------------------------------------------

  @override
Widget build(BuildContext context) {
  if (widget.readOnly) {
    _cleanInvalidSelectionsGlobal();
  }

  final double fontSize =
      isPortraitPhone(context) ? 10 : (isLandscapePhone ? 11 : 12);

  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final visible = widget.selections.take(widget.visiblePunterCount).toList();
  final pickCount = widget.selections.isNotEmpty
      ? widget.selections.first.picks.length
      : 0;

  final baseWidth = widget.tableWidth;
  final tableWidth = math.max(baseWidth, _minTableWidth(pickCount));

  // ⭐ Dynamic height so table does NOT stretch to bottom of screen
  final double tableHeight =
      UIDimensions.headerHeight +
      (visible.length * UIDimensions.rowHeight);

  return Container(
    width: tableWidth,
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withAlpha(64),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),

      // ⭐ One horizontal scroll view for BOTH header + body
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            // -------------------------
            // HEADER (scrolls with body)
            // -------------------------
            SizedBox(
              width: tableWidth,
              child: _buildTableHeader(
                theme,
                cs,
                pickCount,
                tableWidth,
                fontSize,
              ),
            ),

            Divider(height: 1, thickness: 1, color: cs.outlineVariant),

            // -------------------------
            // BODY (dynamic height)
            // -------------------------
            SizedBox(
              width: tableWidth,
              height: tableHeight,
              child: _buildBody(
                theme,
                cs,
                visible,
                pickCount,
                tableWidth,
                fontSize,
              ),
            ),
          ],
        ),
      ),
    ),
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
  // BODY
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
      controller: widget.scrollController,
      itemCount: visible.length,
      itemBuilder: (context, index) {
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
              for (final pick in row.picks) ...[
                SizedBox(
                  width: kPickColumnWidth,
                  child: _buildPickCell(context, row, pick),
                ),
                SizedBox(
                  width: kPickScoreColumnWidth,
                  child: _pickScoreCell(pick),
                ),
              ],
              SizedBox(
                width: kTotalColumnWidth,
                child: _totalCell(context, row),
              ),
            ],
          ),
        );
      },
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
      enabled: widget.userRoleService.isAdmin,   // ⭐ Admin-only editing
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

      // ⭐ Auto-capitalise first letter
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

      // ⭐ TAB or ENTER → move to next punter
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
  // PICK CELL
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

  // -----------------------------
  // Build globalTaken set
  // -----------------------------
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

  // -----------------------------
  // ⭐ Ensure FocusNode exists for TAB navigation
  // -----------------------------
  final pickKey = "${row.punterNumber}_${pick.pickNumber}";
  _pickFocusNodes.putIfAbsent(pickKey, () => FocusNode());

  return DropdownSearch<AflPlayer>(
    selectedItem: selectedPlayer,
    items: filteredPlayers,
    itemAsString: (p) => p.fullName,

    enabled: widget.userRoleService.isAdmin,

    // -----------------------------
    // ⭐ Auto-focus search box
    // -----------------------------
    popupProps: PopupProps.menu(
  constraints: BoxConstraints(
    minWidth: kPickColumnWidth,
    maxWidth: kPickColumnWidth,
  ),
  showSearchBox: true,
  searchFieldProps: TextFieldProps(
    autofocus: true,   // ⭐ Correct autofocus
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

    clearButtonProps: const ClearButtonProps(isVisible: false),

    // -----------------------------
    // ⭐ Custom cell builder
    //    Proper wrapping + background sizing
    // -----------------------------
    dropdownBuilder: (context, player) {
      final text = player == null ? hintText : player.fullName;
      final colours = player == null ? null : _getTeamColoursForPlayer(player);

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
            softWrap: true,                 // ⭐ allow wrapping
            overflow: TextOverflow.visible, // ⭐ background grows with text
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colours == null ? cs.onSurfaceVariant : colours["fg"],
            ),
          ),
        ),
      );
    },

    // -----------------------------
    // ⭐ TAB navigation
    // -----------------------------
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

      row.punterName = snap.punterNames[i];
      _controllers[row.punterNumber]?.text = row.punterName;

      for (int j = 0; j < row.picks.length; j++) {
        final pick = row.picks[j];
        final snapPick = snap.picks[i][j];

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
        "season": widget.season,   // ⭐ REQUIRED
        "round": widget.round,     // ⭐ REQUIRED
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
    final url = Uri.parse(
      "https://fantasy-pairs-and-weekend-quads-production.up.railway.app/loadSelections"
      "?gameType=${widget.gameType}"
      "&season=${widget.season}"
      "&round=${widget.round}",
    );

    final res = await http.get(url);
    if (res.statusCode != 200) return;

    final json = jsonDecode(res.body);
    if (json == null || json is! Map<String, dynamic>) return;

    if (json["picks"] == null || json["punterNames"] == null) return;

    final punterNames = (json["punterNames"] as List<dynamic>)
        .map((e) => e.toString())
        .toList();

    final picksJson = (json["picks"] as List<dynamic>)
        .map<List<_PickSnapshot>>((row) {
      return (row as List<dynamic>).map<_PickSnapshot>((p) {
        return _PickSnapshot(
          playerId: p["playerId"] as String?,
          stats: p["stats"] == null
              ? null
              : Map<String, dynamic>.from(p["stats"] as Map),
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
