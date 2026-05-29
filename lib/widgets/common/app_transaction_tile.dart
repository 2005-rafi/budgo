import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/money.dart';

class AppTransactionTile extends StatelessWidget {
  final String title;
  final int amount;
  final String category;
  final DateTime date;
  final bool isIncome;
  final bool isPending;
  final bool isPlanned;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;
  final Widget? trailing;
  final Color? priorityColor;
  final bool showDivider;

  const AppTransactionTile({
    super.key,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.isIncome,
    required this.isPending,
    required this.isPlanned,
    required this.onTap,
    required this.onDelete,
    this.onConfirm,
    this.trailing,
    this.priorityColor,
    this.showDivider = true,
  });

  IconData _categoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'travel':
        return Icons.directions_car_outlined;
      case 'bills':
        return Icons.receipt_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'lend':
        return Icons.handshake_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'income':
        return Icons.arrow_downward_outlined;
      default:
        return Icons.attach_money_outlined;
    }
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Left Icon Circle Configuration
    final Color iconColor = colorScheme.onSurfaceVariant;
    final Color iconBg = colorScheme.surfaceContainerHigh;
    final IconData iconData = isIncome ? Icons.trending_up_outlined : _categoryIcon(category);

    // Amount Color configuration
    final TextStyle amountStyle = theme.textTheme.titleSmall!.copyWith(
      color: isIncome
          ? colorScheme.secondary // Green-adjacent signal
          : colorScheme.onSurface, // Neutral text for spending
      fontWeight: FontWeight.bold,
    );

    final String amountText = (isIncome ? '+' : (isPlanned ? 'Est. ' : '-')) + amount.format();

    // Confirm swipe configuration
    final bool canSwipeConfirm = isIncome && isPending && onConfirm != null;
    final DismissDirection direction = canSwipeConfirm ? DismissDirection.horizontal : DismissDirection.endToStart;

    Widget tileContent = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        color: Colors.transparent, // Ensure full touch area is active
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Row(
          children: [
            if (priorityColor != null) ...[
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            // 1. Category Icon 20dp inside 36dp circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                iconData,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 2. Name + Date Details
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRelativeDate(date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 3. Category badge/chip (Centered in a fixed-width column for alignment)
            SizedBox(
              width: 76,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    category,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 4. Amount and Trailing indicator (Right-aligned in a fixed-width column)
            Container(
              width: 90,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      amountText,
                      style: amountStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ] else if (isPending || isPlanned) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      isPending ? Icons.schedule_outlined : Icons.shopping_bag_outlined,
                      size: 16,
                      color: isPending ? colorScheme.tertiary : colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: Key('app_tx_tile_${title}_${date.millisecondsSinceEpoch}'),
      direction: direction,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        } else if (direction == DismissDirection.startToEnd && canSwipeConfirm) {
          onConfirm?.call();
        }
        return false; // Let the provider handling redraw the list
      },
      background: Container(
        color: colorScheme.secondaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: Icon(
          Icons.check_circle_outline,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      secondaryBackground: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tileContent,
          if (showDivider)
            Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              indent: 64, // aligned after icon: 16 (padding) + 36 (icon) + 12 (spacing) = 64
            ),
        ],
      ),
    );
  }
}
