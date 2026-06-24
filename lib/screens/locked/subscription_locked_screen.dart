import 'package:flutter/material.dart';
import '../../config/theme_constants.dart';

/// Shown when a classroom's subscription has been switched off by RoutineReady
/// staff (`schools.is_active = false`). Distinct from an offline state — the app
/// only routes here when it has *confirmed* the classroom is inactive (a network
/// outage falls back to the cached schedule instead, so a live display never
/// goes blank just because the internet dropped).
class SubscriptionLockedScreen extends StatelessWidget {
  const SubscriptionLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBgSubtle,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 72, color: AppColors.brandPrimary),
              const SizedBox(height: 24),
              const Text(
                'Subscription paused',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This display is not currently active.\n'
                'Please contact RoutineReady to restore access.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.brandTextMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
