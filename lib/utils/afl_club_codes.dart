// lib/utils/afl_club_codes.dart

class AflClubCodes {
  static const Set<String> aflCodes = {
    "ade","bri","carl","coll","ess","fre","geel","gc","gws",
    "haw","melb","nm","port","rich","stk","syd","wce","wb"
  };

  static String normalize(String raw) {
    final c = raw.trim().toLowerCase();

    // Already an AFL-standard code?
    if (aflCodes.contains(c)) return c.toUpperCase();

    // Full name → AFL code
if (c.contains("adelaide") && c.contains("crows")) return "ADE";
if (c.contains("brisbane")) return "BRI";
if (c.contains("carlton")) return "CARL";
if (c.contains("collingwood")) return "COLL";
if (c.contains("essendon")) return "ESS";
if (c.contains("fremantle")) return "FRE";
if (c.contains("geelong")) return "GEEL";
if (c.contains("gold coast")) return "GC";
if (c.contains("gws") || c.contains("giants")) return "GWS";
if (c.contains("hawthorn")) return "HAW";
if (c.contains("melbourne")) return "MELB";
if (c.contains("north melbourne")) return "NM";
if (c.contains("port adelaide")) return "PORT";
if (c.contains("richmond")) return "RICH";
if (c.contains("st kilda")) return "STK";
if (c.contains("sydney")) return "SYD";
if (c.contains("west coast")) return "WCE";
if (c.contains("western") || c.contains("bulldogs")) return "WB";

    return raw.toUpperCase();
  }
}