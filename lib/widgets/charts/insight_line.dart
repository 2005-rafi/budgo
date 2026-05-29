import 'package:flutter/material.dart';
import 'package:expense/core/app_motion.dart';

class InsightLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const InsightLine({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.standard,
            child: Text(
              text,
              key: ValueKey(text),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
