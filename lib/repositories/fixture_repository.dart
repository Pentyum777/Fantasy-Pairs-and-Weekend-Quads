import 'dart:typed_data';
import '../models/afl_fixture.dart';
import '../parsers/fixture_parser.dart';

class FixtureRepository {
  List<AflFixture> fixtures = [];

  void loadFromExcel(Uint8List bytes) {
    fixtures = parseAflFixtures2026(bytes);
  }

  List<AflFixture> fixturesForRound(int round) {
    return fixtures.where((f) => f.round == round).toList();
  }
}