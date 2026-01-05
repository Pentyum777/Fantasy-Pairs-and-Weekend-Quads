import 'package:flutter/material.dart';
import '../models/game_type.dart';

class GameTypeSelector extends StatelessWidget {
  final Function(GameType) onSelect;

  const GameTypeSelector({
    super.key,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _btn(GameType.thursdayPairs),
          _btn(GameType.fridayPairs),
          _btn(GameType.saturdayPairs),
          _btn(GameType.sundayPairs),
          _btn(GameType.mondayPairs),
          const SizedBox(height: 20),
          _btn(GameType.weekendQuads),
        ],
      ),
    );
  }

  Widget _btn(GameType type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 240,
        height: 48,
        child: ElevatedButton(
          onPressed: () => onSelect(type),
          child: Text(type.label),
        ),
      ),
    );
  }
}