import 'dart:async';
import 'package:flutter/material.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/design/tokens/app_motion.dart';
import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/design/tokens/app_text_styles.dart';

/// Intercepts hardware/system back button cleanly when [onBack] returns false.
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

/// Animated empty state placeholder for lists and charts.
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
      duration: AppMotion.expressive,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
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
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xl,
            horizontal: AppSpacing.md,
          ),
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
                width: MediaQuery.sizeOf(context).width * 0.8,
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

/// Visual toast pill mounted at the topmost root [Overlay] layer so feedback
/// always floats unobstructed above bottom sheets, dialogs, and keyboards.
class BudgoToastBanner extends StatefulWidget {
  final FeedbackMessage message;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  const BudgoToastBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.duration,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<BudgoToastBanner> createState() => _BudgoToastBannerState();
}

class _BudgoToastBannerState extends State<BudgoToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.expressive,
      reverseDuration: AppMotion.fast,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.curveExpressive,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _controller.forward();
    _autoDismissTimer = Timer(widget.duration, _dismissAnimated);
  }

  Future<void> _dismissAnimated() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    try {
      await _controller.reverse();
    } catch (_) {
      // Ignore if controller was disposed mid-reverse.
    }
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasGuidance =
        widget.message.guidance != null && widget.message.guidance!.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Dismissible(
              key: const ValueKey('budgo_toast_dismissible'),
              direction: DismissDirection.up,
              onDismissed: (_) {
                _autoDismissTimer?.cancel();
                _isDismissing = true;
                widget.onDismissed();
              },
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: hasGuidance
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: hasGuidance ? 2.0 : 0.0),
                        child: Icon(
                          widget.icon,
                          size: 20,
                          color: widget.foregroundColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.message.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: widget.foregroundColor,
                                fontWeight: hasGuidance
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            if (hasGuidance) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.message.guidance!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: widget.foregroundColor
                                      .withValues(alpha: 0.9),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.actionLabel != null &&
                          widget.onAction != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: widget.foregroundColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            widget.onAction?.call();
                            _dismissAnimated();
                          },
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centralized Material 3 floating toast feedback powered by [AppErrorTranslator].
/// Renders inside the topmost root [Overlay] so messages stay visible above
/// bottom sheets, modal barriers, dialogs, and keyboards.
class SnackbarFeedback {
  SnackbarFeedback._();

  static const Key toastKey = ValueKey('budgo_toast_banner');
  static OverlayEntry? _activeEntry;

  /// Dismisses any currently displayed floating toast immediately.
  static void dismissCurrent() {
    final entry = _activeEntry;
    _activeEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? guidance,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      FeedbackMessage(
        title: message,
        guidance: guidance,
        severity: FeedbackSeverity.success,
      ),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? guidance,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      FeedbackMessage(
        title: message,
        guidance: guidance,
        severity: FeedbackSeverity.info,
      ),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? guidance,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      FeedbackMessage(
        title: message,
        guidance: guidance,
        severity: FeedbackSeverity.warning,
      ),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(
    BuildContext context,
    Object error, {
    FeedbackOperation? operation,
    String? guidance,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final translated = AppErrorTranslator.translate(error, operation: operation);
    final mergedGuidance = guidance ?? translated.guidance;
    show(
      context,
      FeedbackMessage(
        title: translated.title,
        guidance: mergedGuidance,
        severity: translated.severity == FeedbackSeverity.warning
            ? FeedbackSeverity.warning
            : FeedbackSeverity.error,
      ),
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void show(
    BuildContext context,
    FeedbackMessage msg, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final Duration duration;

    switch (msg.severity) {
      case FeedbackSeverity.success:
        bgColor = colorScheme.primaryContainer;
        fgColor = colorScheme.onPrimaryContainer;
        icon = Icons.check_circle_rounded;
        duration = msg.guidance != null
            ? const Duration(milliseconds: 3500)
            : const Duration(milliseconds: 2500);
        break;
      case FeedbackSeverity.info:
        bgColor = colorScheme.secondaryContainer;
        fgColor = colorScheme.onSecondaryContainer;
        icon = Icons.info_outline_rounded;
        duration = const Duration(milliseconds: 2500);
        break;
      case FeedbackSeverity.warning:
        bgColor = colorScheme.tertiaryContainer;
        fgColor = colorScheme.onTertiaryContainer;
        icon = Icons.warning_amber_rounded;
        duration = const Duration(milliseconds: 4000);
        break;
      case FeedbackSeverity.error:
        bgColor = colorScheme.errorContainer;
        fgColor = colorScheme.onErrorContainer;
        icon = Icons.error_outline_rounded;
        duration = msg.guidance != null
            ? const Duration(milliseconds: 4500)
            : const Duration(milliseconds: 3500);
        break;
    }

    _showInOverlay(
      context,
      msg: msg,
      bgColor: bgColor,
      fgColor: fgColor,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showUndo(BuildContext context, String message, VoidCallback onUndo) {
    final colorScheme = Theme.of(context).colorScheme;
    _showInOverlay(
      context,
      msg: FeedbackMessage(
        title: message,
        severity: FeedbackSeverity.info,
      ),
      bgColor: colorScheme.inverseSurface,
      fgColor: colorScheme.onInverseSurface,
      icon: Icons.undo_rounded,
      duration: const Duration(seconds: 4),
      actionLabel: 'Undo',
      onAction: onUndo,
    );
  }

  static void _showInOverlay(
    BuildContext context, {
    required FeedbackMessage msg,
    required Color bgColor,
    required Color fgColor,
    required IconData icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismissCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: BudgoToastBanner(
          key: toastKey,
          message: msg,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          icon: icon,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction,
          onDismissed: () {
            if (identical(_activeEntry, entry)) {
              _activeEntry = null;
            }
            if (entry.mounted) {
              entry.remove();
            }
          },
        ),
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}
