class RoundCompletionService {
  /// Tracks which rounds have been marked as completed.
  final Set<int> completedRounds = {};

  /// Returns true if the given round number has been completed.
  bool isCompleted(int roundNumber) {
    return completedRounds.contains(roundNumber);
  }

  /// Marks a round as completed.
  void markCompleted(int? round) {
  if (round == null) {
    // If you *don’t* want to track PS completion, you can early‑return:
    // return;
  }

  // Existing logic, now accepting null if you choose to handle it.
}
}