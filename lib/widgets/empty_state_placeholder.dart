import 'package:flutter/material.dart';
import 'package:expense/core/app_durations.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';

class EmptyStatePlaceholder extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<EmptyStatePlaceholder> createState() => _EmptyStatePlaceholderState();
}

class _EmptyStatePlaceholderState extends State<EmptyStatePlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15), // About 24px/160px slide
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.title,
                style: AppTextStyles.titleMedium(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Text(
                  widget.message,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonal(
                  onPressed: widget.onAction,
                  child: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
