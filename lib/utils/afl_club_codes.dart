class AflClubCodes {
  static String normalize(String input) {
    final code = input.trim().toUpperCase();

    const aliases = {
      // ADELAIDE
      "ADELAIDE": "ADE",
      "ADELAIDE CROWS": "ADE",
      "CROWS": "ADE",

      // BRISBANE
      "BRISBANE": "BRL",
      "BRISBANE LIONS": "BRL",
      "LIONS": "BRL",

      // CARLTON
      "CARLTON": "CAR",
      "CARLTON BLUES": "CAR",
      "BLUES": "CAR",

      // COLLINGWOOD
      "COLLINGWOOD": "COL",
      "COLLINGWOOD MAGPIES": "COL",
      "MAGPIES": "COL",
      "PIES": "COL",

      // ESSENDON
      "ESSENDON": "ESS",
      "ESSENDON BOMBERS": "ESS",
      "BOMBERS": "ESS",
      "DONS": "ESS",

      // FREMANTLE
      "FREMANTLE": "FRE",
      "FREMANTLE DOCKERS": "FRE",
      "DOCKERS": "FRE",

      // GEELONG
      "GEELONG": "GEE",
      "GEELONG CATS": "GEE",
      "CATS": "GEE",

      // GOLD COAST
      "GOLD COAST": "GCS",
      "GOLD COAST SUNS": "GCS",
      "SUNS": "GCS",

      // GWS
"GWS": "GWS",
"GREATER WESTERN SYDNEY": "GWS",
"GREATER WESTERN SYDNEY GIANTS": "GWS",
"GWS GIANTS": "GWS", // <-- add this
"GIANTS": "GWS",

      // HAWTHORN
      "HAWTHORN": "HAW",
      "HAWTHORN HAWKS": "HAW",
      "HAWKS": "HAW",

      // MELBOURNE
      "MELBOURNE": "MELB",
      "MELBOURNE DEMONS": "MELB",
      "DEMONS": "MELB",
      "DEES": "MELB",

      // NORTH MELBOURNE
      "NORTH": "NTH",
      "NORTH MELBOURNE": "NTH",
      "NORTH MELBOURNE KANGAROOS": "NTH",
      "KANGAROOS": "NTH",
      "ROOS": "NTH",

      // PORT ADELAIDE
      "PORT": "PTA",
      "PORT ADELAIDE": "PTA",
      "PORT ADELAIDE POWER": "PTA",
      "POWER": "PTA",

      // RICHMOND
      "RICHMOND": "RIC",
      "RICHMOND TIGERS": "RIC",
      "TIGERS": "RIC",
      "TIGES": "RIC",

      // ST KILDA
      "ST KILDA": "STK",
      "STKILDA": "STK",
      "ST KILDA SAINTS": "STK",
      "SAINTS": "STK",

      // SYDNEY
      "SYDNEY": "SYD",
      "SYDNEY SWANS": "SYD",
      "SWANS": "SYD",

      // WEST COAST
      "WEST COAST": "WCE",
      "WEST COAST EAGLES": "WCE",
      "EAGLES": "WCE",

      // WESTERN BULLDOGS
      "WESTERN BULLDOGS": "WBD",
      "BULLDOGS": "WBD",
      "DOGS": "WBD",
      "WB": "WBD",
    };

    return aliases[code] ?? code;
  }
}