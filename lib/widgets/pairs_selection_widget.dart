import 'package:flutter/material.dart';
import '../models/afl_player.dart';

class PairsSelectionWidget extends StatelessWidget {
  final List<AflPlayer> players;

  const PairsSelectionWidget({
    super.key,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<AflPlayer>.from(players)
      ..sort(
        (a, b) => a.shortName.toLowerCase().compareTo(
              b.shortName.toLowerCase(),
            ),
      );

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final p = sorted[index];
        return ListTile(
          title: Text(p.shortName),
          subtitle: Text(p.club),
        );
      },
    );
  }
}