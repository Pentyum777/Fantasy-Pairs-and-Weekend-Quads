import 'package:flutter/material.dart';
import '../utils/afl_club_codes.dart';

class TeamLogo extends StatelessWidget {
  final String? club;
  final double size;

  const TeamLogo(this.club, {this.size = 32, super.key});

  @override
  Widget build(BuildContext context) {
    // If club is null or empty → return placeholder
    if (club == null || club!.trim().isEmpty) {
      return SizedBox(width: size, height: size);
    }

    // Normalize safely
    final code = AflClubCodes.normalize(club!.trim());

    // If normalization fails → return placeholder
    if (code.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    final assetPath = 'assets/logos/$code.png';

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            // Fallback: show the club code text instead of crashing
            return Center(
              child: Text(
                code,
                style: TextStyle(
                  fontSize: size * 0.30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}