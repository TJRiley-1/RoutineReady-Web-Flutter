import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/membership_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/session_provider.dart';

class ModeSelectScreen extends ConsumerStatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  ConsumerState<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends ConsumerState<ModeSelectScreen> {
  void _selectMode(String mode) {
    ref.read(sessionModeProvider.notifier).state = mode;
  }

  @override
  Widget build(BuildContext context) {
    final schoolState = ref.watch(schoolProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '\u2705',
                  style: TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Routine Ready',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                schoolState.whenOrNull(
                      data: (state) => state != null
                          ? Text(
                              '${state.school.schoolName} - ${state.school.className}',
                              style: const TextStyle(
                                color: AppColors.brandTextMuted,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ) ??
                    const SizedBox.shrink(),
                const SizedBox(height: 8),
                const Text(
                  'Choose how to use this device',
                  style: TextStyle(color: AppColors.brandTextMuted),
                ),
                const SizedBox(height: 40),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ModeCard(
                          icon: LucideIcons.monitor,
                          title: 'Display Mode',
                          description:
                              'Full-screen view for students.\nShows the daily schedule timeline.',
                          color: AppColors.brandPrimary,
                          onTap: () => _selectMode('display'),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _ModeCard(
                          icon: LucideIcons.settings,
                          title: 'Admin Mode',
                          description:
                              'Edit tasks, templates, themes, and display settings.',
                          color: AppColors.brandAccent,
                          onTap: () => _selectMode('admin'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Show "Change Classroom" if user has org membership
                    if (ref.watch(membershipProvider).valueOrNull != null) ...[
                      TextButton.icon(
                        onPressed: () {
                          ref.read(selectedClassroomProvider.notifier).state = null;
                        },
                        icon: const Icon(LucideIcons.arrowLeft, size: 16),
                        label: const Text('Change Classroom'),
                      ),
                      const SizedBox(width: 16),
                    ],
                    TextButton.icon(
                      onPressed: () {
                        ref.read(authActionsProvider).signOut();
                      },
                      icon: const Icon(LucideIcons.logOut, size: 16),
                      label: const Text('Sign Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.brandTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
