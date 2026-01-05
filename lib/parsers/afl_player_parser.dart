import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/afl_player.dart';

/// Parses the AFL Players 2026 Excel file into a list of AflPlayer objects.
/// Expected columns:
///   A: Full Name
///   B: Club
///   C: Guernsey Number
///   D: Season
List<AflPlayer> parseAflPlayers2026(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables.values.first;

  final List<AflPlayer> players = [];

  // Skip header row (rowIndex = 0)
  for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
    final row = sheet.rows[rowIndex];

    if (row.isEmpty) continue;

    final fullName = _readCell(row, 0);
    final club = _readCell(row, 1);
    final guernseyStr = _readCell(row, 2);
    final seasonStr = _readCell(row, 3);

    // Skip invalid rows
    if (fullName.isEmpty || club.isEmpty || guernseyStr.isEmpty) {
      continue;
    }

    final guernseyNumber = int.tryParse(guernseyStr) ?? 0;
    final season = int.tryParse(seasonStr) ?? 2026;

    players.add(
      AflPlayer(
        fullName: fullName,
        club: club,
        guernseyNumber: guernseyNumber,
        season: season,
      ),
    );
  }

  return players;
}

/// Safely reads a cell from a row and returns a string.
String _readCell(List<Data?> row, int index) {
  if (index >= row.length) return "";
  final cell = row[index];
  if (cell == null) return "";
  return cell.value.toString().trim();
}