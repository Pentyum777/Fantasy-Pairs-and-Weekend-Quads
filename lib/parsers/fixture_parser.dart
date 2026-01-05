import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/afl_fixture.dart';

String safeCellValue(dynamic cell) {
  if (cell == null) return "";
  return cell.toString().trim();
}

int? parseRound(String value) {
  value = value.trim().toUpperCase();

  if (value == "OPENING ROUND") return 0;

  if (value.startsWith("ROUND")) {
    final parts = value.split(" ");
    if (parts.length >= 2) {
      return int.tryParse(parts[1]);
    }
  }

  return null;
}

DateTime parseAflDate(String value) {
  value = value.trim();

  final parts = value.split(" ");
  if (parts.length < 3) {
    return DateTime(2099, 1, 1);
  }

  final monthName = parts[1];
  final day = int.tryParse(parts[2]) ?? 1;

  const monthMap = {
    "January": 1,
    "February": 2,
    "March": 3,
    "April": 4,
    "May": 5,
    "June": 6,
    "July": 7,
    "August": 8,
    "September": 9,
    "October": 10,
    "November": 11,
    "December": 12,
  };

  final month = monthMap[monthName] ?? 1;

  return DateTime(2026, month, day);
}

List<AflFixture> parseAflFixtures2026(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables.values.first;

  final fixtures = <AflFixture>[];

  for (var i = 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];

    final round = parseRound(safeCellValue(row[0]?.value));
    final rawDate = safeCellValue(row[1]?.value);
    final home = safeCellValue(row[2]?.value);
    final away = safeCellValue(row[3]?.value);
    final venue = safeCellValue(row[4]?.value);
    final time = safeCellValue(row[5]?.value);
    final source = safeCellValue(row[6]?.value);

    if (round == null || home.isEmpty || away.isEmpty) {
      continue;
    }

    final date = parseAflDate(rawDate);

    fixtures.add(
      AflFixture(
        round: round,
        date: date,
        homeTeam: home,
        awayTeam: away,
        venue: venue,
        time: time,
        source: source,
      ),
    );
  }

  print("FINAL FIXTURE COUNT: ${fixtures.length}");
  return fixtures;
}