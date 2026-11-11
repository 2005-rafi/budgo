import 'package:flutter/material.dart';

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/design/tokens/app_radius.dart';

enum AppBrandLogoSize {
  compact(48, 6, AppRadius.md),
  aboutCard(88, 12, AppRadius.lg),
  hero(108, 14, AppRadius.xl);

  final double dimension;
  final double padding;
  final double borderRadius;
  const AppBrandLogoSize(this.dimension, this.padding, this.borderRadius);
}

/// Unified Material 3 Expressive brand emblem framing [AppBrand.logoAsset]
/// across Splash, About & Legal, and license attributions from a single widget.
class AppBrandLogo extends StatelessWidget {
  final AppBrandLogoSize size;
  final bool showElevation;

  const AppBrandLogo({
    super.key,
    this.size = AppBrandLogoSize.aboutCard,
    this.showElevation = true,
  });

  const AppBrandLogo.hero({super.key})
      : size = AppBrandLogoSize.hero,
        showElevation = true;

  const AppBrandLogo.about({super.key})
      : size = AppBrandLogoSize.aboutCard,
        showElevation = true;

  const AppBrandLogo.compact({super.key})
      : size = AppBrandLogoSize.compact,
        showElevation = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cachePx = (size.dimension * 2.5).round();

    return Container(
      width: size.dimension,
      height: size.dimension,
      padding: EdgeInsets.all(size.padding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(size.borderRadius),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
          width: showElevation ? 1.5 : 1.0,
        ),
        boxShadow: showElevation
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  blurRadius: size == AppBrandLogoSize.hero ? 28 : 20,
                  offset: Offset(0, size == AppBrandLogoSize.hero ? 10 : 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (size.borderRadius - 4).clamp(AppRadius.sm, AppRadius.lg),
        ),
        child: Image.asset(
          AppBrand.logoAsset,
          cacheWidth: cachePx,
          cacheHeight: cachePx,
          fit: BoxFit.contain,
          semanticLabel: '${AppBrand.appName} logo',
        ),
      ),
    );
  }
}

