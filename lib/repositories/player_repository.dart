import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/afl_player.dart';
import '../utils/afl_club_codes.dart';

class PlayerRepository {
  final List<AflPlayer> _players = [];
  List<AflPlayer> get players => _players;

  

  // ------------------------------------------------------------
  // LOAD PLAYERS FROM JSON
  // ------------------------------------------------------------
  Future<void> loadPlayers() async {
    _players.clear();

    final jsonString =
        await rootBundle.loadString('assets/afl_players_2026.json');

    final List<dynamic> data = json.decode(jsonString);

    _players.addAll(
      data.map((p) {
        final fullClubName = p['club'] ?? "";
        final clubCode = AflClubCodes.normalize(fullClubName);

        return AflPlayer(
  id: p['id'],
  name: p['name'],        // <-- FIXED
  club: clubCode,
  guernseyNumber: p['number'],
  season: p['season'],
);
      }),
    );
  }
}