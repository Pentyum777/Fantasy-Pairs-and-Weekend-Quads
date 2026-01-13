class Player {
  final String name;
  final String team;
  final String position;

  int fantasyScore; // NEW FIELD

  Player({
    required this.name,
    required this.team,
    required this.position,
    this.fantasyScore = 0, // default score
  });
}