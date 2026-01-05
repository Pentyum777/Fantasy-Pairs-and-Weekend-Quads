import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/afl_player.dart';

class PlayerRepository {
  List<AflPlayer> players = [];

  void loadFromExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;

    final loaded = <AflPlayer>[];

    // Assuming columns: NAME | CLUB
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final name = row[0]?.value?.toString().trim() ?? "";
      final club = row[1]?.value?.toString().trim() ?? "";

      if (name.isEmpty || club.isEmpty) continue;

      loaded.add(
        AflPlayer(
          name: name,
          club: club,
        ),
      );
    }

    players = loaded;
    print("Loaded players: ${players.length}");
  }

  void applyFantasyScores(Map<String, int> scores) {
    for (var p in players) {
      if (scores.containsKey(p.name)) {
        p.liveScore = scores[p.name]!;
      } else {
        p.liveScore = 0;
      }
    }
  }
}