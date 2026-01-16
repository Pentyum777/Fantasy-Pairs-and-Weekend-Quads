import 'package:flutter/material.dart';

import '../models/punter_selection.dart';
import '../models/player_pick.dart';
import '../models/afl_fixture.dart';

import '../repositories/fixture_repository.dart';
import '../repositories/player_repository.dart';
import '../services/punter_score_service.dart';
import '../services/championship_service.dart';
import '../services/round_completion_service.dart';
import '../services/user_role_service.dart';

import 'game_view_screen.dart';

class CustomPairsBuilderScreen extends StatefulWidget {
  final int round;
  final FixtureRepository fixtureRepo;
  final PlayerRepository playerRepo;
  final PunterScoreService fantasyService;
  final ChampionshipService championshipService;
  final RoundCompletionService roundCompletionService;
  final UserRoleService userRoleService;

  const CustomPairsBuilderScreen({
    super.key,
    required this.round,
    required this.fixtureRepo,
    required this.playerRepo,
    required this.fantasyService,
    required this.championshipService,
    required this.roundCompletionService,
    required this.userRoleService,
  });

  @override
  State<CustomPairsBuilderScreen> createState() =>
      _CustomPairsBuilderScreenState();
}

class _CustomPairsBuilderScreenState extends State<CustomPairsBuilderScreen> {
  /// FIXED: matchId is now a String, so the selection set must also be String
  final Set<String> _selectedFixtureIds = {};

  // ---------------------------------------------------------------------------
  // AFL CLUB NORMALISATION MAP
  // ---------------------------------------------------------------------------
  static const Map<String, String> _clubCodeMap = {
    "Adelaide": "ADE",
    "Adelaide Crows": "ADE",
    "Brisbane": "BRI",
    "Brisbane Lions": "BRI",
    "Carlton": "CARL",
    "Collingwood": "COLL",
    "Essendon": "ESS",
    "Fremantle": "FRE",
    "Geelong": "GEEL",
    "Gold Coast": "GC",
    "Gold Coast Suns": "GC",
    "GWS": "GWS",
    "Greater Western Sydney": "GWS",
    "Hawthorn": "HAW",
    "Melbourne": "MELB",
    "North Melbourne": "NM",
    "Port Adelaide": "PORT",
    "Port": "PORT",
    "Power": "PORT",
    "Richmond": "RICH",
    "St Kilda": "STK",
    "Sydney": "SYD",
    "West Coast": "WCE",
    "West Coast Eagles": "WCE",
    "Eagles": "WCE",
    "Western Bulldogs": "WB",
    "Bulldogs": "WB",
  };

  String _normalizeClubCode(String raw) {
    return _clubCodeMap[raw] ?? raw.toUpperCase();
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final fixtures = widget.fixtureRepo.fixturesForRound(widget.round).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Pairs Builder"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  "Select fixtures for Round ${widget.round}",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.builder(
                    itemCount: fixtures.length,
                    itemBuilder: (context, index) {
                      final f = fixtures[index];

                      /// FIXED: fixtureId is always a String
                      final fixtureId = f.matchId ?? index.toString();
                      final selected = _selectedFixtureIds.contains(fixtureId);

                      final label = _buildFixtureLabel(index, f.date);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade400,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _teamLogo(f.homeTeam),
                            const SizedBox(width: 12),

                            Expanded(
                              child: InkWell(
                                onTap: widget.userRoleService.isAdmin
                                    ? () {
                                        setState(() {
                                          selected
                                              ? _selectedFixtureIds
                                                  .remove(fixtureId)
                                              : _selectedFixtureIds
                                                  .add(fixtureId);
                                        });
                                      }
                                    : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Checkbox(
                              value: selected,
                              onChanged: widget.userRoleService.isAdmin
                                  ? (v) {
                                      setState(() {
                                        v == true
                                            ? _selectedFixtureIds
                                                .add(fixtureId)
                                            : _selectedFixtureIds
                                                .remove(fixtureId);
                                      });
                                    }
                                  : null,
                            ),

                            _teamLogo(f.awayTeam),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: widget.userRoleService.isAdmin &&
                          _selectedFixtureIds.isNotEmpty
                      ? () => _startCustomPairs(context, fixtures)
                      : null,
                  child: const Text("Start Custom Pairs"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startCustomPairs(BuildContext context, List<AflFixture> fixtures) {
    final selectedFixtures = fixtures.where((f) {
      final id = f.matchId ?? fixtures.indexOf(f).toString();
      return _selectedFixtureIds.contains(id);
    }).toList();

    final clubs = <String>{};
    for (final f in selectedFixtures) {
      clubs.add(f.homeTeam);
      clubs.add(f.awayTeam);
    }

    final players = widget.playerRepo.players
        .where((p) => clubs.contains(p.club))
        .toList();

    final selections = List.generate(
      25,
      (i) => PunterSelection(
        punterNumber: i + 1,
        punterName: "P${i + 1}",
        picks: [
          PlayerPick(pickNumber: 1, player: null, score: 0),
          PlayerPick(pickNumber: 2, player: null, score: 0),
        ],
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameViewScreen(
          round: widget.round,
          gameType: "custom_pairs",
          selections: selections,
          fixtureRepo: widget.fixtureRepo,
          playerRepo: widget.playerRepo,
          fantasyService: widget.fantasyService,
          championshipService: widget.championshipService,
          roundCompletionService: widget.roundCompletionService,
          userRoleService: widget.userRoleService,
          selectedFixtureIds: _selectedFixtureIds.toList(),
          overridePlayers: players,
        ),
      ),
    );
  }

  String _buildFixtureLabel(int index, DateTime? date) {
    final gameNumber = index + 1;

    if (date == null) return "Game $gameNumber – Time TBC";

    final local = date.toLocal();
    final day = _weekday(local.weekday);
    final time = _formatTime(local);

    return "Game $gameNumber – $day $time";
  }

  String _weekday(int w) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[w - 1];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $ampm";
  }

  // ---------------------------------------------------------------------------
  // UPDATED TEAM LOGO WIDGET WITH NORMALISED CODES
  // ---------------------------------------------------------------------------
  Widget _teamLogo(String clubCode) {
    final code = _normalizeClubCode(clubCode);
    final assetPath = 'logos/$code.png';

    return SizedBox(
      width: 32,
      height: 32,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Center(
              child: Text(
                code,
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }
}