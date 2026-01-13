class AflFantasyScoreService {
  const AflFantasyScoreService();

  int calculateFantasy({
    required int kicks,
    required int handballs,
    required int marks,
    required int tackles,
    required int hitouts,
    required int freesFor,
    required int freesAgainst,
    required int goals,
    required int behinds,
  }) {
    int score = 0;

    score += kicks * 3;
    score += handballs * 2;
    score += marks * 3;
    score += tackles * 4;
    score += hitouts * 1;
    score += freesFor * 1;
    score -= freesAgainst * 3;
    score += goals * 6;
    score += behinds * 1;

    return score;
  }
}