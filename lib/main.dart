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

  late final PlayerRepository playerRepo;
  late final FixtureRepository fixtureRepo;
  final FantasyScoreService fantasyService = FantasyScoreService();

  int punterCount = 11;
  int? selectedRound;
  GameType? selectedGameType;

  List<PunterSelection> punterSelections = [];

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

    if (!mounted) return;

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
      final fixtureBytes =
          await rootBundle.load("assets/afl_fixtures_2026.xlsx");

      if (!mounted) return;

      playerRepo.loadFromExcel(playerBytes.buffer.asUint8List());
      fixtureRepo.loadFromExcel(fixtureBytes.buffer.asUint8List());
    } catch (e, st) {
      debugPrint("ERROR LOADING ASSETS: $e");
      debugPrint(st.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading assets: $e")),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoadingPlayers = false;
    });
  }

  Future<void> _refreshFantasyScores() async {
    final round = selectedRound;
    if (round == null) return;

    final fixtures = fixtureRepo.fixturesForRound(round);

    final urls = fixtures
        .map((f) => f.source)
        .where((u) => u.isNotEmpty);

    final allScores = <String, int>{};

    for (final url in urls) {
      final scores = await fantasyService.fetchScores(url);
      allScores.addAll(scores);
    }

    if (!mounted) return;

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
    final gamePlayers = _playersForFixture(gameType);

    final playersPerPunter =
        gameType == GameType.weekendQuads ? 4 : 2;

    if (punterSelections.length != punterCount ||
        (punterSelections.isNotEmpty &&
            punterSelections.first.players.length != playersPerPunter)) {
      punterSelections = List.generate(
        punterCount,
        (_) => PunterSelection(playersPerPunter),
      );
    }

    final fixtures = _fixturesForGameType(gameType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                items: List.generate(21, (i) => i + 5)
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text("$n"),
                      ),
                    )
                    .toList(),
                onChanged: (n) {
                  if (n == null) return;
                  setState(() {
                    punterCount = n;
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

        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: ElevatedButton(
            onPressed: _refreshFantasyScores,
            child: const Text("Refresh Fantasy Scores"),
          ),
        ),

        _buildFixtureTable(fixtures),

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

  List<AflFixture> _fixturesForGameType(GameType type) {
    final round = selectedRound;
    if (round == null) return [];

    final roundFixtures =
        fixtureRepo.fixtures.where((f) => f.round == round).toList();

    switch (type) {
      case GameType.thursdayPairs:
        return roundFixtures
            .where((f) => f.date.weekday == DateTime.thursday)
            .toList();

      case GameType.fridayPairs:
        return roundFixtures
            .where((f) => f.date.weekday == DateTime.friday)
            .toList();

      case GameType.saturdayPairs:
        return roundFixtures
            .where((f) => f.date.weekday == DateTime.saturday)
            .toList();

      case GameType.sundayPairs:
        return roundFixtures
            .where((f) => f.date.weekday == DateTime.sunday)
            .toList();

      case GameType.mondayPairs:
        return roundFixtures
            .where((f) => f.date.weekday == DateTime.monday)
            .toList();

      case GameType.weekendQuads:
        return roundFixtures
            .where(
              (f) =>
                  f.date.weekday == DateTime.friday ||
                  f.date.weekday == DateTime.saturday ||
                  f.date.weekday == DateTime.sunday ||
                  f.date.weekday == DateTime.monday,
            )
            .toList();
    }
  }

  Widget _buildFixtureTable(List<AflFixture> fixtures) {
    if (fixtures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "No fixtures found for this game type.",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Table(
        border: TableBorder.all(color: Colors.grey),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(3),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Date",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Home",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Away",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Venue",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          ...fixtures.map(
            (f) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text("${f.date.toLocal()}".split(' ')[0]),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(f.homeTeam),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(f.awayTeam),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(f.venue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<AflPlayer> _playersForFixture(GameType type) {
    final round = selectedRound;
    if (round == null) return [];

    final roundFixtures =
        fixtureRepo.fixtures.where((f) => f.round == round).toList();

    if (roundFixtures.isEmpty) return [];

    final selectedFixtures = switch (type) {
      GameType.thursdayPairs =>
          roundFixtures.where((f) => f.date.weekday == DateTime.thursday),

      GameType.fridayPairs =>
          roundFixtures.where((f) => f.date.weekday == DateTime.friday),

      GameType.saturdayPairs =>
          roundFixtures.where((f) => f.date.weekday == DateTime.saturday),

      GameType.sundayPairs =>
          roundFixtures.where((f) => f.date.weekday == DateTime.sunday),

      GameType.mondayPairs =>
          roundFixtures.where((f) => f.date.weekday == DateTime.monday),

      GameType.weekendQuads => roundFixtures.where(
        (f) =>
            f.date.weekday == DateTime.friday ||
            f.date.weekday == DateTime.saturday ||
            f.date.weekday == DateTime.sunday ||
            f.date.weekday == DateTime.monday,
      ),
    };

    final clubs = <String>{
      for (final f in selectedFixtures) f.homeTeam,
      for (final f in selectedFixtures) f.awayTeam,
    };

    return playerRepo.players.where((p) => clubs.contains(p.club)).toList();
  }
}