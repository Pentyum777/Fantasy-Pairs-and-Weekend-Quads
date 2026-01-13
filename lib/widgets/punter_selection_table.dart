// ignore_for_file: unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../models/afl_player.dart';
import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../theme/team_colours_by_club.dart';

class PunterSelectionTable extends StatefulWidget {
  final int visiblePunterCount;
  final int playersPerPunter;
  final List<AflPlayer> availablePlayers;
  final List<PunterSelection> selections;
  final bool isCompleted;

  /// Nullable callback — allowed to be null in read‑only mode
  final void Function()? onChanged;

  /// NEW: read‑only mode flag
  final bool readOnly;

  const PunterSelectionTable({
    super.key,
    required this.visiblePunterCount,
    required this.playersPerPunter,
    required this.availablePlayers,
    required this.selections,
    required this.isCompleted,
    this.onChanged,          // <-- FIXED (nullable, not required)
    required this.readOnly,  // <-- FIXED (required)
  });

  @override
  State<PunterSelectionTable> createState() => _PunterSelectionTableState();
}

class _PunterSelectionTableState extends State<PunterSelectionTable> {
  // Layout
  static const double rowHeight = 34.0;
  static const double headerHeight = 40.0;

  double punterColWidth = 110.0;
  double pickColWidth = 150.0;
  static const double totalColWidth = 70.0;

  final Map<int, TextEditingController> _controllers = {};
  final ScrollController _verticalScrollController = ScrollController();

  // Undo/redo history
  List<_TableSnapshot> _history = [];
  int _historyIndex = -1;

  // Internal player list
  List<AflPlayer> _players = [];
  bool _loadingPlayers = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPlayers();
    _saveSnapshot();
  }

  // ---------------------------------------------------------------------------
  // CLUB NAME → CLUB CODE MAPPING
  // ---------------------------------------------------------------------------

  static const Map<String, String> _clubCodeMap = {
  "Adelaide Crows": "ADE",
  "Brisbane": "BRI",
  "Carlton": "CARL",
  "Collingwood": "COLL",
  "Essendon": "ESS",
  "Fremantle": "FRE",
  "Geelong": "GEEL",        // <- corrected
  "Gold Coast Suns": "GC",
  "Greater Western Sydney": "GWS",
  "Hawthorn": "HAW",
  "Melbourne": "MELB",
  "North Melbourne": "NM",
  "Port Adelaide": "PORT",  // <- corrected
  "Richmond": "RICH",
  "St Kilda": "STK",
  "Sydney Swans": "SYD",
  "West Coast Eagles": "WCE",
  "Western Bulldogs": "WB",
};

  // ---------------------------------------------------------------------------
  // LOAD PLAYERS FROM JSON ARRAY
  // ---------------------------------------------------------------------------

    Future<void> _loadPlayers() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/afl_players_2026.json');

      final List<dynamic> data = json.decode(jsonString);

      final List<AflPlayer> parsed = [];

      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;

        // Name/id handling: prefer name, fall back to id
        final rawName = (raw['name'] ?? raw['id'] ?? '').toString().trim();
        if (rawName.isEmpty) continue;

        // Club handling: supports either full name or already-code
        final clubRaw = (raw['club'] ?? '').toString().trim();
        final clubCode = _clubCodeMap[clubRaw] ?? clubRaw;

        // Number handling: supports both guernseyNumber and number
        final numberRaw = raw['guernseyNumber'] ?? raw['number'] ?? 0;
        final guernsey = int.tryParse(numberRaw.toString()) ?? 0;

        // Season handling: default 2026
        final seasonRaw = raw['season'] ?? 2026;
        final season = int.tryParse(seasonRaw.toString()) ?? 2026;

        parsed.add(
          AflPlayer(
            id: rawName,
            name: rawName,
            club: clubCode,
            guernseyNumber: guernsey,
            season: season,
          ),
        );
      }

      // Sort by shortName
      parsed.sort(
        (a, b) =>
            a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
      );

      setState(() {
        _players = parsed;
        _loadingPlayers = false;
      });
    } catch (e) {
      setState(() {
        _players = [];
        _loadingPlayers = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant PunterSelectionTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initControllers();
  }

  void _initControllers() {
    for (final row in widget.selections) {
      _controllers[row.punterNumber] ??=
          TextEditingController(text: row.punterName);
    }
  }
  // ---------------------------------------------------------------------------
  // SNAKE DRAFT MAPPING
  // ---------------------------------------------------------------------------

  int get _punterCount => widget.visiblePunterCount;
  int get _roundCount => widget.playersPerPunter;

  int _globalPickNumberForCell({
    required int rowIndex,
    required int colIndex,
  }) {
    final int round = colIndex;
    final int indexInRound = rowIndex;
    final int base = round * _punterCount;

    if (round.isEven) {
      return base + indexInRound + 1;
    } else {
      return base + (_punterCount - indexInRound);
    }
  }

  (int rowIndex, int colIndex) _cellForGlobalPickNumber(int pickNumber) {
    final n = pickNumber - 1;
    final round = n ~/ _punterCount;
    final indexInRound = n % _punterCount;

    int rowIndex;
    if (round.isEven) {
      rowIndex = indexInRound;
    } else {
      rowIndex = _punterCount - 1 - indexInRound;
    }

    return (rowIndex, round);
  }

  // ---------------------------------------------------------------------------
  // CURRENT PICK
  // ---------------------------------------------------------------------------

  (int rowIndex, int colIndex)? _findCurrentPick() {
    final totalPicks = _punterCount * _roundCount;

    for (int pickNumber = 1; pickNumber <= totalPicks; pickNumber++) {
      final (rowIndex, colIndex) = _cellForGlobalPickNumber(pickNumber);

      if (rowIndex < 0 ||
          rowIndex >= widget.selections.length ||
          colIndex < 0 ||
          colIndex >= _roundCount) {
        continue;
      }

      final row = widget.selections[rowIndex];
      final pick = row.picks[colIndex];
      if (pick.player == null) {
        return (rowIndex, colIndex);
      }
    }

    return null;
  }

  bool _isCurrentPick(PunterSelection visualRow, PlayerPick pick) {
    final current = _findCurrentPick();
    if (current == null) return false;

    final visualRowIndex = visualRow.punterNumber - 1;
    final pickIndex = pick.pickNumber - 1;

    return current.$1 == visualRowIndex && current.$2 == pickIndex;
  }

  void _scrollToCurrentPick() {
    final current = _findCurrentPick();
    if (current == null) return;

    final rowIndex = current.$1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_verticalScrollController.hasClients) return;
      final targetOffset = rowIndex * rowHeight;
      _verticalScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // UNIQUENESS AND CLEANUP
  // ---------------------------------------------------------------------------

  Set<String> _allSelectedPlayerIdsExcept(PunterSelection row) {
    final ids = <String>{};
    for (final r in widget.selections) {
      if (identical(r, row)) continue;
      for (final pick in r.picks) {
        if (pick.player != null) ids.add(pick.player!.id);
      }
    }
    return ids;
  }

  void _cleanInvalidSelections() {
    for (final row in widget.selections) {
      final globalTaken = _allSelectedPlayerIdsExcept(row);
      for (final pick in row.picks) {
        if (pick.player != null && globalTaken.contains(pick.player!.id)) {
          pick.player = null;
          pick.score = 0;
        }
      }
    }
  }

  bool _rowHasInvalidPicks(PunterSelection row) {
    if (row.picks.any((p) => p.player == null)) return true;

    final ids = row.picks.map((p) => p.player!.id).toList();
    return ids.toSet().length != ids.length;
  }

  // ---------------------------------------------------------------------------
  // COLUMN RESIZE
  // ---------------------------------------------------------------------------

  Widget _resizeHandle(VoidCallback onDrag) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        onDrag.call();
        setState(() {
          pickColWidth += details.delta.dx;
          if (pickColWidth < 110) pickColWidth = 110;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: Colors.transparent,
        ),
      ),
    );
  }

  Widget _resizeHandlePunter(VoidCallback onDrag) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        onDrag.call();
        setState(() {
          punterColWidth += details.delta.dx;
          if (punterColWidth < 90) punterColWidth = 90;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: Colors.transparent,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  void _saveSnapshot() {
    _history = _history.sublist(0, _historyIndex + 1);
    _history.add(_TableSnapshot.fromSelections(widget.selections));
    _historyIndex = _history.length - 1;
  }

  void _restoreSnapshot(int index) {
    if (index < 0 || index >= _history.length) return;

    final snap = _history[index];
    setState(() {
      snap.applyTo(widget.selections);
      _historyIndex = index;
    });
    widget.onChanged?.call();();
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
// BUILD
// ---------------------------------------------------------------------------

@override
Widget build(BuildContext context) {
  _cleanInvalidSelections();

  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  final visible = widget.selections.take(_punterCount).toList();

  final minWidth =
      punterColWidth + _roundCount * pickColWidth + totalColWidth;

  return LayoutBuilder(
    builder: (context, constraints) {
      final tableWidth =
          constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
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
              // HEADER (Undo/Redo removed)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Stack(
                    children: [
                      _buildHeaderRow(theme),
                      // Undo/Redo removed
                    ],
                  ),
                ),
              ),

              Divider(height: 1, thickness: 1, color: cs.outlineVariant),

              // BODY
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: ListView.builder(
                      controller: _verticalScrollController,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final row = visible[index];
                        final isStriped = index.isOdd;
                        final invalid = _rowHasInvalidPicks(row);

                        Color bg;
                        if (invalid) {
                          bg = Colors.red.withOpacity(0.06);
                        } else if (isStriped) {
                          bg = cs.surfaceVariant.withOpacity(0.25);
                        } else {
                          bg = cs.surface;
                        }

                        return Container(
                          height: rowHeight,
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border(
                              bottom: BorderSide(
                                color: cs.outlineVariant.withOpacity(0.6),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              _punterCell(context, row),
                              _resizeHandlePunter(() {}),

                              for (final pick in row.picks) ...[
                                _pickCell(context, row, pick),
                                _resizeHandle(() {}),
                              ],

                              _totalCell(context, row),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// HEADER
// ---------------------------------------------------------------------------

Widget _buildHeaderRow(ThemeData theme) {
  final cs = theme.colorScheme;

  return Container(
    height: headerHeight,
    decoration: BoxDecoration(
      color: cs.surfaceVariant.withOpacity(0.9),
      border: Border(
        bottom: BorderSide(
          color: cs.outlineVariant.withOpacity(0.7),
          width: 0.75,
        ),
      ),
    ),
    child: Row(
      children: [
        _headerCell(theme, "Punter", punterColWidth),
        _resizeHandlePunter(() {}),

        for (int i = 0; i < _roundCount; i++) ...[
          _headerCell(theme, "Pick", pickColWidth),
          _resizeHandle(() {}),
        ],

        _headerCell(theme, "Total", totalColWidth, alignCenter: true),
      ],
    ),
  );
}

Widget _headerCell(
  ThemeData theme,
  String text,
  double width, {
  bool alignCenter = false,
}) {
  return Container(
    width: width,
    alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}

  // ---------------------------------------------------------------------------
  // CELLS
  // ---------------------------------------------------------------------------

  Widget _punterCell(BuildContext context, PunterSelection row) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final controller = _controllers[row.punterNumber]!;

    return Container(
      width: punterColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: TextField(
        enabled: !widget.isCompleted,
        controller: controller,
        onChanged: (value) {
          row.punterName = value;
          widget.onChanged?.call();();
          _saveSnapshot();
        },
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          hintText: "P${row.punterNumber}",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _pickCell(
  BuildContext context,
  PunterSelection visualRow,
  PlayerPick pick,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  if (_loadingPlayers) {
    return Container(
      width: pickColWidth,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  final visualRowIndex = visualRow.punterNumber - 1;
  final colIndex = pick.pickNumber - 1;

  final owner = widget.selections[visualRowIndex];

  final globalPickNumber = _globalPickNumberForCell(
    rowIndex: visualRowIndex,
    colIndex: colIndex,
  );

  final globalTaken = _allSelectedPlayerIdsExcept(owner);
  final selectedPlayer = owner.picks[colIndex].player;

  // 🔥 Clubs involved in the fixture (full names like "Adelaide Crows")
  final allowedClubs = widget.availablePlayers
      .map((p) => p.club)
      .toSet();
print("DEBUG clubs:");
print("availablePlayers clubs: ${widget.availablePlayers.map((p) => p.club).toSet()}");
print("players clubs: ${_players.map((p) => p.club).toSet()}");

  // 🔥 Filter players:
  // - Must be from allowed clubs
  // - Must not be taken by other punters
  // - Except allow the currently selected player
  final filteredPlayers = _players.where((p) {
    final isAllowedClub = allowedClubs.contains(p.club);
    final isTaken = globalTaken.contains(p.id);
    final isCurrent = p == selectedPlayer;
    return isAllowedClub && (!isTaken || isCurrent);
  }).toList();

  final isCurrent = _isCurrentPick(visualRow, pick);

  final hintText = selectedPlayer == null
      ? "P$globalPickNumber"
      : selectedPlayer.shortName;

  return Container(
    width: pickColWidth,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: isCurrent ? Colors.yellow.shade100 : Colors.transparent,
    ),
    child: DropdownSearch<AflPlayer>(
      enabled: !widget.isCompleted,
      selectedItem: selectedPlayer,
      items: filteredPlayers,
      itemAsString: (p) => p.shortName,
      dropdownBuilder: (context, player) {
        if (player == null) {
          return Text(
            hintText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          );
        }
        final colours = _getTeamColoursForPlayer(player);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colours["bg"]?.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            player.shortName,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colours["fg"],
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
      popupProps: PopupProps.menu(
        showSearchBox: true,
        fit: FlexFit.loose,
        searchFieldProps: TextFieldProps(
          decoration: const InputDecoration(
            hintText: "Search players...",
            isDense: true,
            contentPadding: EdgeInsets.all(8),
          ),
        ),
        itemBuilder: (context, player, isSelected) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.4)
                : Colors.transparent,
            child: Text(
              player.shortName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
      ),
      onChanged: (value) {
        owner.picks[colIndex].player = value;
        owner.picks[colIndex].score = value?.fantasyScore ?? 0;
        widget.onChanged?.call();();
        setState(() {
          _saveSnapshot();
        });
        _scrollToCurrentPick();
      },
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
      width: totalColWidth,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.06),
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
}

// -----------------------------------------------------------------------------
// SNAPSHOT MODEL
// -----------------------------------------------------------------------------

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
                    score: p.score,
                  ),
                )
                .toList(),
          )
          .toList(),
    );
  }

  void applyTo(List<PunterSelection> selections) {
    for (int i = 0; i < selections.length; i++) {
      final row = selections[i];

      if (i < punterNames.length) {
        row.punterName = punterNames[i];
      }

      if (i < picks.length) {
        final rowPicks = picks[i];

        for (int j = 0; j < row.picks.length && j < rowPicks.length; j++) {
          final snapPick = rowPicks[j];
          final pick = row.picks[j];

          if (snapPick.playerId == null) {
            pick.player = null;
            pick.score = 0;
          } else {
            // We restore only score because we cannot reconstruct the player
            // object without a global lookup. The UI will refresh correctly.
            pick.score = snapPick.score;
          }
        }
      }
    }
  }
}

class _PickSnapshot {
  final String? playerId;
  final int score;

  _PickSnapshot({
    required this.playerId,
    required this.score,
  });
}