import 'package:flutter/material.dart';

import '../constants/ui_dimensions.dart';
import '../models/afl_player.dart';
import '../models/afl_player_match_stats.dart';
import '../models/punter_selection.dart';
import '../services/punter_score_service.dart';
import '../services/user_role_service.dart';
import '../theme/app_theme.dart';
import 'leaderboard_panel.dart';
import 'punter_selection_table.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScreenshotOverlay
//
// Full-screen modal overlay that scales the punter table + leaderboard to fit
// the device screen exactly, with no chrome, no scrollbars, and no controls.
//
// Usage — call from GameViewScreen:
//
//   ScreenshotOverlay.show(
//     context,
//     selections:        _selections,
//     sortedSelections:  _sortedSelections(),
//     visiblePunterCount: _visiblePunterCount,
//     gameType:          widget.gameType,
//     season:            widget.season,
//     round:             widget.round ?? 0,
//     availablePlayers:  availablePlayers,
//     allPlayers:        _seasonPlayers ?? [],
//     fantasyService:    widget.fantasyService,
//     userRoleService:   widget.userRoleService,
//     isPlayerCompleted: _isPlayerFromCompletedFixture,
//     showAveragePreview: _showAveragePreview,
//   );
// ─────────────────────────────────────────────────────────────────────────────

class ScreenshotOverlay extends StatelessWidget {
  final List<PunterSelection> selections;
  final List<PunterSelection> sortedSelections;
  final int                   visiblePunterCount;
  final String                gameType;
  final int                   season;
  final int                   round;
  final List<AflPlayer>       availablePlayers;
  final List<AflPlayer>       allPlayers;
  final PunterScoreService    fantasyService;
  final UserRoleService       userRoleService;
  final bool Function(AflPlayerMatchStats) isPlayerCompleted;
  final bool                  showAveragePreview;

  const ScreenshotOverlay({
    super.key,
    required this.selections,
    required this.sortedSelections,
    required this.visiblePunterCount,
    required this.gameType,
    required this.season,
    required this.round,
    required this.availablePlayers,
    required this.allPlayers,
    required this.fantasyService,
    required this.userRoleService,
    required this.isPlayerCompleted,
    required this.showAveragePreview,
  });

  // ── Static helper so callers don't need to instantiate directly ─────────────
  static void show(
    BuildContext context, {
    required List<PunterSelection> selections,
    required List<PunterSelection> sortedSelections,
    required int                   visiblePunterCount,
    required String                gameType,
    required int                   season,
    required int                   round,
    required List<AflPlayer>       availablePlayers,
    required List<AflPlayer>       allPlayers,
    required PunterScoreService    fantasyService,
    required UserRoleService       userRoleService,
    required bool Function(AflPlayerMatchStats) isPlayerCompleted,
    required bool                  showAveragePreview,
  }) {
    showDialog(
      context:           context,
      barrierColor:      Colors.black,
      barrierDismissible: true,
      builder: (_) => ScreenshotOverlay(
        selections:         selections,
        sortedSelections:   sortedSelections,
        visiblePunterCount: visiblePunterCount,
        gameType:           gameType,
        season:             season,
        round:              round,
        availablePlayers:   availablePlayers,
        allPlayers:         allPlayers,
        fantasyService:     fantasyService,
        userRoleService:    userRoleService,
        isPlayerCompleted:  isPlayerCompleted,
        showAveragePreview: showAveragePreview,
      ),
    );
  }

  // ── Layout constants (natural / unscaled render size) ───────────────────────
  //
  // We render the table at its natural desktop size inside a fixed-dimension
  // box, then let FittedBox shrink/grow it to fill the screen.  This means
  // we never have to manually calculate a scale factor.

  static const double _naturalTableWidth      = 900.0; // wide enough for picks
  static const double _naturalLeaderboardWidth =
      UIDimensions.rankColumnWidth +
      UIDimensions.punterNameColumnWidth +
      UIDimensions.totalColumnWidth;
  static const double _naturalRowHeight       = UIDimensions.rowHeight;
  static const double _naturalHeaderHeight    = UIDimensions.headerHeight;
  static const double _padding                = 12.0;

  double _naturalHeight(int punterCount) {
    return _naturalHeaderHeight +
        1 + // divider
        punterCount * _naturalRowHeight +
        _padding * 2;
  }

  double get _naturalWidth =>
      _naturalTableWidth + _naturalLeaderboardWidth + _padding * 3;

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final punterCount   = visiblePunterCount;
    final naturalH      = _naturalHeight(punterCount);
    final picks         = gameType == 'weekend_quads' ? 4 : 2;

    final leaderboardPunters =
        sortedSelections.take(punterCount).toList();

    return GestureDetector(
      // Tap anywhere outside the table to dismiss
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Centred, scaled table ──────────────────────────────────────
            Center(
              child: GestureDetector(
                // Swallow taps on the table itself so they don't dismiss
                onTap: () {},
                child: FittedBox(
                  fit:       BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width:  _naturalWidth,
                    height: naturalH,
                    child: _buildTableContent(
                      context, picks, leaderboardPunters, naturalH),
                  ),
                ),
              ),
            ),

            // ── Close button ───────────────────────────────────────────────
            Positioned(
              top:   MediaQuery.paddingOf(context).top + 8,
              right: 12,
              child: _CloseButton(onTap: () => Navigator.of(context).pop()),
            ),

            // ── Hint label ─────────────────────────────────────────────────
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              left:   0,
              right:  0,
              child: const Center(
                child: Text(
                  'Tap anywhere to close',
                  style: TextStyle(
                    color:    Colors.white38,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableContent(
    BuildContext context,
    int picks,
    List<PunterSelection> leaderboardPunters,
    double naturalH,
  ) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(_padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Punter selection table ───────────────────────────────────────
          SizedBox(
            width:  _naturalTableWidth,
            height: naturalH - _padding * 2,
            child: PunterSelectionTable(
              gameType:           gameType,
              season:             season,
              round:              round,
              tableWidth:         _naturalTableWidth,
              visiblePunterCount: visiblePunterCount,
              playersPerPunter:   picks,
              availablePlayers:   availablePlayers,
              selections:         selections,
              isCompleted:        true,   // read-only — no edit controls
              readOnly:           true,
              collapsed:          false,
              scrollController:   null,
              fantasyService:     fantasyService,
              userRoleService:    userRoleService,
              allPlayers:         allPlayers,
              showAveragePreview: showAveragePreview,
              isPlayerCompleted:  isPlayerCompleted,
            ),
          ),

          const SizedBox(width: _padding),

          // ── Leaderboard ──────────────────────────────────────────────────
          SizedBox(
            width:  _naturalLeaderboardWidth,
            height: naturalH - _padding * 2,
            child: LeaderboardPanel(
              punters:            leaderboardPunters,
              rowHeight:          _naturalRowHeight,
              collapsed:          false,
              showAveragePreview: showAveragePreview,
              allPlayers:         allPlayers,
              // No collapse toggle in screenshot mode
              onCollapseChanged:  null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CloseButton
// ─────────────────────────────────────────────────────────────────────────────
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  36,
        height: 36,
        decoration: BoxDecoration(
          color:        AppTheme.surfaceCard.withOpacity(0.85),
          shape:        BoxShape.circle,
          border:       Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.close,
          color: AppTheme.textPrimary,
          size:  18,
        ),
      ),
    );
  }
}
