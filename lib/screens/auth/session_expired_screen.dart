import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              'Session expired',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please sign in again to continue.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Route to the login screen by marking this as an intentional flow.
                ref.read(isExplicitSignOutProvider.notifier).state = true;
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
