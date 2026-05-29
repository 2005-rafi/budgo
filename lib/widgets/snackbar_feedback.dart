import 'package:flutter/material.dart';

class SnackbarFeedback {
  static void showSuccess(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
        backgroundColor: colorScheme.primaryContainer,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
        backgroundColor: colorScheme.secondaryContainer,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
        backgroundColor: colorScheme.errorContainer,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showUndo(BuildContext context, String message, VoidCallback onUndo) {
    final colorScheme = Theme.of(context).colorScheme;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: colorScheme.inversePrimary,
          onPressed: onUndo,
        ),
      ),
    );
  }
}
