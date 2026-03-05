import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'services/msal_service.dart';
import 'repositories/fixture_repository.dart';
import 'repositories/player_repository.dart';
import 'services/punter_score_service.dart';
import 'services/round_completion_service.dart';
import 'services/user_role_service.dart';

import 'screens/round_selection_screen.dart';
import 'screens/game_type_selection_screen.dart';
import 'screens/season_selection_screen.dart';

import 'debug/afl_data_validator.dart';

void main() {
  print("🔥 MAIN EXECUTED — ${kIsWeb ? "WEB" : "WINDOWS/MOBILE"} VERSION");
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

  bool _loggingIn = false; // prevents double-tap on login

  @override
  void initState() {
    super.initState();

    fixtureRepo = FixtureRepository();
    playerRepo = PlayerRepository();
    fantasyService = PunterScoreService();

    playerRepo.loadAllPlayers();

    if (kIsWeb) {
      MsalService.listenForToken((token, account) {
        if (!mounted) return;

        final email = account.username;
        print("MSAL(Dart): Logged in as $email");

        userRoleService.setUser(email);

        setState(() {
          _token = token;
          _fixtureLoadFuture = _loadAllFixtures();
        });
      });
    }
  }

  Future<void> _loadAllFixtures() async {
    await fixtureRepo.loadFixturesFromExcelFile('assets/afl_fixtures_2026.xlsx');
    await fixtureRepo.loadFixturesFromExcelFile('assets/afl_fixtures_2025_round_24.xlsx');
  }

  Widget _buildLoginUI(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final mobile = size.height > size.width && size.width < 600;

  return Center(
    child: IgnorePointer(
      ignoring: _loggingIn, // disables ALL taps, including GestureDetector
      child: GestureDetector(
        onTap: () {
          if (_loggingIn) return;

          setState(() => _loggingIn = true);

          if (kIsWeb) {
            Future.microtask(() {
              MsalService.startLogin(["User.Read"]);
            });
          } else {
            userRoleService.setUser("wpenfold@bigpond.net.au");
            setState(() {
              _token = "local-login";
              _fixtureLoadFuture = _loadAllFixtures();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(mobile ? 12 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mobile ? 16 : 22),
            boxShadow: _loggingIn
                ? []
                : [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.55),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                  ],
          ),
          child: Opacity(
            opacity: _loggingIn ? 0.4 : 1.0,
            child: Image.asset(
              "assets/images/Football.Logo.png",
              height: mobile ? 100 : 150,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
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
            ? _buildLoginUI(context)
            : FutureBuilder(
                future: _fixtureLoadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

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