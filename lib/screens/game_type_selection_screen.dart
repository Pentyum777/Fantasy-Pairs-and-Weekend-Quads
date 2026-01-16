import 'package:flutter/material.dart';

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

class GameTypeSelectionScreen extends StatefulWidget {
  final int? round;
  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;

  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;

  const GameTypeSelectionScreen({
    super.key,
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
  late List<PunterSelection> preseasonPairsSelections;
  late List<PunterSelection> thursdayPairsSelections;
  late List<PunterSelection> fridayPairsSelections;
  late List<PunterSelection> saturdayPairsSelections;
  late List<PunterSelection> sundayPairsSelections;
  late List<PunterSelection> mondayPairsSelections;
  late List<PunterSelection> weekendQuadsSelections;

  final ChampionshipService championshipService = ChampionshipService();

  @override
  void initState() {
    super.initState();

    preseasonPairsSelections = _createEmptySelections(2);

    thursdayPairsSelections = _createEmptySelections(2);
    fridayPairsSelections = _createEmptySelections(2);
    saturdayPairsSelections = _createEmptySelections(2);
    sundayPairsSelections = _createEmptySelections(2);
    mondayPairsSelections = _createEmptySelections(2);

    weekendQuadsSelections = _createEmptySelections(4);
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
            score: 0,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OPEN GAME
  // ---------------------------------------------------------------------------
  void _openGame(String type) {
    // Championship
    if (type == "championship") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChampionshipScreen(service: championshipService),
        ),
      );
      return;
    }

    // Custom Pairs Builder
    if (type == "custom_pairs") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomPairsBuilderScreen(
            round: widget.round!,
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

    // -----------------------------------------------------------------------
    // PRE-SEASON PAIRS
    // -----------------------------------------------------------------------
    if (type == "preseason_pairs") {
      final preseason = widget.fixtureRepo.preseasonFixtures();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameViewScreen(
            round: -1, // special round
            gameType: "preseason_pairs",
            selections: preseasonPairsSelections,
            fixtureRepo: widget.fixtureRepo,
            playerRepo: widget.playerRepo,
            fantasyService: widget.fantasyService,
            championshipService: championshipService,
            roundCompletionService: widget.roundCompletionService,
            userRoleService: widget.userRoleService,
            selectedFixtureIds: preseason
                .where((f) => f.matchId != null && f.matchId!.isNotEmpty)
                .map((f) => f.matchId!)
                .toList(),
          ),
        ),
      );
      return;
    }

    // -----------------------------------------------------------------------
    // NORMAL GAME TYPES
    // -----------------------------------------------------------------------
    late List<PunterSelection> selections;

    switch (type) {
      case "thursday_pairs":
        selections = thursdayPairsSelections;
        break;
      case "friday_pairs":
        selections = fridayPairsSelections;
        break;
      case "saturday_pairs":
        selections = saturdayPairsSelections;
        break;
      case "sunday_pairs":
        selections = sundayPairsSelections;
        break;
      case "monday_pairs":
        selections = mondayPairsSelections;
        break;
      case "weekend_quads":
        selections = weekendQuadsSelections;
        break;
      default:
        selections = weekendQuadsSelections;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          round: widget.round ?? -1,
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

  @override
  Widget build(BuildContext context) {
    final gameTypes = [
      "preseason_pairs",
      "thursday_pairs",
      "friday_pairs",
      "saturday_pairs",
      "sunday_pairs",
      "monday_pairs",
      "weekend_quads",
      "custom_pairs",
      "championship",
    ];

    String shortLabel(String type) {
      switch (type) {
        case "preseason_pairs":
          return "Pre‑Season Pairs";
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
        case "custom_pairs":
          return "Custom Pairs Builder";
        case "championship":
          return "The Championship";
        default:
          return type;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Round ${widget.round} – Select Game Type"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemCount: gameTypes.length,
            itemBuilder: (context, i) {
              final type = gameTypes[i];

              return GestureDetector(
                onTap: () => _openGame(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Text(
                    shortLabel(type),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}