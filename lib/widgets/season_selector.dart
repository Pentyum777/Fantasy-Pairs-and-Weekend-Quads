import 'package:flutter/material.dart';

class SeasonSelector extends StatelessWidget {
  final List<int> seasons;
  final ValueChanged<int> onSelect;

  const SeasonSelector({
    super.key,
    required this.seasons,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: seasons.map((season) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton(
            onPressed: () => onSelect(season),
            child: Text("$season Season"),
          ),
        );
      }).toList(),
    );
  }
}