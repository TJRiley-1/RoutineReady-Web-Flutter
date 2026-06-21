import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/membership_provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/admin/onboarding_tour.dart';

class UserSettingsModal extends ConsumerStatefulWidget {
  final VoidCallback? onStartTour;

  const UserSettingsModal({super.key, this.onStartTour});

  @override
  ConsumerState<UserSettingsModal> createState() => _UserSettingsModalState();
}

class _UserSettingsModalState extends ConsumerState<UserSettingsModal> {
  bool _isEditingSetup = false;
  late TextEditingController _schoolNameController;
  late TextEditingController _classNameController;
  late TextEditingController _teacherNameController;
  late TextEditingController _deviceNameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(schoolProvider).valueOrNull;
    _schoolNameController =
        TextEditingController(text: state?.school.schoolName ?? '');
    _classNameController =
        TextEditingController(text: state?.school.className ?? '');
    _teacherNameController =
        TextEditingController(text: state?.school.teacherName ?? '');
    _deviceNameController =
        TextEditingController(text: state?.school.deviceName ?? '');
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _classNameController.dispose();
    _teacherNameController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolState = ref.watch(schoolProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    // Only meaningful in the org-based flow where a classroom was picked.
    final hasSelectedClassroom =
        ref.watch(selectedClassroomProvider) != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'User Settings',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account section
                      const Text('Account',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Email'),
                        subtitle: Text(user?.email ?? 'Not signed in'),
                        dense: true,
                      ),
                      ListTile(
                        title: const Text('Reset Password'),
                        trailing: OutlinedButton(
                          onPressed: () {
                            if (user?.email != null) {
                              ref
                                  .read(authActionsProvider)
                                  .resetPassword(user!.email!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Password reset email sent!')),
                              );
                            }
                          },
                          child: const Text('Send Reset Email'),
                        ),
                        dense: true,
                      ),
                      const SizedBox(height: 16),

                      // Setup info
                      const Text('Setup Info',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),

                      if (_isEditingSetup) ...[
                        TextField(
                          controller: _schoolNameController,
                          decoration: const InputDecoration(
                              labelText: 'School Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _classNameController,
                          decoration: const InputDecoration(
                              labelText: 'Class Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _teacherNameController,
                          decoration: const InputDecoration(
                              labelText: 'Teacher Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _deviceNameController,
                          decoration: const InputDecoration(
                              labelText: 'Device Name'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isEditingSetup = false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await ref
                                    .read(schoolProvider.notifier)
                                    .updateSchoolInfo(
                                      schoolName:
                                          _schoolNameController.text.trim(),
                                      className:
                                          _classNameController.text.trim(),
                                      teacherName:
                                          _teacherNameController.text.trim(),
                                      deviceName:
                                          _deviceNameController.text.trim(),
                                    );
                                setState(() => _isEditingSetup = false);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ] else ...[
                        ListTile(
                          title: const Text('School'),
                          subtitle:
                              Text(schoolState?.school.schoolName ?? ''),
                          dense: true,
                        ),
                        ListTile(
                          title: const Text('Class'),
                          subtitle:
                              Text(schoolState?.school.className ?? ''),
                          dense: true,
                        ),
                        ListTile(
                          title: const Text('Teacher'),
                          subtitle:
                              Text(schoolState?.school.teacherName ?? ''),
                          dense: true,
                        ),
                        ListTile(
                          title: const Text('Device'),
                          subtitle:
                              Text(schoolState?.school.deviceName ?? ''),
                          dense: true,
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _isEditingSetup = true),
                          child: const Text('Edit Setup Info'),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Text('Help',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await resetOnboarding();
                          if (context.mounted) {
                            Navigator.pop(context);
                            widget.onStartTour?.call();
                          }
                        },
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: const Text('Take a tour'),
                      ),

                      const SizedBox(height: 24),
                      const Text('Data Management',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _exportBackup(context),
                            icon: const Icon(Icons.upload, size: 18),
                            label: const Text('Export Backup'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _importBackup(context),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Restore Backup'),
                          ),
                          OutlinedButton(
                            onPressed: () => _resetSetup(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brandError,
                              side: const BorderSide(
                                  color: AppColors.brandError),
                            ),
                            child: const Text('Reset to Default'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      if (hasSelectedClassroom)
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Return to the classroom picker (org members)
                              // or the all-orgs picker (staff super-admins).
                              ref
                                  .read(selectedClassroomProvider.notifier)
                                  .state = null;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Switch Classroom'),
                          ),
                        ),
                      if (hasSelectedClassroom) const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(authActionsProvider).signOut();
                            ref
                                .read(sessionModeProvider.notifier)
                                .state = null;
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: AppColors.brandText,
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportBackup(BuildContext context) {
    final backup = ref.read(schoolProvider.notifier).exportBackup();
    if (backup.isEmpty) return;

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup copied to clipboard!')),
    );
  }

  void _importBackup(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Paste the backup JSON below. This will overwrite your current data.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Paste backup JSON here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final data =
                    jsonDecode(controller.text) as Map<String, dynamic>;
                Navigator.pop(ctx);
                await ref.read(schoolProvider.notifier).importBackup(data);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored!')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Invalid backup: $e')),
                  );
                }
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _resetSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text(
            'This will clear all data and restart setup. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await ref.read(schoolProvider.notifier).resetAll();
              ref.read(sessionModeProvider.notifier).state = null;
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandError),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
