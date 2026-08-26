class RoundHelper {
  /// Pre‑Season is represented as `null` everywhere in the app.
  static bool isPreseason(int? round) => round == null;

  /// Finals rounds use the same short codes as the fixture spreadsheet
  /// (see FixtureParser._finalsRoundCodes) so the UI always matches what's
  /// in the sheet.
  static const Map<int, String> _finalsRoundLabels = {
    25: "WF", // Wild Card Finals
    26: "QE", // Qualifying & Elimination Finals
    27: "SF", // Semi Finals
    28: "PF", // Preliminary Finals
    29: "GF", // Grand Final
  };

  /// Converts internal round value → UI label
  ///
  /// null   → "Pre‑Season"
  /// 0      → "Opening Round"
  /// 1–24   → "Round X"
  /// 25–29  → "WF" / "QE" / "SF" / "PF" / "GF"
  static String label(int? round) {
    if (round == null) return "Pre‑Season";
    if (round == 0) return "Opening Round";
    final finalsLabel = _finalsRoundLabels[round];
    if (finalsLabel != null) return finalsLabel;
    return "Round $round";
  }

  /// Converts UI token → internal round
  ///
  /// "PS" → null
  /// "R0" → 0
  /// "R1" → 1
  /// Invalid tokens → null (never -1)
  static int? fromToken(String token) {
    if (token == "PS") return null;

    if (token.startsWith("R")) {
      final parsed = int.tryParse(token.substring(1));
      if (parsed != null && parsed >= 0) {
        return parsed;
      }
    }

    return null; // fallback, never return -1
  }

  /// Converts internal round → UI token
  ///
  /// null → "PS"
  /// 0    → "R0"
  /// 1    → "R1"
  static String toToken(int? round) {
    if (round == null) return "PS";
    return "R$round";
  }
}