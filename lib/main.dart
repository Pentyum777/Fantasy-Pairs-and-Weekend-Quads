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
import 'screens/season_selection_screen.dart';

import 'debug/afl_data_validator.dart';

void main() {
  print("🔥 MAIN EXECUTED — CLEAN VERSION");
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

    // MSAL → Dart token + account callback
    MsalService.listenForToken((token, account) {
      if (!mounted) return;

      try {
        final email = account.username;
        print("MSAL(Dart): Logged in as $email");

        // Safely assign user role
        try {
          userRoleService.setUser(email);
        } catch (e, st) {
          print("MSAL(Dart): ERROR in setUser($email) → $e");
          print(st);
        }

        // Update UI + start fixture loading
        setState(() {
          _token = token;

          try {
            _fixtureLoadFuture = _loadAllFixtures();
          } catch (e, st) {
            print("MSAL(Dart): ERROR starting _loadAllFixtures() → $e");
            print(st);
            _fixtureLoadFuture = Future.value(); // prevent crash
          }
        });
      } catch (e, st) {
        print("MSAL(Dart): ERROR in listenForToken callback → $e");
        print(st);
      }
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
      home: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              Color(0xFFE8ECF7),
              Color(0xFFF7F9FC),
            ],
          ),
        ),
        child: _token == null
            ? LoginScreen(
                onLoggedIn: () {
                  if (!mounted) return;

                  try {
                    setState(() {
                      _token = "local-login";

                      try {
                        _fixtureLoadFuture = _loadAllFixtures();
                      } catch (e, st) {
                        print("ERROR starting _loadAllFixtures() → $e");
                        print(st);
                        _fixtureLoadFuture = Future.value();
                      }
                    });
                  } catch (e, st) {
                    print("ERROR in onLoggedIn callback → $e");
                    print(st);
                  }
                },
              )
            : FutureBuilder(
                future: _fixtureLoadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
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

                      rounds.addAll(
                        fixtureRepo.allRoundsForSeason(season),
                      );

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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⭐ UPDATED LOGIN SCREEN (PRO TILE SYSTEM)
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  final void Function() onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  bool _hovering = false;


  void _login() {
    setState(() => _loading = true);
    widget.onLoggedIn();
  }

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
  }

  
  @override
Widget build(BuildContext context) {
  final bool mobile = isPortraitPhone(context);

  return Container(
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/images/stadium_glow.png"),
        fit: BoxFit.cover,
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("AFL Login"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 24 : 40,
            vertical: mobile ? 28 : 40,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withAlpha((255 * 0.15).round()),
            borderRadius: BorderRadius.circular(mobile ? 16 : 22),
            border: Border.all(
              color: Colors.grey.shade300.withAlpha(153),
              width: mobile ? 1.1 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(46),
                blurRadius: mobile ? 6 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: _loading
              ? const CircularProgressIndicator()
              : MouseRegion(
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() => _hovering = false),
                  child: GestureDetector(
                    onTap: _login,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.all(mobile ? 12 : 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(mobile ? 16 : 22),
                        boxShadow: _hovering
                            ? [
                                BoxShadow(
                                  color: Colors.blueAccent.withValues(
                                      alpha: 255 * 0.55),
                                  blurRadius: 25,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withAlpha(46),
                                  blurRadius: mobile ? 6 : 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Image.asset(
                        "assets/images/Football.Logo.png",
                        height: mobile ? 100 : 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}
}