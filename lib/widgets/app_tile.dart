import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// The standard tappable tile used on round-selection, game-type-selection,
/// and any other grid/list of choices.
///
/// Replaces the copy-pasted `buildProTile` that previously lived inside
/// [SeasonSelectionScreen], [RoundSelectionScreen], and
/// [GameTypeSelectionScreen].
class AppTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  /// Shows a dimmed/muted style for completed rounds.
  final bool dimmed;

  /// Optional leading icon shown to the left of the label.
  final IconData? icon;

  /// Optional accent colour for the left border strip.
  final Color? accentColor;

  const AppTile({
    super.key,
    required this.label,
    required this.onTap,
    this.dimmed    = false,
    this.icon      = null,
    this.accentColor = null,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isPortraitPhone(context);

    final borderColor = dimmed
        ? AppTheme.border
        : AppTheme.border.withOpacity(0.9);

    final bgColor = dimmed
        ? AppTheme.surfaceCard.withOpacity(0.45)
        : AppTheme.surfaceCard.withOpacity(0.75);

    final labelColor = dimmed
        ? AppTheme.textSecondary
        : AppTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(mobile ? 10 : 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(mobile ? 10 : 14),
        onTap: onTap,
        splashColor: AppTheme.primary.withOpacity(0.18),
        highlightColor: AppTheme.primary.withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            vertical:   mobile ? 8  : 12,
            horizontal: mobile ? 8  : 14,
          ),
          decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(mobile ? 10 : 14),
            border: Border(
              left: accentColor != null
                  ? BorderSide(color: accentColor!, width: 3)
                  : BorderSide(color: borderColor, width: mobile ? 1.0 : 1.3),
              top:    BorderSide(color: borderColor, width: mobile ? 1.0 : 1.3),
              right:  BorderSide(color: borderColor, width: mobile ? 1.0 : 1.3),
              bottom: BorderSide(color: borderColor, width: mobile ? 1.0 : 1.3),
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.25),
                blurRadius: mobile ? 4 : 8,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: mobile ? 14 : 16, color: labelColor),
                SizedBox(width: mobile ? 5 : 7),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   mobile ? 12 : 14,
                    color:      labelColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
