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

      final email = account.username;
      print("MSAL(Dart): Logged in as $email");

      // Set user role based on email
      userRoleService.setUser(email);

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
      home: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              Color(0xFFE8ECF7), // soft bluish-grey
              Color(0xFFF7F9FC), // near-white
            ],
          ),
        ),
        child: _token == null
            ? LoginScreen(
                onLoggedIn: () {
                  setState(() {
                    _token = "local-login";
                    _fixtureLoadFuture = _loadAllFixtures();
                  });

                  MsalService.startLogin(["User.Read"]);
                },
              )
            : FutureBuilder(
                future: _fixtureLoadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(
                      backgroundColor: Colors.transparent,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⭐ UPDATED SEASON SELECTION SCREEN (PRO TILE SYSTEM)
// ---------------------------------------------------------------------------

class SeasonSelectionScreen extends StatelessWidget {
  final List<int> seasons;
  final void Function(int season) onSelect;

  const SeasonSelectionScreen({
    super.key,
    required this.seasons,
    required this.onSelect,
  });

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
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
            vertical: mobile ? 8 : 12,
            horizontal: mobile ? 6 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mobile ? 14 : 20),
            color: Colors.grey.shade900.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: mobile ? 4 : 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade300.withValues(alpha: 0.6),
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
    final bool mobile = isPortraitPhone(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Select Season"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mobile ? 3 : 5,
              mainAxisSpacing: mobile ? 10 : 12,
              crossAxisSpacing: mobile ? 10 : 12,
              childAspectRatio: mobile ? 2.4 : 4.2,
            ),
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];

              return buildProTile(
                context: context,
                label: "$season",
                onTap: () => onSelect(season),
              );
            },
          ),
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
    final theme = Theme.of(context);
    final bool mobile = isPortraitPhone(context);

    return Scaffold(
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
            color: Colors.grey.shade900.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(mobile ? 16 : 22),
            border: Border.all(
              color: Colors.grey.shade300.withValues(alpha: 0.6),
              width: mobile ? 1.1 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: mobile ? 6 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _loading
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                  icon: const Icon(Icons.login, size: 20),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 20 : 32,
                      vertical: mobile ? 12 : 16,
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(mobile ? 12 : 16),
                    ),
                  ),
                  onPressed: _login,
                  label: Text(
                    "Login with Microsoft",
                    style: TextStyle(
                      fontSize: mobile ? 14 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}