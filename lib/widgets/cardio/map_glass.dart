import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// The translucent charcoal panel used for everything that floats over the
/// map. It is a plain translucent fill with a thin border (no blur), so it
/// costs nothing per frame and never hides the map labels beneath it.
class MapGlass extends StatelessWidget {
  const MapGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF111418) : Colors.white).withValues(
          alpha: dark ? 0.72 : 0.82,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }
}

/// A compact button on the map: an icon with an optional label.
class MapGlassButton extends StatelessWidget {
  const MapGlassButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimary;
    final fg = onPressed == null
        ? context.appTextMuted
        : (active ? accent : context.appTextPrimary);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: MapGlass(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 10 : 12,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: fg),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip ?? label,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button),
    );
  }
}
