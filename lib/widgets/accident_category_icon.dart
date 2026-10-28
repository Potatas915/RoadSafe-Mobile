import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Uses the same category silhouettes and view boxes as the web manager.
class AccidentCategoryIcon extends StatelessWidget {
  const AccidentCategoryIcon({
    super.key,
    required this.categoryId,
    required this.color,
  });

  final String? categoryId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final category =
        const {
          'collision',
          'hit-and-run',
          'rollover',
          'pedestrian',
          'other',
        }.contains(categoryId)
        ? categoryId!
        : 'other';
    return SvgPicture.asset(
      'assets/images/accidents/$category.svg',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
