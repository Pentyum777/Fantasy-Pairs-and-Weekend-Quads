class AflClubCodes {
  static const Map<String, String> _map = {
    // ADELAIDE
    "ADE": "ADE",
    "ADELAIDE": "ADE",
    "ADELAIDE CROWS": "ADE",

    // BRISBANE
    "BRL": "BRL",
    "BRISBANE": "BRL",
    "BRISBANE LIONS": "BRL",
    "LIONS": "BRL",

    // CARLTON
    "CAR": "CAR",
    "CARL": "CAR",
    "CARLTON": "CAR",
    "CARLTON BLUES": "CAR",

    // COLLINGWOOD
    "COL": "COL",
    "COLL": "COL",
    "COLLINGWOOD": "COL",
    "COLLINGWOOD MAGPIES": "COL",

    // ESSENDON
    "ESS": "ESS",
    "ESSENDON": "ESS",
    "ESSENDON BOMBERS": "ESS",

    // FREMANTLE
    "FRE": "FRE",
    "FREMANTLE": "FRE",
    "FREMANTLE DOCKERS": "FRE",

    // GEELONG
    "GEE": "GEE",
    "GEELONG": "GEE",
    "GEELONG CATS": "GEE",

    // GOLD COAST
    "GCS": "GCS",
    "GOLD COAST": "GCS",
    "GOLD COAST SUNS": "GCS",
    "SUNS": "GCS",

    // GWS
    "GWS": "GWS",
    "GIANTS": "GWS",
    "GWS GIANTS": "GWS",
    "GREATER WESTERN SYDNEY": "GWS",
    "GREATER WESTERN SYDNEY GIANTS": "GWS",

    // HAWTHORN
    "HAW": "HAW",
    "HAWTHORN": "HAW",
    "HAWTHORN HAWKS": "HAW",

    // MELBOURNE  → MELB
    "MEL": "MELB",
    "MELB": "MELB",
    "MELBOURNE": "MELB",
    "MELBOURNE DEMONS": "MELB",
    "DEMONS": "MELB",

    // NORTH MELBOURNE
    "NTH": "NTH",
    "NORTH": "NTH",
    "NORTH MELBOURNE": "NTH",
    "NORTH MELBOURNE KANGAROOS": "NTH",

    // PORT ADELAIDE
    "PTA": "PTA",
    "PORT": "PTA",
    "PORT ADELAIDE": "PTA",
    "PORT ADELAIDE POWER": "PTA",

    // RICHMOND
    "RIC": "RIC",
    "RICHMOND": "RIC",
    "RICHMOND TIGERS": "RIC",

    // ST KILDA
    "STK": "STK",
    "SAINTS": "STK",
    "ST KILDA": "STK",
    "ST KILDA SAINTS": "STK",

    // SYDNEY
    "SYD": "SYD",
    "SWANS": "SYD",
    "SYDNEY": "SYD",
    "SYDNEY SWANS": "SYD",

    // WEST COAST
    "WCE": "WCE",
    "WEST COAST": "WCE",
    "WEST COAST EAGLES": "WCE",
    "EAGLES": "WCE",

    // WESTERN BULLDOGS
    "WBD": "WBD",
    "WB": "WBD",
    "BULLDOGS": "WBD",
    "WESTERN BULLDOGS": "WBD",
  };

  static String normalize(String raw) {
    if (raw.isEmpty) return "";
    final key = raw.trim().toUpperCase();
    return _map[key] ?? "";
  }
}
