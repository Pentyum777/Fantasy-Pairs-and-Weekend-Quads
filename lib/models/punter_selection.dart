import 'afl_player.dart';

class PunterSelection {
  String name;
  final List<AflPlayer?> players;

  PunterSelection(int count)
      : name = "",
        players = List.generate(count, (_) => null);
}