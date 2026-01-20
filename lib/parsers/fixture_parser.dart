import 'dart:typed_data';
import 'package:excel/excel.dart';

import '../models/afl_fixture.dart';

class FixtureParser {
  List<AflFixture> parse(Uint8List bytes) {
    final List<AflFixture> fixtures = [];

    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return fixtures;

    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.length <= 1) return fixtures;

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
      return fixtures;
    }

    const int defaultYear = 2026;

    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];

      if (row.length < headerRow.length) continue;

      // -----------------------------
      // ROUND LABEL
      // -----------------------------
      String roundLabel = _cellString(row, idxRound).trim();
      if (roundLabel.isEmpty) continue;

      final originalRoundLabel = roundLabel;
      final upper = roundLabel.toUpperCase();

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

      // -----------------------------
      // PRE‑SEASON DETECTION
      // -----------------------------
      final bool isPreseasonFromRound =
          upper == "PRE-SEASON" ||
          upper == "PRESEASON" ||
          upper == "PS";

      final String preseasonRaw =
          idxIsPreseason != null ? _cellString(row, idxIsPreseason) : "";
      final bool isPreseasonFromColumn =
          preseasonRaw.toUpperCase() == "TRUE" || preseasonRaw == "1";

      final bool isPreseason = isPreseasonFromRound || isPreseasonFromColumn;

      if (homeTeam.isEmpty || awayTeam.isEmpty) continue;

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

        if (parsedDate != null && time.isNotEmpty) {
          parsedDate = _combineDateAndTime(parsedDate, time);
        }
      }

      // -----------------------------
      // ROUND NUMBER PARSING
      // -----------------------------
      final int? roundNumber =
          isPreseason ? null : _parseRound(roundLabel);

      print(
        "ROW $r | RAW_ROUND='$originalRoundLabel' → NORM_ROUND='$roundLabel' → round=${roundNumber ?? "null"} | "
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

    return fixtures;
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

  int _parseRound(String roundLabel) {
    final trimmed = roundLabel.trim().toUpperCase();

    if (trimmed == "0" || trimmed == "OPENING ROUND" || trimmed == "OR") {
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
}