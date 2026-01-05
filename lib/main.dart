import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'msal_web.dart';
import 'models/afl_player.dart';
import 'models/afl_fixture.dart';
import 'models/game_type.dart';
import 'models/punter_selection.dart';
import 'repositories/player_repository.dart';
import 'repositories/fixture_repository.dart';
import 'widgets/game_type_selector.dart';
import 'widgets/punter_selection_table.dart';
import 'widgets/round_selector.dart';
import 'services/fantasy_score_service.dart';

void main() {
  initMsal();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  bool isLoadingPlayers = false;

  late PlayerRepository playerRepo;
  late FixtureRepository fixtureRepo;
  final fantasyService = FantasyScoreService();

  int punterCount = 11;
  int? selectedRound;
  GameType? selectedGameType;

  late List<PunterSelection> punterSelections;

  @override
  void initState() {
    super.initState();
    playerRepo = PlayerRepository();
    fixtureRepo = FixtureRepository();
  }

  Future<void> _handleLogin() async {
    final token = await acquireTokenWithMsal([
      "User.Read",
      "Files.Read",
      "Files.Read.All",
    ]);

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed. Please try again.")),
      );
      return;
    }

    setState(() {
      isLoggedIn = true;
      isLoadingPlayers = true;
    });

    try {
      final playerBytes = await rootBundle.load("assets/afl_players_2026.xlsx");
      playerRepo.loadFromExcel(playerBytes.buffer.asUint8List());

      final fixtureBytes =
          await rootBundle.load("assets/afl_fixtures_2026.xlsx");
      fixtureRepo.loadFromExcel(fixtureBytes.buffer.asUint8List());

      print("Fixtures loaded: ${fixtureRepo.fixtures.length}");
    } catch (e, st) {
      print("ERROR LOADING ASSETS: $e");
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading assets: $e")),
      );
    }

    setState(() {
      isLoadingPlayers = false;
    });
  }

  Future<void> _refreshFantasyScores() async {
    if (selectedRound == null) return;

    final fixtures = fixtureRepo.fixturesForRound(selectedRound!);

    final urls = fixtures
        .map((f) => f.source)
        .where((u) => u.isNotEmpty)
        .toList();

    final allScores = <String, int>{};

    for (var url in urls) {
      final scores = await fantasyService.fetchScores(url);
      allScores.addAll(scores);
    }

    playerRepo.applyFantasyScores(allScores);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AFL Pairs",
      home: Scaffold(
        appBar: AppBar(
          title: const Text("AFL Pairs"),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!isLoggedIn) {
      return _buildLoginScreen();
    }

    if (isLoadingPlayers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedRound == null) {
      final rounds = fixtureRepo.fixtures
          .map((f) => f.round)
          .toSet()
          .toList()
        ..sort();

      return RoundSelector(
        rounds: rounds,
        onSelect: (round) {
          setState(() => selectedRound = round);
        },
      );
    }

    if (selectedGameType == null) {
      return GameTypeSelector(
        onSelect: (type) {
          setState(() => selectedGameType = type);
        },
      );
    }

    return _buildGameUI();
  }

  Widget _buildLoginScreen() {
    return Center(
      child: ElevatedButton(
        onPressed: _handleLogin,
        child: const Text("Login with Microsoft"),
      ),
    );
  }

  Widget _buildGameUI() {
    final gameType = selectedGameType!;
    final List<AflPlayer> gamePlayers = _playersForFixture(gameType);

    final int playersPerPunter =
        gameType == GameType.weekendQuads ? 4 : 2;

    // Initialize punter selections
    punterSelections = List.generate(
      punterCount,
      (_) => PunterSelection(playersPerPunter),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Punter count dropdown
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
          child: Row(
            children: [
              const Text(
                "Punters:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: punterCount,
                items: List.generate(21, (i) => i + 5).map((n) {
                  return DropdownMenuItem(
                    value: n,
                    child: Text("$n"),
                  );
                }).toList(),
                onChanged: (n) {
                  setState(() {
                    punterCount = n!;
                    punterSelections = List.generate(
                      punterCount,
                      (_) => PunterSelection(playersPerPunter),
                    );
                  });
                },
              ),
            ],
          ),
        ),

        // Refresh button
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: ElevatedButton(
            onPressed: _refreshFantasyScores,
            child: const Text("Refresh Fantasy Scores"),
          ),
        ),

        // Selection table
        Expanded(
          child: PunterSelectionTable(
            punterCount: punterCount,
            playersPerPunter: playersPerPunter,
            availablePlayers: gamePlayers,
            selections: punterSelections,
            onChanged: () => setState(() {}),
          ),
        ),
      ],
    );
  }

  List<AflPlayer> _playersForFixture(GameType type) {
    if (selectedRound == null) return [];

    final roundFixtures = fixtureRepo.fixtures
        .where((f) => f.round == selectedRound)
        .toList();

    if (roundFixtures.isEmpty) return [];

    List<AflFixture> selectedFixtures = [];

    switch (type) {
      case GameType.thursdayPairs:
        selectedFixtures = roundFixtures
            .where((f) => f.date.weekday == DateTime.thursday)
            .toList();
        break;
      case GameType.fridayPairs:
        selectedFixtures = roundFixtures
            .where((f) => f.date.weekday == DateTime.friday)
            .toList();
        break;
      case GameType.saturdayPairs:
        selectedFixtures = roundFixtures
            .where((f) => f.date.weekday == DateTime.saturday)
            .toList();
        break;
      case GameType.sundayPairs:
        selectedFixtures = roundFixtures
            .where((f) => f.date.weekday == DateTime.sunday)
            .toList();
        break;
      case GameType.mondayPairs:
        selectedFixtures = roundFixtures
            .where((f) => f.date.weekday == DateTime.monday)
            .toList();
        break;
      case GameType.weekendQuads:
        selectedFixtures = roundFixtures.where((f) =>
            f.date.weekday == DateTime.friday ||
            f.date.weekday == DateTime.saturday ||
            f.date.weekday == DateTime.sunday ||
            f.date.weekday == DateTime.monday).toList();
        break;
    }

    final clubs = <String>{};
    for (var f in selectedFixtures) {
      clubs.add(f.homeTeam);
      clubs.add(f.awayTeam);
    }

    return playerRepo.players.where((p) => clubs.contains(p.club)).toList();
  }
}