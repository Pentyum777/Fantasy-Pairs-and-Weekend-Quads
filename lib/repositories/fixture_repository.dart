import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_fixture.dart';
import '../utils/afl_club_codes.dart';

class FixtureRepository {
  final List<AflFixture> fixtures = [];

  // ---------------------------------------------------------------------------
  // LOAD FIXTURES
  // ---------------------------------------------------------------------------
  Future<void> loadFixtures() async {
    final bytesMain = await rootBundle.load('assets/afl_fixtures_2026.xlsx');
    loadFromExcel(bytesMain.buffer.asUint8List());
  }

  // ---------------------------------------------------------------------------
  // REFRESH LIVE SCORES FOR A ROUND (placeholder for AFL.com.au)
  // ---------------------------------------------------------------------------
  Future<void> refreshLiveScoresForRound(int round) async {
    final roundFixtures = fixturesForRound(round);

    for (final f in roundFixtures) {
      if (f.matchId != null && f.matchId!.isNotEmpty) {
        // AFL.com.au ingestion coming soon
      }
    }
  }

  // ---------------------------------------------------------------------------
  // EXCEL PARSING
  // ---------------------------------------------------------------------------
  void loadFromExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return;

    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.length <= 1) return;

    final headerRow = sheet.rows.first;

    final Map<String, int> headerIndex = {};
    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      final value = cell?.value?.toString().trim();
      if (value != null && value.isNotEmpty) {
        headerIndex[value.toUpperCase()] = i;
      }
    }

    final idxRound = headerIndex["ROUND"];
    final idxDate = headerIndex["DATE"];
    final idxHome = headerIndex["HOME TEAM"];
    final idxAway = headerIndex["AWAY TEAM"];
    final idxVenue = headerIndex["VENUE"];
    final idxTime = headerIndex["TIME"];
    final idxSource = headerIndex["GAME DATA SOURCE"];
    final idxMatchId = headerIndex["MATCH ID"];
    final idxIsPreseason = headerIndex["ISPRESEASON"];

    if (idxRound == null ||
        idxDate == null ||
        idxHome == null ||
        idxAway == null ||
        idxVenue == null) {
      print("❌ Missing required columns in fixture sheet");
      return;
    }

    const int defaultYear = 2026;

    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];

      if (row.length < headerRow.length) {
        print("⚠️ Skipping malformed row $r (not enough columns)");
        continue;
      }

      String roundLabel = _cellString(row, idxRound).trim();
      if (roundLabel.isEmpty) continue;

      final upper = roundLabel.toUpperCase();
      if (upper == "OPENING ROUND" || upper == "OR") {
        roundLabel = "0";
      }

      final dateText = _cellString(row, idxDate);

      // ------------------------------------------------------------
      // NORMALIZE FIXTURE CLUB NAMES (AFL-standard codes)
      // ------------------------------------------------------------
      final rawHome = _cellString(row, idxHome);
      final rawAway = _cellString(row, idxAway);

      final homeTeam = AflClubCodes.normalize(rawHome);
      final awayTeam = AflClubCodes.normalize(rawAway);
      // ------------------------------------------------------------

      final venue = _cellString(row, idxVenue);
      final timeText = idxTime != null ? _cellString(row, idxTime) : "";
      final source = idxSource != null ? _cellString(row, idxSource) : "";

      final String? matchId =
          idxMatchId != null ? _cellString(row, idxMatchId) : null;

      final String preseasonRaw =
          idxIsPreseason != null ? _cellString(row, idxIsPreseason) : "";
      final bool isPreseason =
          preseasonRaw.toUpperCase() == "TRUE" || preseasonRaw == "1";

      if (homeTeam.isEmpty || awayTeam.isEmpty) {
        print("⚠️ Skipping row $r (missing home/away team)");
        continue;
      }

      final upperDate = dateText.toUpperCase();
      final bool isTbcDate = dateText.trim().isEmpty ||
          upperDate.contains("TBC") ||
          upperDate.contains("TBA") ||
          upperDate.contains("TBD");

      DateTime? parsedDate;
      if (!isTbcDate) {
        parsedDate = _parseDateWithoutYear(dateText, defaultYear);

        if (parsedDate != null && timeText.isNotEmpty) {
          parsedDate = _combineDateAndTime(parsedDate, timeText);
        }
      }

      final int roundNumber = _parseRound(roundLabel);

      fixtures.add(
        AflFixture(
          roundLabel: roundLabel,
          round: roundNumber,
          date: parsedDate,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          venue: venue,
          time: timeText,
          source: source,
          matchId: matchId,
          isPreseason: isPreseason,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS (MUST BE INSIDE THE CLASS)
  // ---------------------------------------------------------------------------
  String _cellString(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return "";
    final cell = row[index];
    final value = cell?.value;
    return value?.toString().trim() ?? "";
  }

  int _parseRound(String roundLabel) {
    final trimmed = roundLabel.trim().toUpperCase();
    if (trimmed == "0") return 0;

    final digitMatch = RegExp(r'(\d+)').firstMatch(trimmed);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  DateTime? _parseDateWithoutYear(String text, int year) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    final month = _monthFromName(parts[1]);
    if (month == 0) return null;

    final day = int.tryParse(parts[2].replaceAll(RegExp(r'\D'), '')) ?? 1;

    return DateTime(year, month, day);
  }

  DateTime _combineDateAndTime(DateTime date, String timeText) {
    final parts = timeText.split(RegExp(r'[:\s]'));
    if (parts.length < 3) return date;

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final ampm = parts[2].toUpperCase();

    if (ampm == "PM" && hour != 12) hour += 12;
    if (ampm == "AM" && hour == 12) hour = 0;

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  int _monthFromName(String monthName) {
    switch (monthName.toLowerCase()) {
      case 'january':
      case 'jan':
        return 1;
      case 'february':
      case 'feb':
        return 2;
      case 'march':
      case 'mar':
        return 3;
      case 'april':
      case 'apr':
        return 4;
      case 'may':
        return 5;
      case 'june':
      case 'jun':
        return 6;
      case 'july':
      case 'jul':
        return 7;
      case 'august':
      case 'aug':
        return 8;
      case 'september':
      case 'sep':
        return 9;
      case 'october':
      case 'oct':
        return 10;
      case 'november':
      case 'nov':
        return 11;
      case 'december':
      case 'dec':
        return 12;
      default:
        return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // QUERY HELPERS
  // ---------------------------------------------------------------------------
  List<AflFixture> fixturesForRound(int round) {
    return fixtures.where((f) => !f.isPreseason && f.round == round).toList();
  }

  List<AflFixture> preseasonFixtures() {
    return fixtures.where((f) => f.isPreseason).toList();
  }

  List<int> allSeasonRounds() {
    final rounds = fixtures
        .where((f) => !f.isPreseason)
        .map((f) => f.round)
        .toSet()
        .toList();
    rounds.sort();
    return rounds;
  }
}