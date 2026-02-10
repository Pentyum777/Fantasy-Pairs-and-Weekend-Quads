import 'package:flutter/material.dart';

// ignore: deprecated_member_use


import 'services/msal_service.dart';

import 'repositories/fixture_repository.dart';
import 'repositories/player_repository.dart';
import 'services/punter_score_service.dart';
import 'services/round_completion_service.dart';
import 'services/user_role_service.dart';

import 'screens/round_selection_screen.dart';
import 'screens/game_type_selection_screen.dart';

import 'debug/afl_data_validator.dart';

void main() {
  print("🔥 MAIN EXECUTED — CLEAN VERSION");

  // IMPORTANT:
  // We do NOT override js.context['onMsalToken'] anymore.
  // msal.js already delivers tokens into MsalService internally.

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

    playerRepo.loadAllPlayers();
    userRoleService.setRole(UserRole.admin);

    // MSAL → Dart token callback
    MsalService.listenForToken((token) {
      print("MSAL(Dart): Token received → $token");

      if (!mounted) return;

      setState(() {
        _token = token;
        _fixtureLoadFuture = _loadAllFixtures();
      });
    });
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
      home: _token == null
          ? LoginScreen(
              onLoggedIn: () {
                // User pressed login → mark as logged in immediately
                // so FutureBuilder can run and fixtures can load.
                setState(() {
                  _token = "local-login";
                  _fixtureLoadFuture = _loadAllFixtures();
                });

                // Also start MSAL login flow (optional for real auth)
                MsalService.startLogin(["User.Read"]);
              },
            )
          : FutureBuilder(
              future: _fixtureLoadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                validateAflData(
                  fixtureRepo: fixtureRepo,
                  playerRepo: playerRepo,
                );

                return SeasonSelectionScreen(
                  seasons: const [2025, 2026],
                  onSelect: (season) {
                    setState(() {
                      selectedSeason = season;
                    });

                    final List<int?> rounds = [];

                    if (fixtureRepo.preseasonFixturesForSeason(season).isNotEmpty) {
                      rounds.add(null);
                    }

                    rounds.addAll(fixtureRepo.allRoundsForSeason(season));

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: "round_selection"),
                        builder: (_) => RoundSelectionScreen(
                          rounds: rounds,
                          completedRounds: roundCompletionService.completedRounds,
                          onRoundSelected: (int? round) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: RouteSettings(
                                  name: "game_type_${round ?? 'ps'}",
                                ),
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
    );
  }
}

class SeasonSelectionScreen extends StatelessWidget {
  final List<int> seasons;
  final void Function(int season) onSelect;

  const SeasonSelectionScreen({
    super.key,
    required this.seasons,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Season")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: seasons.map((season) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => onSelect(season),
              child: Text("$season Season"),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final void Function() onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  void _login() {
    setState(() => _loading = true);
    widget.onLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AFL Login")),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _login,
                child: const Text("Login with Microsoft"),
              ),
      ),
    );
  }
}