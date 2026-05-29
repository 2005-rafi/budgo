import 'package:flutter/material.dart';
import 'package:expense/core/app_motion.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  AppPageRoute({required this.child, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: AppMotion.enter,
          reverseTransitionDuration: AppMotion.exit,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Horizontal shared-axis transition: slide in from right, fade, slide out to left
            final slideIn = SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0.0), // M3 subtle 30% horizontal slide in
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: AppMotion.curveEnter,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-0.3, 0.0), // Exit to left with 30% slide
              ).animate(CurvedAnimation(
                parent: secondaryAnimation,
                curve: AppMotion.curveExit,
              )),
              child: slideIn,
            );
          },
        );
}
