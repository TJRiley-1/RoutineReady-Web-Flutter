import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_admin_provider.dart';
import 'dialogs/create_user_dialog.dart';

class UserListView extends ConsumerWidget {
  const UserListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(staffAdminUsersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Text(
                'Users',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const CreateUserDialog(),
                ),
                icon: const Icon(Icons.person_add),
                label: const Text('Create User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $e'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(staffAdminUsersProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (users) {
              if (users.isEmpty) {
                return const Center(child: Text('No users found.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final email = user['email'] as String? ?? '';
                  final memberships = List<Map<String, dynamic>>.from(
                    user['memberships'] as List? ?? [],
                  );
                  final orgNames = memberships
                      .map((m) {
                        final org = m['organizations'];
                        if (org is Map) return org['name'] as String? ?? '';
                        return '';
                      })
                      .where((n) => n.isNotEmpty)
                      .join(', ');

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: email.endsWith('@routineready.app') || email.endsWith('@routineready.co.uk')
                            ? Colors.amber.shade100
                            : AppColors.brandPrimaryBg,
                        child: Icon(
                          email.endsWith('@routineready.app') || email.endsWith('@routineready.co.uk')
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: email.endsWith('@routineready.app') || email.endsWith('@routineready.co.uk')
                              ? Colors.amber.shade800
                              : AppColors.brandPrimary,
                        ),
                      ),
                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        orgNames.isNotEmpty ? orgNames : 'No organization',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _handleAction(context, ref, action, user),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'reset_password',
                            child: ListTile(
                              leading: Icon(Icons.lock_reset, size: 20),
                              title: Text('Reset Password'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, size: 20, color: Colors.red),
                              title: Text('Delete User', style: TextStyle(color: Colors.red)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Map<String, dynamic> user,
  ) {
    final email = user['email'] as String? ?? '';
    final userId = user['id'] as String;

    switch (action) {
      case 'reset_password':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Password'),
            content: Text('Send a password reset email to "$email"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    // Use the public resetPasswordForEmail (actually sends the
                    // email) rather than the edge generateLink which doesn't.
                    await ref.read(authActionsProvider).resetPassword(email);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Password reset email sent to $email.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Send Reset'),
              ),
            ],
          ),
        );
        break;

      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete User'),
            content: Text(
              'Delete "$email"? This will remove the user and all org memberships. This cannot be undone.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(staffAdminActionsProvider).deleteUser(userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User deleted.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
    }
  }
}
