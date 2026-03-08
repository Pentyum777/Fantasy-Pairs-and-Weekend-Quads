import 'package:flutter/material.dart';

import '../helpers/round_helper.dart';

import '../models/punter_selection.dart';
import '../models/player_pick.dart';

import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/punter_score_service.dart';
import '../services/championship_service.dart';
import '../services/round_completion_service.dart';
import '../services/user_role_service.dart';

import '../screens/game_view_screen.dart';
import 'championship_screen.dart';
import 'custom_pairs_builder_screen.dart';

import '../widgets/background_container.dart';

class GameTypeSelectionScreen extends StatefulWidget {
  final int season;
  final int? round;

  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;

  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;

  const GameTypeSelectionScreen({
    super.key,
    required this.season,
    required this.round,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.fantasyService,
    required this.roundCompletionService,
    required this.userRoleService,
  });

  @override
  State<GameTypeSelectionScreen> createState() =>
      _GameTypeSelectionScreenState();
}

class _GameTypeSelectionScreenState extends State<GameTypeSelectionScreen> {
  final Map<String, List<PunterSelection>> _selectionCache = {};
  final ChampionshipService championshipService = ChampionshipService();

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
  }

  List<PunterSelection> _createEmptySelections(int playersPerPunter) {
    return List.generate(
      25,
      (i) => PunterSelection(
        punterNumber: i + 1,
        punterName: "P${i + 1}",
        picks: List.generate(
          playersPerPunter,
          (j) => PlayerPick(
            pickNumber: j + 1,
            player: null,
            stats: null,
          ),
        ),
      ),
    );
  }

  List<PunterSelection> _getSelectionsForGameType(String type) {
    final key = "${widget.season}-${widget.round}-$type";

    if (_selectionCache.containsKey(key)) {
      return _selectionCache[key]!;
    }

    final playersPerPunter = type == "weekend_quads" ? 4 : 2;

    final newList = _createEmptySelections(playersPerPunter);
    _selectionCache[key] = newList;
    return newList;
  }

  void _openGame(String type) {
    // ------------------------------------------------------------
    // NEW: Custom Builder (admin only)
    // ------------------------------------------------------------
    if (type == "custom_builder") {
      if (!widget.userRoleService.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admins only")),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomPairsBuilderScreen(
            season: widget.season,
            round: widget.round,
            fixtureRepo: widget.fixtureRepo,
            playerRepo: widget.playerRepo,
            fantasyService: widget.fantasyService,
            championshipService: championshipService,
            roundCompletionService: widget.roundCompletionService,
            userRoleService: widget.userRoleService,
          ),
        ),
      );
      return;
    }

    // ------------------------------------------------------------
    // NEW: Custom Game (everyone can view)
    // ------------------------------------------------------------
    if (type == "custom_game") {
      final selections = _getSelectionsForGameType("custom_game");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameViewScreen(
            season: widget.season,
            round: widget.round,
            gameType: "custom_game",
            selections: selections,
            fixtureRepo: widget.fixtureRepo,
            playerRepo: widget.playerRepo,
            fantasyService: widget.fantasyService,
            championshipService: championshipService,
            roundCompletionService: widget.roundCompletionService,
            userRoleService: widget.userRoleService,
          ),
        ),
      );
      return;
    }

    // ------------------------------------------------------------
    // Championship
    // ------------------------------------------------------------
    if (type == "championship") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChampionshipScreen(service: championshipService),
        ),
      );
      return;
    }

    // ------------------------------------------------------------
    // Normal game types
    // ------------------------------------------------------------
    final selections = _getSelectionsForGameType(type);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          season: widget.season,
          round: widget.round,
          gameType: type,
          selections: selections,
          fixtureRepo: widget.fixtureRepo,
          playerRepo: widget.playerRepo,
          fantasyService: widget.fantasyService,
          championshipService: championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService: widget.userRoleService,
        ),
      ),
    );
  }

  Widget buildProTile({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool mobile = isPortraitPhone(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mobile ? 14 : 20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: mobile ? 8 : 14,
            horizontal: mobile ? 6 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mobile ? 14 : 22),
            color: Colors.grey.shade900.withAlpha((255 * 0.15).round()),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.18).round()),
                blurRadius: mobile ? 4 : 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade300.withAlpha((255 * 0.6).round()),
              width: mobile ? 1.1 : 1.4,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: mobile ? 12 : 16,
                color: Colors.grey.shade100,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------
    // UPDATED: Added custom_builder + custom_game
    // ------------------------------------------------------------
    final gameTypes = [
      "thursday_pairs",
      "friday_pairs",
      "saturday_pairs",
      "sunday_pairs",
      "monday_pairs",
      "weekend_quads",
      "custom_builder",   // ⭐ NEW
      "custom_game",      // ⭐ NEW
      "championship",
    ];

    String shortLabel(String type) {
      switch (type) {
        case "thursday_pairs":
          return "Thursday Pairs";
        case "friday_pairs":
          return "Friday Pairs";
        case "saturday_pairs":
          return "Saturday Pairs";
        case "sunday_pairs":
          return "Sunday Pairs";
        case "monday_pairs":
          return "Monday Pairs";
        case "weekend_quads":
          return "Weekend Quads";
        case "custom_builder":
          return "Custom Builder";     // ⭐ NEW
        case "custom_game":
          return "Custom Game";        // ⭐ NEW
        case "championship":
          return "The Championship";
        default:
          return type;
      }
    }

    final String roundLabel = RoundHelper.label(widget.round);
    final bool mobile = isPortraitPhone(context);

    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("$roundLabel – Select Game Type"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: mobile ? 2 : 3,
                mainAxisSpacing: mobile ? 10 : 16,
                crossAxisSpacing: mobile ? 10 : 16,
                childAspectRatio: mobile ? 2.2 : 2.6,
              ),
              itemCount: gameTypes.length,
              itemBuilder: (context, i) {
                final type = gameTypes[i];

                return buildProTile(
                  context: context,
                  label: shortLabel(type),
                  onTap: () => _openGame(type),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}