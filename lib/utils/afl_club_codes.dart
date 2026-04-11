class AflClubCodes {
  static const Map<String, String> _map = {
    // ADELAIDE
    "ADE": "ADE",
    "ADELAIDE": "ADE",
    "ADELAIDE CROWS": "ADE",
    "CROWS": "ADE",

    // BRISBANE
    "BRL": "BRL",
    "BRIS": "BRL",
    "BRISBANE": "BRL",
    "BRISBANE LIONS": "BRL",
    "LIONS": "BRL",

    // CARLTON
    "CAR": "CAR",
    "CARL": "CAR",
    "CARLTON": "CAR",
    "CARLTON BLUES": "CAR",
    "BLUES": "CAR",

    // COLLINGWOOD
    "COL": "COL",
    "COLL": "COL",
    "COLLINGWOOD": "COL",
    "COLLINGWOOD MAGPIES": "COL",
    "MAGPIES": "COL",
    "PIES": "COL",

    // ESSENDON
    "ESS": "ESS",
    "ESSENDON": "ESS",
    "ESSENDON BOMBERS": "ESS",
    "BOMBERS": "ESS",

    // FREMANTLE
    "FRE": "FRE",
    "FREMANTLE": "FRE",
    "FREMANTLE DOCKERS": "FRE",
    "DOCKERS": "FRE",

    // GEELONG
    "GEE": "GEE",
    "GEELONG": "GEE",
    "GEELONG CATS": "GEE",
    "CATS": "GEE",

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
    "HAWKS": "HAW",

    // MELBOURNE → MELB
    "MEL": "MELB",
    "MELB": "MELB",
    "MELBOURNE": "MELB",
    "MELBOURNE DEMONS": "MELB",
    "DEMONS": "MELB",

    // NORTH MELBOURNE
    "NM": "NTH",
    "NTH": "NTH",
    "NORTH": "NTH",
    "NORTH MELBOURNE": "NTH",
    "NORTH MELBOURNE KANGAROOS": "NTH",
    "KANGAROOS": "NTH",
    "ROOS": "NTH",

    // PORT ADELAIDE
    "PTA": "PTA",
    "PORT": "PTA",
    "PORT ADELAIDE": "PTA",
    "PORT ADELAIDE POWER": "PTA",
    "POWER": "PTA",

    // RICHMOND
    "RIC": "RIC",
    "RICHMOND": "RIC",
    "RICHMOND TIGERS": "RIC",
    "TIGERS": "RIC",
    "TIGS": "RIC",

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
    "DOGS": "WBD",
    "WESTERN BULLDOGS": "WBD",
  };

  static String normalize(String raw) {
    if (raw.isEmpty) return "";
    final key = raw.trim().toUpperCase();
    return _map[key] ?? "";
  }
}