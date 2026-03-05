import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

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
import 'screens/login_screen.dart';

import 'debug/afl_data_validator.dart';

void main() {
  print("🔥 MAIN EXECUTED — WEB VERSION");
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

  Timer? _versionTimer;
  String _currentVersion = "";

  @override
  void initState() {
    super.initState();

    _startVersionPolling();

    fixtureRepo = FixtureRepository();
    playerRepo = PlayerRepository();
    fantasyService = PunterScoreService();

    playerRepo.loadAllPlayers();

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

  void _startVersionPolling() {
    _versionTimer?.cancel();
    _versionTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkForNewVersion(),
    );
  }

  Future<void> _checkForNewVersion() async {
    try {
      final response = await http.get(
        Uri.parse("version.json?cb=${DateTime.now().millisecondsSinceEpoch}"),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final newVersion = json["version"];

        if (_currentVersion.isEmpty) {
          _currentVersion = newVersion;
          return;
        }

        if (newVersion != _currentVersion) {
          print("🔄 New version detected → forcing reload");
          web.window.location.reload();
        }
      }
    } catch (_) {}
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
  MsalService.startLogin(["User.Read"]);
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
  season: selectedSeason,   // ⭐ FIX
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