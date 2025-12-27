import 'package:flutter/material.dart';
import '../../config.dart';
import '../utils/screen_utils.dart';

class GameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const GameButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppConfig.gameGreen, // Default game green
    this.icon,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Disable interaction if onPressed is null
    final isEnabled = widget.onPressed != null;
    
    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: AppConfig.animationDurationFast,
        margin: EdgeInsets.only(top: _isPressed ? 4 : 0), // Push down effect
        padding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.relativeSize(
            context,
            AppConfig.gameButtonPaddingHorizontalFactor,
          ),
          vertical: ScreenUtils.relativeSize(
            context,
            AppConfig.gameButtonPaddingVerticalFactor,
          ),
        ),
        decoration: BoxDecoration(
          color: isEnabled ? widget.color : Colors.grey,
          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.gameButtonBorderRadiusFactor)),
          // "3D" bottom shadow border
          boxShadow: _isPressed || !isEnabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 0, // Sharp shadow for "game" feel
                  ),
                ],
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorSmall),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: Colors.white,
                size: ScreenUtils.relativeSize(
                  context,
                  AppConfig.gameButtonIconSizeFactor,
                ),
              ),
              SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall * 4)),
            ],
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  AppConfig.gameButtonFontSizeFactor,
                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                ),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

