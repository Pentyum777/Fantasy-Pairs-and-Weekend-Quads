import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/afl_player.dart';
import '../utils/afl_club_codes.dart';

class PlayerRepository {
  final List<AflPlayer> _players = [];
  List<AflPlayer> get players => _players;

  // ------------------------------------------------------------
  // STATIC NORMALIZER (used by FixtureRepository)
  // ------------------------------------------------------------
  static String normalizeClubStatic(String raw) {
    return AflClubCodes.normalize(raw);
  }

  // ------------------------------------------------------------
  // INSTANCE NORMALIZER (used when loading players)
  // ------------------------------------------------------------
  String normalizeClub(String raw) {
    return AflClubCodes.normalize(raw);
  }

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
        final clubCode = normalizeClub(fullClubName);

        return AflPlayer(
          id: p['id'],
          name: p['id'],
          club: clubCode,
          guernseyNumber: p['number'],
          season: p['season'],
        );
      }),
    );
  }
}