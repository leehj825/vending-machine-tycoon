import 'package:flutter/material.dart';

import 'vex_theme.dart';

/// A bordered dark panel, the building block of the vexmarch look.
class VexPanel extends StatelessWidget {
  const VexPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderColor = VexColors.border,
    this.color = VexColors.panel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// A gold-edged button. [primary] buttons use the gold gradient.
class VexButton extends StatelessWidget {
  const VexButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.primary = false,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = primary ? const Color(0xFF1A1008) : VexColors.cream;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 16 : 18, color: foreground),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 16,
              vertical: compact ? 6 : 11,
            ),
            decoration: BoxDecoration(
              gradient: primary
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [VexColors.gold, VexColors.goldDeep],
                    )
                  : null,
              color: primary ? null : VexColors.panelSoft,
              border: Border.all(
                color: primary ? Colors.transparent : VexColors.border,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A small stat chip for the top bar: an icon and a value.
class VexStat extends StatelessWidget {
  const VexStat({
    super.key,
    required this.icon,
    required this.value,
    this.color = VexColors.cream,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return VexPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      borderColor: VexColors.line,
      color: VexColors.panel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: VexColors.gold),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// A gold label for a section heading, in capitals.
class VexLabel extends StatelessWidget {
  const VexLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: VexColors.gold,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// A thin progress bar in the vexmarch style. Pass [low] to show it in red.
class VexBar extends StatelessWidget {
  const VexBar({super.key, required this.value, this.low = false});

  final double value;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final fill = low
        ? const [VexColors.red, Color(0xFF9A1F1A)]
        : const [VexColors.green, Color(0xFF6F9A2A)];
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        border: Border.all(color: VexColors.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: fill),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// A bottom navigation tab with a gold underline when selected.
class VexNavTab extends StatelessWidget {
  const VexNavTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? VexColors.gold : VexColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: selected ? VexColors.gold : Colors.transparent,
                width: 2,
              ),
            ),
            color: selected ? const Color(0x14F2D27A) : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square icon button in the vexmarch style, for map and screen controls.
class VexIconButton extends StatelessWidget {
  const VexIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: VexColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: VexColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: VexColors.gold, size: size * 0.55),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
