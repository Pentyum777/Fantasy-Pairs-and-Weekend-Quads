import 'dart:async';
import 'package:flutter/material.dart';

import 'repositories/fixture_repository.dart';
import 'repositories/player_repository.dart';
import 'services/punter_score_service.dart';
import 'services/round_completion_service.dart';
import 'services/user_role_service.dart';

import 'screens/round_selection_screen.dart';
import 'screens/game_type_selection_screen.dart';
import 'screens/season_selection_screen.dart';
import 'screens/login_screen.dart';

import 'debug/afl_data_validator.dart';

void main() {
  print("🔥 MAIN EXECUTED — WINDOWS/MOBILE VERSION");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;

  int selectedSeason = 2026;

  late final FixtureRepository fixtureRepo;
  late final PlayerRepository playerRepo;
  late final PunterScoreService fantasyService;

  final RoundCompletionService roundCompletionService = RoundCompletionService();
  final UserRoleService userRoleService = UserRoleService();

  Future<void>? _fixtureLoadFuture;

  @override
  void initState() {
    super.initState();

    fixtureRepo = FixtureRepository();
    playerRepo = PlayerRepository();
    fantasyService = PunterScoreService();

    // Load all players for both seasons
    playerRepo.loadAllPlayers();
  }

  Future<void> _loadAllFixtures() async {
    await fixtureRepo.loadFixturesFromExcelFile('assets/afl_fixtures_2026.xlsx');
    await fixtureRepo.loadFixturesFromExcelFile('assets/afl_fixtures_2025_round_24.xlsx');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AFL App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/stadium_glow.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: _token == null
            ? LoginScreen(
                onLoggedIn: () {
                  // Local login for Windows/mobile
                  userRoleService.setUser("wpenfold@bigpond.net.au");

                  setState(() {
                    _token = "local-login";
                    _fixtureLoadFuture = _loadAllFixtures();
                  });
                },
              )
            : FutureBuilder(
                future: _fixtureLoadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Validate fixture + player data
                  validateAflData(
  fixtureRepo: fixtureRepo,
  playerRepo: playerRepo,
  season: selectedSeason,
);


                  return SeasonSelectionScreen(
                    seasons: const [2025, 2026],
                    onSelect: (season) {
                      setState(() => selectedSeason = season);

                      final rounds = <int?>[];

                      if (fixtureRepo.preseasonFixturesForSeason(season).isNotEmpty) {
                        rounds.add(null);
                      }

                      rounds.addAll(fixtureRepo.allRoundsForSeason(season));

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoundSelectionScreen(
                            rounds: rounds,
                            completedRounds: roundCompletionService.completedRounds,
                            onRoundSelected: (round) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameTypeSelectionScreen(
                                    season: season,
                                    round: round,
                                    fixtureRepo: fixtureRepo,
                                    playerRepo: playerRepo,
                                    fantasyService: fantasyService,
                                    roundCompletionService: roundCompletionService,
                                    userRoleService: userRoleService,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}