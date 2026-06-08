import 'package:flutter/material.dart';

/// Wraps any screen in the stadium-glow background image.
/// All Scaffolds must set [backgroundColor: Colors.transparent] so this
/// shows through.
class BackgroundContainer extends StatelessWidget {
  final Widget child;

  const BackgroundContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/stadium_glow.png'),
          fit:   BoxFit.cover,
        ),
      ),
      // Subtle dark overlay so text stays legible on bright parts of the image
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
        ),
        child: child,
      ),
    );
  }
}
