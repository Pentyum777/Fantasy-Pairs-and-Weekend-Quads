import 'package:flutter/material.dart';

import '../helpers/round_helper.dart';

import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../models/afl_fixture.dart';

import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/punter_score_service.dart';
import '../services/championship_service.dart';
import '../services/round_completion_service.dart';
import '../services/user_role_service.dart';

import '../widgets/team_logo.dart';
import 'game_view_screen.dart';

class CustomPairsBuilderScreen extends StatefulWidget {
  final int season;
  final int? round;

  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;
  final ChampionshipService championshipService;
  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;

  const CustomPairsBuilderScreen({
    super.key,
    required this.season,
    required this.round,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.fantasyService,
    required this.championshipService,
    required this.roundCompletionService,
    required this.userRoleService,
  });

  @override
  State<CustomPairsBuilderScreen> createState() =>
      _CustomPairsBuilderScreenState();
}

class _CustomPairsBuilderScreenState extends State<CustomPairsBuilderScreen> {
  final Set<String> _selectedFixtureIds = {};

  @override
  Widget build(BuildContext context) {
    final fixtures = widget.round == null
        ? widget.fixtureRepo.preseasonFixturesForSeason(widget.season)
        : widget.fixtureRepo.fixturesForSeasonRound(
            widget.season,
            widget.round!,
          );

    final roundLabel = RoundHelper.label(widget.round);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Pairs Builder"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Select fixtures for $roundLabel",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // FIXTURE LIST
                Expanded(
                  child: ListView.builder(
                    itemCount: fixtures.length,
                    itemBuilder: (context, index) {
                      final f = fixtures[index];
                      final fixtureId = f.matchId ?? index.toString();
                      final selected = _selectedFixtureIds.contains(fixtureId);
                      final label = _buildFixtureLabel(index, f.date);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.userRoleService.isAdmin
                              ? () {
                                  setState(() {
                                    selected
                                        ? _selectedFixtureIds.remove(fixtureId)
                                        : _selectedFixtureIds.add(fixtureId);
                                  });
                                }
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),

                              // ⭐ Correct alpha handling
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha(20) // 0.08 opacity
                                  : Theme.of(context).colorScheme.surface,

                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade400,
                                width: selected ? 2 : 1,
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13), // 0.05 opacity
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                TeamLogo(f.homeTeam, size: 34),
                                const SizedBox(width: 12),

                                // LABEL
                                Expanded(
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),
                                TeamLogo(f.awayTeam, size: 34),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // START BUTTON
                ElevatedButton(
                  onPressed: widget.userRoleService.isAdmin &&
                          _selectedFixtureIds.isNotEmpty
                      ? () => _startCustomPairs(context, fixtures)
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text(
                    "Start Custom Pairs",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startCustomPairs(BuildContext context, List<AflFixture> fixtures) {
    final selectedFixtures = fixtures.where((f) {
      final id = f.matchId ?? fixtures.indexOf(f).toString();
      return _selectedFixtureIds.contains(id);
    }).toList();

    final clubs = <String>{};
    for (final f in selectedFixtures) {
      clubs.add(f.homeTeam);
      clubs.add(f.awayTeam);
    }

    final players = widget.playerRepo.players
        .where((p) => clubs.contains(p.club))
        .toList();

    final selections = List.generate(
      25,
      (i) => PunterSelection(
        punterNumber: i + 1,
        punterName: "P${i + 1}",
        picks: [
          PlayerPick(pickNumber: 1, player: null, stats: null),
          PlayerPick(pickNumber: 2, player: null, stats: null),
        ],
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          season: widget.season,
          round: widget.round,
          gameType: "custom_pairs",
          selections: selections,
          fixtureRepo: widget.fixtureRepo,
          playerRepo: widget.playerRepo,
          fantasyService: widget.fantasyService,
          championshipService: widget.championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService: widget.userRoleService,
          selectedFixtureIds: _selectedFixtureIds.toList(),
          overridePlayers: players,
        ),
      ),
    );
  }

  String _buildFixtureLabel(int index, DateTime? date) {
    final gameNumber = index + 1;

    if (date == null) return "Game $gameNumber – Time TBC";

    final local = date.toLocal();
    final day = _weekday(local.weekday);
    final time = _formatTime(local);

    return "Game $gameNumber – $day $time";
  }

  String _weekday(int w) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[w - 1];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $ampm";
  }
}