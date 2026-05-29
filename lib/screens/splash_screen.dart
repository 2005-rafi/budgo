import 'package:flutter/material.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/core/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/app_readiness_notifier.dart';
import 'package:expense/navigation/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  AppReadinessNotifier? _readinessNotifier;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readinessNotifier?.removeListener(_onReadinessChanged);
    _readinessNotifier = Provider.of<AppReadinessNotifier>(context, listen: false);
    _readinessNotifier?.addListener(_onReadinessChanged);
    _onReadinessChanged();
  }

  void _onReadinessChanged() {
    if (_readinessNotifier?.isReady == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      });
    }
  }

  @override
  void dispose() {
    _readinessNotifier?.removeListener(_onReadinessChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon/app_icon.png', width: 100, height: 100),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Budgo",
                style: AppTextStyles.headlineLarge(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "All Expense Tracker",
                style: AppTextStyles.titleMedium(context).copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
