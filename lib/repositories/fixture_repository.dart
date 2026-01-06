import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/afl_fixture.dart';

class FixtureRepository {
  final List<AflFixture> fixtures = [];

  void loadFromExcel(Uint8List bytes) {
    fixtures.clear();

    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return;

    final String firstSheetName = excel.tables.keys.first;
    final sheet = excel.tables[firstSheetName];
    if (sheet == null) return;
    if (sheet.rows.isEmpty || sheet.maxRows <= 1) return;

    final headerRow = sheet.rows.first;

    final Map<String, int> headerIndex = {};
    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null || cell.value == null) continue;
      final key = cell.value.toString().trim().toUpperCase();
      if (key.isEmpty) continue;
      headerIndex[key] = i;
    }

    int? idxRound = headerIndex["ROUND"];
    int? idxDate = headerIndex["DATE"];
    int? idxHome = headerIndex["HOME TEAM"];
    int? idxAway = headerIndex["AWAY TEAM"];
    int? idxVenue = headerIndex["VENUE"];
    int? idxTime = headerIndex["TIME"];
    int? idxSource = headerIndex["GAME DATA SOURCE"];

    if (idxRound == null ||
        idxDate == null ||
        idxHome == null ||
        idxAway == null ||
        idxVenue == null) {
      return;
    }

    const int defaultYear = 2026;

    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];

      String roundLabel = _cellString(row, idxRound);
      if (roundLabel.isEmpty) continue;

      String dateText = _cellString(row, idxDate);
      String homeTeam = _cellString(row, idxHome);
      String awayTeam = _cellString(row, idxAway);
      String venue = _cellString(row, idxVenue);
      String time = idxTime != null ? _cellString(row, idxTime) : "";
      String source = idxSource != null ? _cellString(row, idxSource) : "";

      if (dateText.isEmpty || homeTeam.isEmpty || awayTeam.isEmpty) {
        continue;
      }

      final parsedDate =
          _parseDateWithoutYear(dateText, defaultYear) ?? DateTime.now();
      final int roundNumber = _parseRound(roundLabel);

      final fixture = AflFixture(
        roundLabel: roundLabel,   // ✅ REQUIRED FIELD ADDED
        round: roundNumber,
        date: parsedDate,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        venue: venue,
        time: time,
        source: source,
      );

      fixtures.add(fixture);
    }
  }

  List<AflFixture> fixturesForRound(int round) {
    return fixtures.where((f) => f.round == round).toList();
  }

  String _cellString(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return "";
    final cell = row[index];
    if (cell == null || cell.value == null) return "";
    return cell.value.toString().trim();
  }

  int _parseRound(String roundLabel) {
    final trimmed = roundLabel.trim().toUpperCase();

    if (trimmed == "OPENING ROUND") {
      return 0;
    }

    final digitMatch = RegExp(r'(\d+)').firstMatch(trimmed);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  DateTime? _parseDateWithoutYear(String text, int year) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) {
      return null;
    }

    final monthName = parts[1];
    final dayPart = parts[2];

    final month = _monthFromName(monthName);
    if (month == 0) return null;

    final day = int.tryParse(dayPart.replaceAll(RegExp(r'\D'), '')) ?? 1;

    return DateTime(year, month, day);
  }

  int _monthFromName(String monthName) {
    final m = monthName.toLowerCase();
    switch (m) {
      case 'january':
        return 1;
      case 'february':
        return 2;
      case 'march':
        return 3;
      case 'april':
        return 4;
      case 'may':
        return 5;
      case 'june':
        return 6;
      case 'july':
        return 7;
      case 'august':
        return 8;
      case 'september':
        return 9;
      case 'october':
        return 10;
      case 'november':
        return 11;
      case 'december':
        return 12;
      default:
        return 0;
    }
  }
}