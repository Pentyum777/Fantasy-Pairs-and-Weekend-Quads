import 'package:flutter/material.dart';

/// A single place for responsive breakpoint logic.
/// Import this instead of duplicating `isPortraitPhone` across screens.
class Responsive {
  Responsive._();

  /// True on a phone held in portrait (width < 600, taller than wide).
  static bool isPortraitPhone(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.height > s.width && s.width < 600;
  }

  /// True when the device is wider than 600 dp (tablet / desktop / landscape phone).
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  /// True on a phone held in landscape.
  static bool isLandscapePhone(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.width > s.height && s.width < 900;
  }
}
