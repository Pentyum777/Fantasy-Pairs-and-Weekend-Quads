import '../models/punter_selection.dart';
import '../models/afl_player_match_stats.dart';
import '../models/afl_player.dart';

/// Holds loaded game state so that navigating away and back does not
/// trigger a fresh network load.
///
/// Lives in GameTypeSelectionScreen and is passed into every GameViewScreen.
class GameDataCache {
  // selections keyed by "season-round-gameType"
  final Map<String, List<PunterSelection>> _selections = {};

  // ⭐ Live stats keyed by "season-round" (shared across all game types).
  // All game types in the same round use the same player stats pool.
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
  // Live stats — keyed by "season-round" not "season-round-gameType"
  // so all game types in a round share the same cached stats.
  // ---------------------------------------------------------------

  /// Strips the gameType suffix to get the round-level key.
  /// "2026-5-sunday_pairs" -> "2026-5"
  static String _roundKey(String key) {
    final parts = key.split('-');
    if (parts.length >= 2) return '${parts[0]}-${parts[1]}';
    return key;
  }

  bool hasStats(String key) {
    final rk = _roundKey(key);
    return _stats.containsKey(rk) && _stats[rk]!.isNotEmpty;
  }

  Map<String, AflPlayerMatchStats> getStats(String key) =>
      _stats[_roundKey(key)] ?? {};

  void setStats(String key, Map<String, AflPlayerMatchStats> value) {
    _stats[_roundKey(key)] = value;
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