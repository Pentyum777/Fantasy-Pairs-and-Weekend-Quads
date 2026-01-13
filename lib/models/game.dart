class Game {
  final String id;
  final String label; // e.g. "Game 1", or a match name
  final List<String> players;

  Game({
    required this.id,
    required this.label,
    required this.players,
  });
}