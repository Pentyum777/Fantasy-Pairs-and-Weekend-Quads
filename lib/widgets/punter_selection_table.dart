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

  final void Function()? onChanged;
  final bool readOnly;

  const PunterSelectionTable({
    super.key,
    required this.visiblePunterCount,
    required this.playersPerPunter,
    required this.availablePlayers,
    required this.selections,
    required this.isCompleted,
    this.onChanged,
    required this.readOnly,
  });

  @override
  State<PunterSelectionTable> createState() => _PunterSelectionTableState();
}

class _PunterSelectionTableState extends State<PunterSelectionTable> {
  // ---------------------------------------------------------------------------
  // LAYOUT CONSTANTS
  // ---------------------------------------------------------------------------
  static const double rowHeight = 34.0;
  static const double headerHeight = 26.0;

  double punterColWidth = 80.0;
  double pickColWidth = 185.0; // widened
  static const double totalColWidth = 40.0;

  // ---------------------------------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------------------------------
  final Map<int, TextEditingController> _controllers = {};
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final Map<int, FocusNode> _punterFocusNodes = {};

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------
  List<_TableSnapshot> _history = [];
  int _historyIndex = -1;

  // ---------------------------------------------------------------------------
  // PLAYER LIST
  // ---------------------------------------------------------------------------
  List<AflPlayer> _players = [];
  bool _loadingPlayers = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initFocusNodes();
    _loadPlayers();
    _saveSnapshot();
  }

  @override
  void didUpdateWidget(covariant PunterSelectionTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initControllers();
    _initFocusNodes();
  }

  // ---------------------------------------------------------------------------
  // INIT CONTROLLERS
  // ---------------------------------------------------------------------------
  void _initControllers() {
    for (final row in widget.selections) {
      _controllers[row.punterNumber] ??=
          TextEditingController(text: row.punterName);
    }
  }

  // ---------------------------------------------------------------------------
  // INIT FOCUS NODES
  // ---------------------------------------------------------------------------
  void _initFocusNodes() {
    for (final row in widget.selections) {
      _punterFocusNodes[row.punterNumber] ??= FocusNode();
    }
  }

  // ---------------------------------------------------------------------------
  // RESPONSIVE
  // ---------------------------------------------------------------------------
  bool get _isMobile {
    final width = MediaQuery.of(context).size.width;
    return width < 700;
  }

  // ---------------------------------------------------------------------------
  // CLUB CODE MAP
  // ---------------------------------------------------------------------------
  static const Map<String, String> _clubCodeMap = {
    "Adelaide Crows": "ADE",
    "Brisbane Lions": "BRI",
    "Carlton": "CAR",
    "Collingwood": "COL",
    "Essendon": "ESS",
    "Fremantle": "FRE",
    "Geelong Cats": "GEE",
    "Gold Coast Suns": "GCS",
    "GWS Giants": "GWS",
    "Hawthorn": "HAW",
    "Melbourne": "MEL",
    "North Melbourne": "NTH",
    "Port Adelaide": "PTA",
    "Richmond": "RIC",
    "St Kilda": "STK",
    "Sydney Swans": "SYD",
    "West Coast Eagles": "WCE",
    "Western Bulldogs": "WB",
  };

  // ---------------------------------------------------------------------------
  // LOAD PLAYERS
  // ---------------------------------------------------------------------------
  Future<void> _loadPlayers() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/afl_players_2026.json');

      final List<dynamic> data = json.decode(jsonString);
      final List<AflPlayer> parsed = [];

      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;

        final rawName = (raw['name'] ?? raw['id'] ?? '').toString().trim();
        if (rawName.isEmpty) continue;

        final clubRaw = (raw['club'] ?? '').toString().trim();
        final clubCode = _clubCodeMap[clubRaw] ?? clubRaw;

        final numberRaw = raw['guernseyNumber'] ?? raw['number'] ?? 0;
        final guernsey = int.tryParse(numberRaw.toString()) ?? 0;

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

  // ---------------------------------------------------------------------------
  // PICK LABELS
  // ---------------------------------------------------------------------------
  List<String> _pickLabels() =>
      List.generate(_roundCount, (i) => 'P${i + 1}');

  int get _punterCount => widget.visiblePunterCount;
  int get _roundCount => widget.playersPerPunter;
    // ---------------------------------------------------------------------------
  // HEADER ROW
  // ---------------------------------------------------------------------------
  Widget _buildHeaderRow(ThemeData theme) {
    final cs = theme.colorScheme;
    final labels = _pickLabels();

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
          _headerCell(theme, "Punter", punterColWidth, alignCenter: true),
          if (!_isMobile) _resizeHandlePunter(() {}),

          for (final label in labels) ...[
            _headerCell(theme, label, pickColWidth, alignCenter: true),
            if (!_isMobile) _resizeHandle(() {}),
          ],

          _headerCell(theme, "T", totalColWidth, alignCenter: true),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER CELL
  // ---------------------------------------------------------------------------
  Widget _headerCell(
    ThemeData theme,
    String text,
    double width, {
    bool alignCenter = false,
  }) {
    return Container(
      width: width,
      alignment: alignCenter ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESIZE HANDLES
  // ---------------------------------------------------------------------------
  Widget _resizeHandle(VoidCallback onDrag) {
    if (_isMobile) return const SizedBox(width: 0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        onDrag.call();
        setState(() {
          pickColWidth += details.delta.dx;
          if (pickColWidth < 120) pickColWidth = 120;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(width: 3, color: Colors.transparent),
      ),
    );
  }

  Widget _resizeHandlePunter(VoidCallback onDrag) {
    if (_isMobile) return const SizedBox(width: 0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        onDrag.call();
        setState(() {
          punterColWidth += details.delta.dx;
          if (punterColWidth < 60) punterColWidth = 60;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(width: 3, color: Colors.transparent),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SNAKE DRAFT MAPPING
  // ---------------------------------------------------------------------------
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
  // GLOBAL UNIQUENESS
  // ---------------------------------------------------------------------------
  void _cleanInvalidSelectionsGlobal() {
    final seen = <String>{};

    for (final row in widget.selections) {
      for (final pick in row.picks) {
        final p = pick.player;
        if (p == null) continue;

        if (seen.contains(p.id)) {
          pick.player = null;
          pick.score = 0;
        } else {
          seen.add(p.id);
        }
      }
    }
  }

  bool _hasAnyGlobalDuplicate() {
    final ids = <String>[];

    for (final row in widget.selections) {
      for (final pick in row.picks) {
        if (pick.player != null) ids.add(pick.player!.id);
      }
    }

    return ids.length != ids.toSet().length;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    _cleanInvalidSelectionsGlobal();

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
                // HEADER
                SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: _buildHeaderRow(theme),
                  ),
                ),

                Divider(height: 1, thickness: 1, color: cs.outlineVariant),

                // BODY
                Expanded(
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: ListView.builder(
                        controller: _verticalScrollController,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final row = visible[index];
                          final isStriped = index.isOdd;
                          final invalid = _hasAnyGlobalDuplicate();

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

      if (!_isMobile) _resizeHandlePunter(() {}),

      for (final pick in row.picks) ...[
        _pickCell(context, row, pick),
        if (!_isMobile) _resizeHandle(() {}),
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
  // PUNTER CELL (LEFT‑ALIGNED)
  // ---------------------------------------------------------------------------
  Widget _punterCell(BuildContext context, PunterSelection row) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final controller = _controllers[row.punterNumber]!;
    final focusNode = _punterFocusNodes[row.punterNumber]!;

    return Container(
      width: punterColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.centerLeft,
      child: TextField(
        enabled: !widget.isCompleted,
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.left,
        onChanged: (value) {
          row.punterName = value;
          widget.onChanged?.call();
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

  // ---------------------------------------------------------------------------
  // PICK CELL (GLOBAL UNIQUENESS + HIDE ARROW WHEN SELECTED)
  // ---------------------------------------------------------------------------
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

    // Build global taken set, excluding this exact pick
    final globalTaken = <String>{};
    for (final row in widget.selections) {
      for (int i = 0; i < row.picks.length; i++) {
        final p = row.picks[i].player;
        if (p == null) continue;

        if (identical(row, owner) && i == colIndex) continue;

        globalTaken.add(p.id);
      }
    }

    final selectedPlayer = owner.picks[colIndex].player;

    // Fixture-driven allowed clubs: passed in via availablePlayers
    final allowedClubs = widget.availablePlayers.map((p) => p.club).toSet();

    final filteredPlayers = _players.where((p) {
      final isAllowedClub = allowedClubs.contains(p.club);
      final isTaken = globalTaken.contains(p.id);
      final isCurrent = p == selectedPlayer;
      return isAllowedClub && (!isTaken || isCurrent);
    }).toList();

    final isCurrentPick = _isCurrentPick(visualRow, pick);

    final globalPickNumber = _globalPickNumberForCell(
      rowIndex: visualRowIndex,
      colIndex: colIndex,
    );

    final hintText = selectedPlayer == null
        ? "P$globalPickNumber"
        : selectedPlayer.shortName;

    return Container(
      width: pickColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center, // vertical centering
      decoration: BoxDecoration(
        color: isCurrentPick ? cs.primary.withOpacity(0.08) : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownSearch<AflPlayer>(
              enabled: !widget.isCompleted,
              selectedItem: selectedPlayer,
              items: filteredPlayers,
              itemAsString: (p) => p.shortName,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  suffixIcon: selectedPlayer == null
                      ? const Icon(Icons.arrow_drop_down)
                      : null, // hide arrow when selected
                ),
              ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              ),
              onChanged: (value) {
                owner.picks[colIndex].player = value;
                owner.picks[colIndex].score = value?.fantasyScore ?? 0;
                widget.onChanged?.call();
                setState(() {
                  _saveSnapshot();
                });
                _scrollToCurrentPick();
              },
            ),
          ),

          // SCORE DISPLAY
          if (selectedPlayer != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                "${pick.score}",
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
        ],
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
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
  // HISTORY SNAPSHOT MODEL
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
      snap.applyTo(widget.selections, _players);
      _historyIndex = index;
    });
    widget.onChanged?.call();
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

  void applyTo(List<PunterSelection> selections, List<AflPlayer> allPlayers) {
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
            final restored =
                allPlayers.where((p) => p.id == snapPick.playerId);
            pick.player = restored.isNotEmpty ? restored.first : null;
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