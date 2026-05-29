import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_theme_extensions.dart';

enum SkeletonVariant { transactionTile, heroCard, insightCard, kpiCard }

class SkeletonCard extends StatelessWidget {
  final SkeletonVariant variant;
  final Animation<double> shimmerAnimation;

  const SkeletonCard._({
    required this.variant,
    required this.shimmerAnimation,
  });

  factory SkeletonCard.transactionTile({required Animation<double> animation}) =>
      SkeletonCard._(variant: SkeletonVariant.transactionTile, shimmerAnimation: animation);

  factory SkeletonCard.heroCard({required Animation<double> animation}) =>
      SkeletonCard._(variant: SkeletonVariant.heroCard, shimmerAnimation: animation);

  factory SkeletonCard.insightCard({required Animation<double> animation}) =>
      SkeletonCard._(variant: SkeletonVariant.insightCard, shimmerAnimation: animation);

  factory SkeletonCard.kpiCard({required Animation<double> animation}) =>
      SkeletonCard._(variant: SkeletonVariant.kpiCard, shimmerAnimation: animation);

  @override
  Widget build(BuildContext context) {
    final baseColor = BudgoColors.skeletonBase(context);
    final highlightColor = BudgoColors.skeletonHighlight(context);

    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, child) {
        final gradient = LinearGradient(
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0 + (shimmerAnimation.value * 2.0), -0.3),
          end: Alignment(0.0 + (shimmerAnimation.value * 2.0), 0.3),
          tileMode: TileMode.clamp,
        );

        return ShaderMask(
          shaderCallback: (bounds) => gradient.createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: _buildSkeletonShape(context),
    );
  }

  Widget _buildSkeletonShape(BuildContext context) {
    final baseColor = BudgoColors.skeletonBase(context);

    switch (variant) {
      case SkeletonVariant.transactionTile:
        return Container(
          height: 72.0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Row(
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14.0,
                      width: 120.0,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      height: 10.0,
                      width: 80.0,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 16.0,
                width: 60.0,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ],
          ),
        );

      case SkeletonVariant.heroCard:
        return Container(
          height: 160.0,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 36.0,
                width: 150.0,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 16.0,
                    width: 100.0,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  Container(
                    height: 16.0,
                    width: 100.0,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case SkeletonVariant.insightCard:
        return Container(
          width: 200.0,
          height: 80.0,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        );

      case SkeletonVariant.kpiCard:
        return Container(
          height: 96.0,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        );
    }
  }
}
