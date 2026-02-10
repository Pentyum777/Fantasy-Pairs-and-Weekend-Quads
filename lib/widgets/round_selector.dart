import 'package:flutter/material.dart';

class RoundSelector extends StatelessWidget {
  final List<int> rounds;
  final ValueChanged<int> onSelect;

  const RoundSelector({
    super.key,
    required this.rounds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: rounds.map((round) {
        final label = switch (round) {
          -1 => "Pre-Season",
          0 => "Opening Round",
          _ => "Round $round",
        };

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton(
            onPressed: () => onSelect(round),
            child: Text(label),
          ),
        );
      }).toList(),
    );
  }
}