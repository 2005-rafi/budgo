import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/initialization/app_readiness_notifier.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/navigation/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  AppReadinessNotifier? _readinessNotifier;
  Timer? _minHoldTimer;
  bool _minHoldElapsed = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _scaleIn = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );
    _entranceController.forward();

    // Brief brand showcase buffer prevents harsh flash while keeping startup fast (<200ms).
    _minHoldTimer = Timer(const Duration(milliseconds: 180), () {
      _minHoldElapsed = true;
      _tryNavigateIfReady();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Provider.of<AppReadinessNotifier>(context, listen: false);
    if (!identical(_readinessNotifier, next)) {
      _readinessNotifier?.removeListener(_onReadinessChanged);
      _readinessNotifier = next;
      _readinessNotifier?.addListener(_onReadinessChanged);
      _onReadinessChanged();
    }
  }

  void _onReadinessChanged() {
    if (!mounted) return;
    _tryNavigateIfReady();
    setState(() {});
  }

  void _tryNavigateIfReady() {
    if (_didNavigate) return;
    if (_readinessNotifier?.isReady == true && _minHoldElapsed) {
      _didNavigate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      });
    }
  }

  @override
  void dispose() {
    _minHoldTimer?.cancel();
    _readinessNotifier?.removeListener(_onReadinessChanged);
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final readiness = _readinessNotifier ?? context.watch<AppReadinessNotifier>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppMotion.standard,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: readiness.hasFailed
              ? BudgoStartupErrorView(
                  key: const ValueKey('splash_error_view'),
                  title: readiness.errorTitle ??
                      'Unable to finish starting ${AppBrand.appName}',
                  message: readiness.errorGuidance ??
                      'Your saved data is intact. Please retry opening your workspace or close and restart the app.',
                  isRetrying: readiness.isRetrying,
                  onRetry: () {
                    readiness.retry();
                  },
                )
              : Center(
                  key: const ValueKey('splash_loading_view'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: ScaleTransition(
                        scale: _scaleIn,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Elevated Brand Logo Card
                            const AppBrandLogo.hero(),
                            const SizedBox(height: AppSpacing.xl),

                            // Bold, Confident Offline Display Wordmark
                            Text(
                              AppBrand.appName,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontFamily: AppBrand.brandFontFamily,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.1,
                                color: colorScheme.onSurface,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                AppBrand.taglineUppercase,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontFamily: AppBrand.taglineFontFamily,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.8,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Material 3 Expressive Linear Wavy Progress Indicator
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 248),
                              child: BudgoWavyProgressIndicator(
                                value: readiness.progress,
                                strokeWidth: 3.6,
                                amplitude: 3.0,
                                wavelength: 50.0,
                                semanticsLabel: readiness.statusMessage,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // User-Friendly Plain-Language Status Ticker
                            SizedBox(
                              height: 24,
                              child: AnimatedSwitcher(
                                duration: AppMotion.fast,
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(opacity: anim, child: child),
                                child: Text(
                                  readiness.statusMessage,
                                  key: ValueKey<String>(readiness.statusMessage),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium(context).copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
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
