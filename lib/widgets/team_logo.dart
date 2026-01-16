// lib/widgets/team_logo.dart

import 'package:flutter/material.dart';
import '../utils/afl_club_codes.dart';

class TeamLogo extends StatelessWidget {
  final String club;
  final double size;

  const TeamLogo(this.club, {this.size = 32, super.key});

  @override
  Widget build(BuildContext context) {
    final code = AflClubCodes.normalize(club);
    final assetPath = 'assets/logos/$code.png';

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(code, style: TextStyle(fontSize: size * 0.3)),
          ),
        ),
      ),
    );
  }
}