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
  /// Stores selections for ALL game types, keyed by:
  /// "season-round-gameType"
  final Map<String, List<PunterSelection>> _selectionCache = {};

  final ChampionshipService championshipService = ChampionshipService();

  @override
  void initState() {
    super.initState();
  }

  /// Creates a new empty selection list (only if not already cached)
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

  /// Returns a stable, persistent selection list for the given game type.
  List<PunterSelection> _getSelectionsForGameType(String type) {
    final key = "${widget.season}-${widget.round}-$type";

    if (_selectionCache.containsKey(key)) {
      return _selectionCache[key]!;
    }

    // Create new only once
    final playersPerPunter =
        type == "weekend_quads" ? 4 : 2;

    final newList = _createEmptySelections(playersPerPunter);
    _selectionCache[key] = newList;
    return newList;
  }

  void _openGame(String type) {
    if (type == "championship") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChampionshipScreen(service: championshipService),
        ),
      );
      return;
    }

    if (type == "custom_pairs") {
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

    final selections = _getSelectionsForGameType(type);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          season: widget.season,
          round: widget.round,
          gameType: type,
          selections: selections, // persistent list
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

    final String roundLabel = RoundHelper.label(widget.round);

    return Scaffold(
      appBar: AppBar(
        title: Text("$roundLabel – Select Game Type"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.6,
            ),
            itemCount: gameTypes.length,
            itemBuilder: (context, i) {
              final type = gameTypes[i];

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _openGame(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.6,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        shortLabel(type),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
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