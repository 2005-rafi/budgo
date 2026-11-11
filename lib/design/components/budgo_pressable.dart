import 'package:flutter/material.dart';
import 'package:expense/design/tokens/app_motion.dart';

/// Expressive tactile press scale feedback used across interactive cards, pills,
/// and secondary action containers.
class BudgoPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const BudgoPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<BudgoPressable> createState() => _BudgoPressableState();
}

class _BudgoPressableState extends State<BudgoPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: interactive
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: interactive ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppMotion.micro,
        curve: AppMotion.curveStandard,
        child: widget.child,
      ),
    );
  }
}
