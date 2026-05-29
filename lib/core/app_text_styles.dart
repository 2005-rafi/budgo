import 'package:flutter/material.dart';
import 'package:expense/core/app_theme_extensions.dart';

abstract final class AppTextStyles {
  // Display — hero financial numbers only
  static TextStyle amountDisplay(BuildContext ctx) =>
      Theme.of(ctx).textTheme.displaySmall!.copyWith(
        fontWeight: FontWeight.w300,
        color: Theme.of(ctx).colorScheme.onSurface,
        letterSpacing: -0.5,
      );

  // Headline — screen section titles
  static TextStyle headline(BuildContext ctx) =>
      Theme.of(ctx).textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(ctx).colorScheme.onSurface,
      );

  // Title — card titles, metric names, timeline group headers
  static TextStyle title(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(ctx).colorScheme.onSurface,
      );

  // Body — transaction names, descriptions, form content
  static TextStyle body(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyMedium!.copyWith(
        color: Theme.of(ctx).colorScheme.onSurface,
      );

  // Body secondary — subtitles, helper text
  static TextStyle bodySecondary(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodySmall!.copyWith(
        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
      );

  // Label — chips, badges, timestamps, metadata
  static TextStyle label(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelSmall!.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
      );

  // Amount variants
  static TextStyle amountPositive(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: BudgoColors.incomeColor(ctx), // tertiary
      );

  static TextStyle amountNegative(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(ctx).colorScheme.onSurface,  // neutral
      );

  static TextStyle amountOverBudget(BuildContext ctx) =>
      Theme.of(ctx).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(ctx).colorScheme.error,
      );

  // Category label — used inside chips and tiles
  static TextStyle categoryLabel(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelSmall!.copyWith(
        fontWeight: FontWeight.w500,
        color: BudgoColors.categoryChipText(ctx), // onSecondaryContainer
        letterSpacing: 0.2,
      );

  // Backward compatibility aliases
  static TextStyle titleMedium(BuildContext ctx) => title(ctx);
  static TextStyle labelSmall(BuildContext ctx) => label(ctx);
  static TextStyle bodyMedium(BuildContext ctx) => body(ctx);
  static TextStyle bodySmall(BuildContext ctx) => bodySecondary(ctx);
  static TextStyle amountLarge(BuildContext ctx) => amountDisplay(ctx);
  static TextStyle headlineLarge(BuildContext ctx) => headline(ctx);
}
