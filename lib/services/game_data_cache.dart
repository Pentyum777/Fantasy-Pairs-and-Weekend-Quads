import '../models/punter_selection.dart';
import '../models/afl_player_match_stats.dart';
import '../models/afl_player.dart';

/// Holds loaded game state for each (season, round, gameType) key so that
/// navigating away from a game and back does not trigger a fresh network load.
///
/// Lives in GameTypeSelectionScreen and is passed into every GameViewScreen.
class GameDataCache {
  // selections keyed by "season-round-gameType"
  final Map<String, List<PunterSelection>> _selections = {};

  // live stats keyed by the same key
  final Map<String, Map<String, AflPlayerMatchStats>> _stats = {};

  // season players keyed by season
  final Map<int, List<AflPlayer>> _players = {};

  // ---------------------------------------------------------------
  // Selections
  // ---------------------------------------------------------------

  bool hasSelections(String key) => _selections.containsKey(key);

  List<PunterSelection> getSelections(String key) => _selections[key]!;

  void setSelections(String key, List<PunterSelection> value) {
    _selections[key] = value;
  }

  // ---------------------------------------------------------------
  // Live stats
  // ---------------------------------------------------------------

  bool hasStats(String key) =>
      _stats.containsKey(key) && _stats[key]!.isNotEmpty;

  Map<String, AflPlayerMatchStats> getStats(String key) =>
      _stats[key] ?? {};

  void setStats(String key, Map<String, AflPlayerMatchStats> value) {
    _stats[key] = value;
  }

  // ---------------------------------------------------------------
  // Season players
  // ---------------------------------------------------------------

  bool hasPlayers(int season) =>
      _players.containsKey(season) && _players[season]!.isNotEmpty;

  List<AflPlayer> getPlayers(int season) => _players[season]!;

  void setPlayers(int season, List<AflPlayer> value) {
    _players[season] = value;
  }
}