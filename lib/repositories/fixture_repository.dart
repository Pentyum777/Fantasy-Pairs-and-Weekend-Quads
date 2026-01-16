import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/afl_fixture.dart';

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
  // EXCEL PARSING
  // ---------------------------------------------------------------------------
  void loadFromExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return;

    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.length <= 1) return;

    final headerRow = sheet.rows.first;

    // Build header index map (case-insensitive)
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

      // -----------------------------
      // ROUND LABEL NORMALIZATION
      // -----------------------------
      String roundLabel = _cellString(row, idxRound).trim();
      if (roundLabel.isEmpty) {
        print("⚠️ Row $r has empty ROUND label, skipping");
        continue;
      }

      final originalRoundLabel = roundLabel;
      final upper = roundLabel.toUpperCase();

      // Pre-Season → PS
      if (upper == "PRE-SEASON" || upper == "PRESEASON" || upper == "PS") {
        roundLabel = "PS";
      }

      // Opening Round → 0
      if (upper == "OPENING ROUND" || upper == "OR") {
        roundLabel = "0";
      }

      final dateText = _cellString(row, idxDate);
      final homeTeam = _cellString(row, idxHome);
      final awayTeam = _cellString(row, idxAway);
      final venue = _cellString(row, idxVenue);
      final time = idxTime != null ? _cellString(row, idxTime) : "";
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

      // -----------------------------
      // DATE PARSING
      // -----------------------------
      final upperDate = dateText.toUpperCase();
      final bool isTbcDate = dateText.trim().isEmpty ||
          upperDate.contains("TBC") ||
          upperDate.contains("TBA") ||
          upperDate.contains("TBD");

      DateTime? parsedDate;
      if (!isTbcDate) {
        parsedDate = _parseDateWithoutYear(dateText, defaultYear);

        // Combine with time if available
        if (parsedDate != null && time.isNotEmpty) {
          parsedDate = _combineDateAndTime(parsedDate, time);
        }
      }

      // -----------------------------
      // ROUND NUMBER PARSING
      // -----------------------------
      final int roundNumber = _parseRound(roundLabel);

      // 🔍 Debug print for this row
      print(
        "ROW $r | RAW_ROUND='$originalRoundLabel' → NORM_ROUND='$roundLabel' → round=$roundNumber | "
        "DATE='$dateText' → $parsedDate | HOME='$homeTeam' AWAY='$awayTeam' | "
        "matchId='${matchId ?? ""}' isPreseason=$isPreseason",
      );

      fixtures.add(
        AflFixture(
          roundLabel: roundLabel,
          round: roundNumber,
          date: parsedDate,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          venue: venue,
          time: time,
          source: source,
          matchId: matchId,
          isPreseason: isPreseason,
        ),
      );
    }

    print("✅ Finished loading fixtures. Total loaded: ${fixtures.length}");
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  String _cellString(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return "";
    final cell = row[index];
    final value = cell?.value;
    return value?.toString().trim() ?? "";
  }

  // -----------------------------
  // ROUND PARSER (PS = -1, OR = 0)
  // -----------------------------
  int _parseRound(String roundLabel) {
    final trimmed = roundLabel.trim().toUpperCase();

    // Pre-Season
    if (trimmed == "PS" || trimmed == "PRE-SEASON" || trimmed == "PRESEASON") {
      return -1;
    }

    // Opening Round
    if (trimmed == "0" || trimmed == "OPENING ROUND" || trimmed == "OR") {
      return 0;
    }

    // ROUND 1, ROUND 2, etc.
    final digitMatch = RegExp(r'(\d+)').firstMatch(trimmed);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  DateTime? _parseDateWithoutYear(String text, int year) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    // Format: Wednesday February 25
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
  // QUERY HELPERS (required by main.dart + game_view_screen.dart)
  // ---------------------------------------------------------------------------
  List<AflFixture> fixturesForRound(int round) {
    return fixtures.where((f) => f.round == round).toList();
  }

  List<AflFixture> preseasonFixtures() {
    return fixtures.where((f) => f.round == -1).toList();
  }

  List<int> allSeasonRounds() {
    final rounds = fixtures.map((f) => f.round).toSet().toList();
    rounds.sort();
    return rounds;
  }

  Future<void> refreshLiveScoresForRound(int round) async {
    final roundFixtures = fixturesForRound(round);

    for (final f in roundFixtures) {
      if (f.matchId != null && f.matchId!.isNotEmpty) {
        // Live score ingestion coming later
      }
    }
  }
}