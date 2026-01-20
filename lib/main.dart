

import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:js/js.dart';

import 'services/msal_service.dart';

import 'repositories/fixture_repository.dart';
import 'repositories/player_repository.dart';
import 'services/punter_score_service.dart';
import 'services/round_completion_service.dart';
import 'services/user_role_service.dart';

import 'screens/round_selection_screen.dart';
import 'screens/game_type_selection_screen.dart';

@JS('onMsalToken')
external set onMsalToken(void Function(String token) f);


void main() {
 
print("🔥🔥🔥 MAIN EXECUTED — VERSION 7");

  onMsalToken = allowInterop((String token) {
    MsalService.receiveTokenFromJs(token);
  });

  final pending = js_util.getProperty(js.context, '__pendingMsalToken');
  if (pending != null) {
    MsalService.receiveTokenFromJs(pending);
    js_util.setProperty(js.context, '__pendingMsalToken', null);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;

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

    playerRepo.loadPlayers();
    userRoleService.setRole(UserRole.admin);

    MsalService.listenForToken((token) {
      if (!mounted) return;

      setState(() {
        _token = token;
        _fixtureLoadFuture = fixtureRepo.loadFixtures();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AFL App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _token == null
          ? LoginScreen(
              onLoggedIn: (token) {
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

                final List<int?> rounds = [];

                if (fixtureRepo.preseasonFixtures().isNotEmpty) {
                  rounds.add(null);
                }

                rounds.addAll(fixtureRepo.allSeasonRounds());

                // 🔥 CRITICAL DIAGNOSTIC
                print("🔥 ROUNDS LIST (from main.dart) → $rounds");

                return RoundSelectionScreen(
                  rounds: rounds,
                  completedRounds: roundCompletionService.completedRounds,
                  onRoundSelected: (int? round) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameTypeSelectionScreen(
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
                );
              },
            ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final void Function(String token) onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  void _login() {
    setState(() => _loading = true);
    widget.onLoggedIn("");
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