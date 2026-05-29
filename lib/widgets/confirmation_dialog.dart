import 'package:flutter/material.dart';

class ConfirmationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                cancelLabel,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            if (isDestructive)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(confirmLabel),
              ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
