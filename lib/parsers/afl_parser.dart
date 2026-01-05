import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/afl_player.dart';

List<AflPlayer> parseAflPlayers2026(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables.values.first;

  final List<AflPlayer> players = [];
  String lastClub = "";

  for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
    final row = sheet.rows[rowIndex];

    if (row.isEmpty) continue;

    final club = _readCell(row, 0);
    final fullName = _readCell(row, 1);
    final guernseyStr = _readCell(row, 2);
    final seasonStr = _readCell(row, 3);

    // Carry forward merged club cells
    final resolvedClub = club.isEmpty ? lastClub : club;
    lastClub = resolvedClub;

    if (fullName.isEmpty || guernseyStr.isEmpty) continue;

    players.add(
      AflPlayer(
        fullName: fullName,
        club: resolvedClub,
        guernseyNumber: int.tryParse(guernseyStr) ?? 0,
        season: int.tryParse(seasonStr) ?? 2026,
      ),
    );
  }

  return players;
}

String _readCell(List<Data?> row, int index) {
  if (index >= row.length) return "";
  final cell = row[index];
  if (cell == null) return "";
  return cell.value.toString().trim();
}