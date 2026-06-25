import 'dart:typed_data';
import 'package:excel/excel.dart';

import '../models/afl_fixture.dart';
import '../utils/afl_club_codes.dart';

class FixtureParser {
  final Map<String, dynamic> dfsMap;

  FixtureParser(this.dfsMap);

  List<AflFixture> parse(Uint8List bytes) {
    print("DEBUG: FixtureParser.parse() called");
    print("DEBUG: bytes length = ${bytes.length}");

    final List<AflFixture> fixtures = [];

    final excel = Excel.decodeBytes(bytes);

    print("DEBUG: excel.tables keys = ${excel.tables.keys}");

    if (excel.tables.isEmpty) {
      print("❌ DEBUG: No tables found in XLSX file");
      return fixtures;
    }

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    print("DEBUG: Using sheet '$sheetName'");
    print("DEBUG: sheet row count = ${sheet?.rows.length}");

    if (sheet == null || sheet.rows.length <= 1) {
      print("❌ DEBUG: Sheet is empty or has no data rows");
      return fixtures;
    }

    final headerRow = sheet.rows.first;

    print("DEBUG: Header row = ${headerRow.map((c) => c?.value).toList()}");

    final Map<String, int> headerIndex = {};
    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      final value = cell?.value?.toString().trim();
      if (value != null && value.isNotEmpty) {
        headerIndex[value.toUpperCase()] = i;
      }
    }

    print("DEBUG: headerIndex = $headerIndex");

    final idxRound = headerIndex["ROUND"];
    final idxDate = headerIndex["DATE"];
    final idxHome = headerIndex["HOME TEAM"];
    final idxAway = headerIndex["AWAY TEAM"];
    final idxVenue = headerIndex["VENUE"];
    final idxTime = headerIndex["TIME"];
    final idxSource = headerIndex["GAME DATA SOURCE"];
    final idxMatchId = headerIndex["MATCH ID"];
    final idxIsPreseason = headerIndex["ISPRESEASON"];

    final idxFootyInfo = headerIndex["FOOTY INFO"];
    final idxFootyInfoId = headerIndex["FOOTY INFO ID"];

    if (idxRound == null ||
        idxDate == null ||
        idxHome == null ||
        idxAway == null ||
        idxVenue == null) {
      print("❌ DEBUG: Missing required columns in fixture sheet");
      return fixtures;
    }

    const int defaultYear = 2026;

    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];

      while (row.length < headerRow.length) {
        row.add(null);
      }

      String roundLabel = _cellString(row, idxRound).trim();
      if (roundLabel.isEmpty) {
        print("DEBUG: Row $r skipped (empty round)");
        continue;
      }

      final originalRoundLabel = roundLabel;
      final upper = roundLabel.toUpperCase();

      if (upper == "OPENING ROUND" || upper == "OR") {
        roundLabel = "0";
      }

      final dateText = _cellString(row, idxDate);

      final homeTeamRaw = _cellString(row, idxHome);
      final awayTeamRaw = _cellString(row, idxAway);

      final homeTeam = _normalizeClub(homeTeamRaw);
      final awayTeam = _normalizeClub(awayTeamRaw);

      final venue = _cellString(row, idxVenue);
      final time = idxTime != null ? _cellString(row, idxTime) : "";
      final source = idxSource != null ? _cellString(row, idxSource) : "";
      final String? matchId =
          idxMatchId != null ? _cellString(row, idxMatchId) : null;

      final bool isPreseasonFromRound =
          upper == "PRE-SEASON" ||
          upper == "PRESEASON" ||
          upper == "PS";

      final String preseasonRaw =
          idxIsPreseason != null ? _cellString(row, idxIsPreseason) : "";
      final bool isPreseasonFromColumn =
          preseasonRaw.toUpperCase() == "TRUE" || preseasonRaw == "1";

      final bool isPreseason = isPreseasonFromRound || isPreseasonFromColumn;

      if (homeTeam.isEmpty || awayTeam.isEmpty) {
        print("DEBUG: Row $r skipped (empty home/away team)");
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

        if (parsedDate != null && time.isNotEmpty) {
          parsedDate = _combineDateAndTime(parsedDate, time);
        }
      }

      final int? roundNumber =
          isPreseason ? null : _parseRound(roundLabel);

      final footyInfoUrl =
          idxFootyInfo != null ? _cellString(row, idxFootyInfo) : null;

      final footyInfoId =
          idxFootyInfoId != null ? _cellString(row, idxFootyInfoId) : null;

      // ⭐ NEW: Lookup DFS ID using matchId
      final dfsId = matchId != null ? dfsMap[matchId] : null;

      print(
        "ROW $r | RAW_ROUND='$originalRoundLabel' → NORM_ROUND='$roundLabel' → round=${roundNumber ?? "null"} | "
        "DATE='$dateText' → $parsedDate | HOME='$homeTeamRaw' → '$homeTeam' | "
        "AWAY='$awayTeamRaw' → '$awayTeam' | matchId='${matchId ?? ""}' dfsId='${dfsId ?? ""}' isPreseason=$isPreseason | "
        "footyInfoUrl='$footyInfoUrl' footyInfoId='$footyInfoId'",
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
          footyInfoUrl: footyInfoUrl,
          footyInfoId: footyInfoId,

          // ⭐ NEW FIELD
          dfsId: dfsId?.toString(),
        ),
      );
    }

    print("DEBUG: Total fixtures parsed = ${fixtures.length}");
    return fixtures;
  }

  String _cellString(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return "";
    final cell = row[index];
    final value = cell?.value;
    return value?.toString().trim() ?? "";
  }

  String _normalizeClub(String raw) {
    final cleaned = raw
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return "";

    final base = AflClubCodes.normalize(cleaned);

    const overrides = {
      "CARL": "CAR",
      "CARLTON": "CAR",
      "COLL": "COL",
      "COLLINGWOOD": "COL",
      "BRI": "BRL",
      "BRISBANE": "BRL",
      "BRISBANE LIONS": "BRL",
      "MELB": "MELB",
      "MELBOURNE": "MELB",
      "RICH": "RIC",
      "RICHMOND": "RIC",
      "WB": "WBD",
      "WESTERN BULLDOGS": "WBD",
      "WESTERN BULLDOGS FOOTBALL CLUB": "WBD",
      "GWS GIANTS": "GWS",
      "GWS": "GWS",
    };

    return overrides[base.toUpperCase()] ?? base;
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
    // Handle "7.30pm" or "12.35pm" format
    final dotMatch = RegExp(r'^(\d{1,2})\.(\d{2})(am|pm)$', caseSensitive: false)
        .firstMatch(timeText.trim());
    if (dotMatch != null) {
      int hour = int.tryParse(dotMatch.group(1)!) ?? 0;
      final minute = int.tryParse(dotMatch.group(2)!) ?? 0;
      final ampm = dotMatch.group(3)!.toUpperCase();
      if (ampm == "PM" && hour != 12) hour += 12;
      if (ampm == "AM" && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }

    // Handle "7:30 pm" or "7:30pm" format
    final parts = timeText.split(RegExp(r'[:\s]'));
    if (parts.length < 2) return date;

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final ampmPart = parts.length > 2 ? parts[2] : parts[1].replaceAll(RegExp(r'[0-9]'), '');
    final ampm = ampmPart.toUpperCase();

    if (ampm == "PM" && hour != 12) hour += 12;
    if (ampm == "AM" && hour == 12) hour = 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
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
