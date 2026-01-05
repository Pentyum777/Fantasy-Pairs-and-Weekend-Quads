enum GameType {
  thursdayPairs,
  fridayPairs,
  saturdayPairs,
  sundayPairs,
  mondayPairs,
  weekendQuads,
}

extension GameTypeLabel on GameType {
  String get label {
    switch (this) {
      case GameType.thursdayPairs:
        return "Thursday Pairs";
      case GameType.fridayPairs:
        return "Friday Pairs";
      case GameType.saturdayPairs:
        return "Saturday Pairs";
      case GameType.sundayPairs:
        return "Sunday Pairs";
      case GameType.mondayPairs:
        return "Monday Pairs";
      case GameType.weekendQuads:
        return "Weekend Quads";
    }
  }
}