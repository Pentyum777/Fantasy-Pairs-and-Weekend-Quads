class AflClubCodes {
  static String normalize(String input) {
    final code = input.trim().toUpperCase();

    const aliases = {
      "NM": "NTH",
      "NORTH": "NTH",
      "NORTH MELBOURNE": "NTH",
      "PA": "PTA",
      "PORT": "PTA",
      "PORT ADELAIDE": "PTA",
      "GC": "GCS",
      "GOLD COAST": "GCS",
      "GOLD COAST SUNS": "GCS",
      "SK": "STK",
      "STKILDA": "STK",
      "ST KILDA": "STK",
      "WB": "WB",
      "WBD": "WB",
      "WESTERN BULLDOGS": "WB",
      "BRISBANE": "BRI",
      "BRIS": "BRI",
      "GEELONG": "GEE",
      "CARLTON": "CAR",
      "COLLINGWOOD": "COL",
      "MELBOURNE": "MEL",
      "ESSENDON": "ESS",
      "FREMANTLE": "FRE",
      "HAWTHORN": "HAW",
      "RICHMOND": "RIC",
      "SYDNEY": "SYD",
      "WEST COAST": "WCE",
      "ADELAIDE": "ADE",
      "GWS": "GWS",
      "GREATER WESTERN SYDNEY": "GWS",
    };

    return aliases[code] ?? code;
  }
}