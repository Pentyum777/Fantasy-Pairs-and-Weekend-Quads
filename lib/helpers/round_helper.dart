class RoundHelper {
  /// Pre‑Season is represented as `null` everywhere in the app.
  static bool isPreseason(int? round) => round == null;

  /// Converts internal round value → UI label
  ///
  /// null → "Pre‑Season"
  /// 0    → "Opening Round"
  /// 1–24 → "Round X"
  static String label(int? round) {
    if (round == null) return "Pre‑Season";
    if (round == 0) return "Opening Round";
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