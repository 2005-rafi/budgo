import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';

class SwipeActionContainer extends StatelessWidget {
  final Widget child;
  final Future<bool?> Function() onDelete;
  final VoidCallback onEdit;
  final Key dismissibleKey;

  const SwipeActionContainer({
    required this.dismissibleKey,
    required this.child,
    required this.onDelete,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: dismissibleKey,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.4,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await onDelete();
        } else if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false; // Do not dismiss for edit
        }
        return false;
      },
      background: Container(
        color: colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.edit_outlined, color: colorScheme.onPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Edit',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: colorScheme.onError,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.delete_outline, color: colorScheme.onError),
          ],
        ),
      ),
      child: child,
    );
  }
}
