import 'package:flutter/material.dart';

/// Single source of truth for all colours, text styles, and component themes.
/// Screens reference [AppTheme.dark] via [Theme.of(context)] — no per-screen
/// colour overrides required.
class AppTheme {
  AppTheme._();

  // ─── Brand palette ────────────────────────────────────────────────────────
  static const Color _primary       = Color(0xFF1565C0); // blue 800
  static const Color _primaryLight  = Color(0xFF1E88E5); // blue 600
  static const Color _surface       = Color(0xFF0D0D0D);
  static const Color _surfaceCard   = Color(0xFF1A1A1A);
  static const Color _border        = Color(0xFF2E2E2E);
  static const Color _textPrimary   = Color(0xFFF0F0F0);
  static const Color _textSecondary = Color(0xFF9E9E9E);

  // Exposed so widgets can reference them without going via BuildContext
  static const Color primary       = _primary;
  static const Color primaryLight  = _primaryLight;
  static const Color surface       = _surface;
  static const Color surfaceCard   = _surfaceCard;
  static const Color border        = _border;
  static const Color textPrimary   = _textPrimary;
  static const Color textSecondary = _textSecondary;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary:        _primary,
        onPrimary:      Colors.white,
        secondary:      _primaryLight,
        onSecondary:    Colors.white,
        surface:        _surface,
        onSurface:      _textPrimary,
        outline:        _border,
      ),

      scaffoldBackgroundColor: Colors.transparent,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _textPrimary,
        elevation:       0,
        centerTitle:     false,
        titleTextStyle: TextStyle(
          color:      _textPrimary,
          fontSize:   18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: _textPrimary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:          const Color(0xCC0D0D0D), // 80% opaque
        indicatorColor:           _primary.withOpacity(0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize:   11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color:      active ? _primaryLight : _textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? _primaryLight : _textSecondary,
            size:  22,
          );
        }),
      ),

      cardTheme: CardThemeData(
        color:        _surfaceCard,
        elevation:    0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color:     _border,
        thickness: 1,
        space:     1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor:    _surfaceCard,
        selectedColor:      _primary.withOpacity(0.35),
        labelStyle:         const TextStyle(color: _textPrimary, fontSize: 13),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(
          color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(
          color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: const TextStyle(
          color: _textPrimary, fontSize: 14),
        bodySmall: const TextStyle(
          color: _textSecondary, fontSize: 12),
        labelSmall: const TextStyle(
          color: _textSecondary, fontSize: 11),
      ),
    );
  }
}
