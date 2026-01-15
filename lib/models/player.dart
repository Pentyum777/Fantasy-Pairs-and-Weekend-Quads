class Player {
  final String name;
  final String team;
  final String position;
  final bool isPrizeWinner; // ✅ NEW FIELD

  int fantasyScore;

  Player({
    required this.name,
    required this.team,
    required this.position,
    this.fantasyScore = 0,
    this.isPrizeWinner = false, // ✅ default
  });

  Player copyWith({
    String? name,
    String? team,
    String? position,
    int? fantasyScore,
    bool? isPrizeWinner,
  }) {
    return Player(
      name: name ?? this.name,
      team: team ?? this.team,
      position: position ?? this.position,
      fantasyScore: fantasyScore ?? this.fantasyScore,
      isPrizeWinner: isPrizeWinner ?? this.isPrizeWinner,
    );
  }
}