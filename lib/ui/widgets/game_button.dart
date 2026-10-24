import 'package:flutter/material.dart';

import '../theme/vex_theme.dart';

/// A compact vexmarch button. [color] tints its border and the icon, so the
/// old colour-coded actions still read at a glance.
class GameButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const GameButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = VexColors.gold,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = enabled ? color : VexColors.muted;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: VexColors.panelSoft,
              border: Border.all(color: accent.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: VexColors.cream,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
