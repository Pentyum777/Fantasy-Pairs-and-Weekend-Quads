import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import '../models/afl_fixture.dart';

class PreseasonFixtureParser {
  static Future<List<AflFixture>> parse() async {
    final bytes = await rootBundle.load('assets/afl_fixtures_2026_pre_season.xlsx');
    final excel = Excel.decodeBytes(bytes.buffer.asUint8List());

    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;
    final rows = sheet.rows;

    final fixtures = <AflFixture>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      // Guard against malformed rows
      if (row.length < 4) {
        print("⚠️ Skipping malformed preseason row $i (not enough columns)");
        continue;
      }

      final round = _cellString(row, 0).isEmpty
          ? 0
          : int.tryParse(_cellString(row, 0)) ?? 0;

      final roundLabel = _cellString(row, 1).isEmpty
          ? "Pre-Season"
          : _cellString(row, 1);

      final homeTeam = _cellString(row, 2);
      final awayTeam = _cellString(row, 3);
      final venue = _cellString(row, 4);
      final dateStr = _cellString(row, 5);
      final timeStr = _cellString(row, 6);

      if (homeTeam.isEmpty || awayTeam.isEmpty) {
        print("⚠️ Skipping preseason row $i (missing home/away team)");
        continue;
      }

      // Match ID (auto-generate if missing)
      int matchId;
      final rawMatchId = _cellString(row, 7);
      if (rawMatchId.isNotEmpty) {
        matchId = int.tryParse(rawMatchId) ?? (9000 + fixtures.length + 1);
      } else {
        matchId = 9000 + fixtures.length + 1;
      }

      // Parse date/time
      final dateTime = _parseDateTime(dateStr, timeStr);

      fixtures.add(
        AflFixture(
          round: round,
          roundLabel: roundLabel,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          venue: venue,
          date: dateTime,
          time: timeStr,
          matchId: matchId,
          source: "PreSeason",
        ),
      );
    }

    return fixtures;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _cellString(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return "";
    final cell = row[index];
    final value = cell?.value;
    return value?.toString().trim() ?? "";
  }

  static DateTime? _parseDateTime(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return null;

    // Excel serial date (int or double)
    final numeric = num.tryParse(dateStr);
    if (numeric != null) {
      try {
        final excelEpoch = DateTime(1899, 12, 30);
        final date = excelEpoch.add(Duration(days: numeric.floor()));

        if (timeStr.isNotEmpty) {
          final parsed = DateTime.tryParse("${date.toIso8601String().split('T')[0]} $timeStr");
          return parsed ?? date;
        }

        return date;
      } catch (_) {}
    }

    // Standard string date
    final parsed = DateTime.tryParse("$dateStr $timeStr");
    if (parsed != null) return parsed;

    // Try date only
    return DateTime.tryParse(dateStr);
  }
}