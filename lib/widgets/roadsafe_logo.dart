import 'package:flutter/material.dart';

/// App logo that follows the theme: the dark tile on dark mode and the
/// orange tile on light mode.
class RoadSafeLogo extends StatelessWidget {
  const RoadSafeLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/logo_dark.png' : 'assets/images/logo_orange.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: 'RoadSafe logo',
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}

/// Full logo with the "ROAD TRACK" wordmark. Uses white lettering on dark
/// mode and dark lettering on light mode.
class RoadSafeWordmark extends StatelessWidget {
  const RoadSafeWordmark({super.key, this.maxWidth = 300});
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Image.asset(
        dark
            ? 'assets/images/wordmark_dark.png'
            : 'assets/images/wordmark_light.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Road Track logo',
        errorBuilder: (_, _, _) => const SizedBox(height: 120),
      ),
    );
  }
}
