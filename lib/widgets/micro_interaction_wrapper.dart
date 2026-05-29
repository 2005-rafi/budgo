import 'package:flutter/material.dart';
import 'package:expense/core/app_durations.dart';

class MicroInteractionWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const MicroInteractionWrapper({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<MicroInteractionWrapper> createState() => _MicroInteractionWrapperState();
}

class _MicroInteractionWrapperState extends State<MicroInteractionWrapper> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() => _scale = 0.95);
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _scale = 1.0);
          widget.onTap!();
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          setState(() => _scale = 1.0);
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: _scale),
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        builder: (context, val, child) {
          return Transform.scale(
            scale: val,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
