class RoundCompletionService {
  /// Tracks which rounds have been marked as completed.
  final Set<int> completedRounds = {};

  /// Returns true if the given round number has been completed.
  bool isCompleted(int roundNumber) {
    return completedRounds.contains(roundNumber);
  }

  /// Marks a round as completed.
  void markCompleted(int roundNumber) {
    completedRounds.add(roundNumber);
  }
}