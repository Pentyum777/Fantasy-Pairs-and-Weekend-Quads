import '../models/afl_player.dart';
import 'afl_player_parser.dart';

class AflParser {
  /// Generic entry point to parse AFL players from JSON.
  static List<AflPlayer> parsePlayers(dynamic json) {
    return AflPlayerParser.parse(json);
  }
}