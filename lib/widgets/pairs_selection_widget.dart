import 'package:flutter/material.dart';
import '../models/afl_player.dart';
import '../theme/club_colors.dart';

class PairsSelectionWidget extends StatefulWidget {
  final List<AflPlayer> players;
  final Function(AflPlayer?, AflPlayer?) onChanged;

  const PairsSelectionWidget({
    super.key,
    required this.players,
    required this.onChanged,
  });

  @override
  State<PairsSelectionWidget> createState() => _PairsSelectionWidgetState();
}

class _PairsSelectionWidgetState extends State<PairsSelectionWidget> {
  AflPlayer? pick1;
  AflPlayer? pick2;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildPickColumn(
          label: "Pick 1",
          selected: pick1,
          onChanged: (p) {
            setState(() => pick1 = p);
            widget.onChanged(pick1, pick2);
          },
        ),
        const SizedBox(width: 20),
        _buildPickColumn(
          label: "Pick 2",
          selected: pick2,
          onChanged: (p) {
            setState(() => pick2 = p);
            widget.onChanged(pick1, pick2);
          },
        ),
      ],
    );
  }

  Widget _buildPickColumn({
    required String label,
    required AflPlayer? selected,
    required Function(AflPlayer?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
            color: selected != null
                ? ClubColors.forClub(selected.club)
                : Colors.transparent,
          ),
          child: DropdownButton<AflPlayer>(
            isExpanded: true,
            value: selected,
            hint: const Text("Select Player"),
            items: widget.players.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p.fullName),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}