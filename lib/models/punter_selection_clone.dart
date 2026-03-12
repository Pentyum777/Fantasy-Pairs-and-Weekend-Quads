import 'punter_selection.dart';
import 'player_pick.dart';

extension PunterSelectionClone on PunterSelection {
  PunterSelection clone() {
    return PunterSelection(
      punterNumber: punterNumber,
      punterName: punterName,
      picks: picks.map((p) => p.clone()).toList(),
    );
  }
}

extension PlayerPickClone on PlayerPick {
  PlayerPick clone() {
    return PlayerPick(
      pickNumber: pickNumber,
      player: player, // shallow copy is fine
      stats: stats == null ? null : Map<String, dynamic>.from(stats!),
    );
  }
}