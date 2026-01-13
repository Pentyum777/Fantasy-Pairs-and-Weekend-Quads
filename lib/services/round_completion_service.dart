class RoundCompletionService {
  final Set<int> completedRounds = {};

  bool isCompleted(int roundNumber) {
    return completedRounds.contains(roundNumber);
  }

  void markCompleted(int roundNumber) {
    completedRounds.add(roundNumber);
  }
}