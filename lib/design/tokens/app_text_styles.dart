import 'package:flutter/material.dart';
import 'package:expense/design/theme/app_theme_extensions.dart';

abstract final class AppTextStyles {
  static TextStyle amountDisplay(BuildContext ctx) =>
      Theme.of(ctx).textTheme.displaySmall!.copyWith(
            fontWeight: FontWeight.w400,
            color: Theme.of(ctx).colorScheme.onSurface,
            letterSpacing: -0.5,
          );

  static TextStyle headline(BuildContext ctx) =>
      Theme.of(ctx).textTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.onSurface,
          );

  static TextStyle title(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.onSurface,
          );

  static TextStyle body(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyMedium!.copyWith(
            color: Theme.of(ctx).colorScheme.onSurface,
          );

  static TextStyle bodySecondary(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodySmall!.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          );

  static TextStyle label(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelSmall!.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          );

  static TextStyle labelMedium(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          );

  static TextStyle amountPositive(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: BudgoColors.incomeColor(ctx),
          );

  static TextStyle amountNegative(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.onSurface,
          );

  static TextStyle amountOverBudget(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.error,
          );

  static TextStyle categoryLabel(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelSmall!.copyWith(
            fontWeight: FontWeight.w500,
            color: BudgoColors.categoryChipText(ctx),
            letterSpacing: 0.2,
          );

  static TextStyle titleMedium(BuildContext ctx) => title(ctx);
  static TextStyle labelSmall(BuildContext ctx) => label(ctx);
  static TextStyle bodyMedium(BuildContext ctx) => body(ctx);
  static TextStyle bodySmall(BuildContext ctx) => bodySecondary(ctx);
  static TextStyle amountLarge(BuildContext ctx) => amountDisplay(ctx);
  static TextStyle headlineLarge(BuildContext ctx) => headline(ctx);
}
