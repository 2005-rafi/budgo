import 'package:flutter/material.dart';

class AppBackGuard extends StatelessWidget {
  final Widget child;
  final Future<bool> Function()? onBack;

  const AppBackGuard({
    super.key,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: onBack == null,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (onBack != null) {
          final shouldPop = await onBack!();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop(result);
          }
        }
      },
      child: child,
    );
  }
}
