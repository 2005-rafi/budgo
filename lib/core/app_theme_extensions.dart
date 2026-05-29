import 'package:flutter/material.dart';

class BudgoColors {
  // Income — tertiary family. Calm positive signal, not traffic-light green.
  static Color incomeColor(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiary;

  static Color incomeContainer(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiaryContainer;

  static Color onIncomeContainer(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onTertiaryContainer;

  // Expense — neutral. Spending is normal behavior.
  static Color expenseColor(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface;

  // Budget states
  static Color budgetSafe(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.primary;

  static Color budgetWarning(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiary;

  static Color budgetOver(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.error;

  static Color budgetWarningContainer(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiaryContainer;

  static Color onBudgetWarningContainer(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onTertiaryContainer;

  // Cards and surfaces
  static Color cardSurface(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surfaceContainerLow;

  static Color heroCardSurface(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surfaceContainerHigh;

  static Color bottomSheetSurface(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surfaceContainerHighest;

  // Category chips
  static Color categoryChipBackground(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.secondaryContainer;

  static Color categoryChipText(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSecondaryContainer;

  // Category icon circles in TransactionTile
  static Color categoryIconCircle(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.secondaryContainer;

  static Color categoryIconColor(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSecondaryContainer;

  static Color incomeIconCircle(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiaryContainer;

  static Color incomeIconColor(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onTertiaryContainer;

  // Skeleton loading
  static Color skeletonBase(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surfaceContainerHighest;

  static Color skeletonHighlight(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surfaceContainer;

  // Swipe action panels
  static Color deleteSwipePanel(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.error;

  static Color editSwipePanel(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.secondary;

  static Color confirmSwipePanel(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiary;

  // Insight cards
  static Color insightWarningBackground(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.tertiaryContainer;

  static Color insightWarningText(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onTertiaryContainer;

  static Color insightNeutralBackground(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.surfaceContainerLow;

  // Dividers
  static Color divider(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.outlineVariant;

  static Color strongDivider(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.outline;

  // Deprecated / Backwards compatibility aliases
  static Color warningColor(BuildContext ctx) => budgetWarning(ctx);
  static Color overBudgetColor(BuildContext ctx) => budgetOver(ctx);
}
