import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/msal_service.dart';
import 'repositories/fixture_repository.dart';
import 'repositories/player_repository.dart';
import 'services/punter_score_service.dart';
import 'services/round_completion_service.dart';
import 'services/user_role_service.dart';
import 'debug/afl_data_validator.dart';
import 'theme/app_theme.dart';
import 'widgets/background_container.dart';
import 'screens/home_screen.dart';

void main() {
  print('🔥 MAIN EXECUTED — ${kIsWeb ? "WEB" : "WINDOWS/MOBILE"} VERSION');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;

  late final FixtureRepository    fixtureRepo;
  late final PlayerRepository     playerRepo;
  late final PunterScoreService   fantasyService;

  final RoundCompletionService roundCompletionService = RoundCompletionService();
  final UserRoleService        userRoleService        = UserRoleService();

  Future<void>? _fixtureLoadFuture;
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();

    fixtureRepo    = FixtureRepository();
    playerRepo     = PlayerRepository();
    fantasyService = PunterScoreService();

    playerRepo.loadAllPlayers();

    // ── Restore saved login ──────────────────────────────────────────────────
    // Check SharedPreferences for a previously saved email. If found, skip
    // the login screen entirely and go straight to the app.
    SharedPreferences.getInstance().then((prefs) {
      final savedEmail = prefs.getString('logged_in_email');
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        userRoleService.setUser(savedEmail);
        setState(() {
          _token             = 'restored-session';
          _fixtureLoadFuture = _loadAllFixtures();
        });
      }
    });

    if (kIsWeb) {
      MsalService.listenForToken((token, account) {
        if (!mounted) return;
        final email = account.username;
        print('MSAL(Dart): Logged in as $email');
        userRoleService.setUser(email);
        // Persist so next launch skips login
        SharedPreferences.getInstance()
            .then((prefs) => prefs.setString('logged_in_email', email));
        setState(() {
          _token             = token;
          _fixtureLoadFuture = _loadAllFixtures();
        });
      });
    }
  }

  Future<void> _loadAllFixtures() async {
    await fixtureRepo.loadFixturesFromExcelFile('assets/afl_fixtures_2026.xlsx');
  }

  // ── Login screen ────────────────────────────────────────────────────────────

  Widget _buildLoginUI(BuildContext context) {
    final size   = MediaQuery.sizeOf(context);
    final mobile = size.height > size.width && size.width < 600;

    return Center(
      child: IgnorePointer(
        ignoring: _loggingIn,
        child: GestureDetector(
          onTap: () {
            if (_loggingIn) return;
            setState(() => _loggingIn = true);

            if (kIsWeb) {
              Future.microtask(() => MsalService.startLogin(['User.Read']));
            } else {
              final email = 'wpenfold@bigpond.net.au';
              userRoleService.setUser(email);
              SharedPreferences.getInstance()
                  .then((prefs) => prefs.setString('logged_in_email', email));
              setState(() {
                _token             = 'local-login';
                _fixtureLoadFuture = _loadAllFixtures();
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(mobile ? 12 : 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(mobile ? 16 : 22),
                  boxShadow: _loggingIn
                      ? []
                      : [
                          BoxShadow(
                            color:      Colors.blueAccent.withOpacity(0.55),
                            blurRadius: 25,
                            spreadRadius: 4,
                          ),
                        ],
                ),
                child: Opacity(
                  opacity: _loggingIn ? 0.4 : 1.0,
                  child: Image.asset(
                    'assets/images/Football.Logo.png',
                    height: mobile ? 100 : 150,
                    fit:    BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: mobile ? 16 : 20),
              AnimatedOpacity(
                opacity:  _loggingIn ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  'Tap to sign in',
                  style: TextStyle(
                    color:      Colors.white70,
                    fontSize:   mobile ? 13 : 15,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'AFL Fantasy',
      debugShowCheckedModeBanner: false,
      theme:        AppTheme.dark,
      home: BackgroundContainer(
        child: _token == null
            ? Scaffold(
                backgroundColor: Colors.transparent,
                body:            SafeArea(child: _buildLoginUI(context)),
              )
            : FutureBuilder(
                future:  _fixtureLoadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(
                      backgroundColor: Colors.transparent,
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Data validation (dev-mode only)
                  validateAflData(
                    fixtureRepo: fixtureRepo,
                    playerRepo:  playerRepo,
                    season:      2026,
                  );

                  return HomeScreen(
                    seasons:               const [2026],
                    fixtureRepo:           fixtureRepo,
                    playerRepo:            playerRepo,
                    fantasyService:        fantasyService,
                    roundCompletionService: roundCompletionService,
                    userRoleService:       userRoleService,
                  );
                },
              ),
      ),
    );
  }
}
