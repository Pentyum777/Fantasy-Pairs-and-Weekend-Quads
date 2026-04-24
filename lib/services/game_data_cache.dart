import '../models/punter_selection.dart';
import '../models/afl_player_match_stats.dart';
import '../models/afl_player.dart';

/// Holds loaded game state for each (season, round, gameType) key so that
/// navigating away from a game and back does not trigger a fresh network load.
///
/// Lives in GameTypeSelectionScreen and is passed into every GameViewScreen.
/// All selections are stored as deep copies (via JSON) to prevent cross-game
/// mutation when the same list objects are reused.
class GameDataCache {
  // selections keyed by "season-round-gameType" — stored as JSON for deep copy
  final Map<String, List<Map<String, dynamic>>> _selectionsJson = {};

  // live stats keyed by the same key
  final Map<String, Map<String, AflPlayerMatchStats>> _stats = {};

  // season players keyed by season
  final Map<int, List<AflPlayer>> _players = {};

  // ---------------------------------------------------------------
  // Selections — always deep-copied via JSON
  // ---------------------------------------------------------------

  bool hasSelections(String key) {
    if (!_selectionsJson.containsKey(key)) return false;
    final list = _selectionsJson[key]!;
    // Only consider it cached if it has real data
    return list.any((p) {
      final name = (p['punterName'] as String? ?? '').trim();
      final num = p['punterNumber']?.toString() ?? '';
      final isPlaceholder = name == 'P$num' || RegExp(r'^P\d+$').hasMatch(name);
      if (!isPlaceholder && name.isNotEmpty) return true;
      final picks = p['picks'] as List<dynamic>? ?? [];
      return picks.any((pick) => (pick as Map<String, dynamic>)['player'] != null);
    });
  }

  List<PunterSelection> getSelections(String key) {
    final jsonList = _selectionsJson[key] ?? [];
    return jsonList.map((j) => PunterSelection.fromJson(j)).toList();
  }

  void setSelections(String key, List<PunterSelection> value) {
    // Only cache if we have real data
    final hasReal = value.any((p) {
      final name = p.punterName.trim();
      final isPlaceholder = RegExp(r'^P\d+$').hasMatch(name);
      if (!isPlaceholder && name.isNotEmpty) return true;
      return p.picks.any((pick) => pick.player != null);
    });
    if (!hasReal) return;
    // Deep copy via JSON serialization
    _selectionsJson[key] = value.map((p) => p.toJson()).toList();
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
  // Custom game fixture IDs
  // ---------------------------------------------------------------

  // selectedFixtureIds keyed by "season-round-custom_game"
  final Map<String, List<String>> _fixtureIds = {};

  bool hasFixtureIds(String key) =>
      _fixtureIds.containsKey(key) && _fixtureIds[key]!.isNotEmpty;

  List<String> getFixtureIds(String key) => _fixtureIds[key] ?? [];

  void setFixtureIds(String key, List<String> ids) {
    if (ids.isEmpty) return;
    _fixtureIds[key] = List<String>.from(ids);
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