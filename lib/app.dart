import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme_constants.dart';
import 'models/org_member.dart';
import 'providers/auth_provider.dart';
import 'providers/membership_provider.dart';
import 'providers/school_provider.dart';
import 'providers/session_provider.dart';
import 'providers/staff_admin_provider.dart';
import 'providers/subscription_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/session_expired_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/auth/setup_wizard_screen.dart';
import 'screens/classroom_picker/classroom_picker_screen.dart';
import 'screens/classroom_picker/all_classrooms_picker_screen.dart';
import 'screens/mode_select/mode_select_screen.dart';
import 'screens/locked/subscription_locked_screen.dart';
import 'screens/display/display_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/staff_admin/staff_admin_shell.dart';

class RoutineReadyApp extends ConsumerWidget {
  const RoutineReadyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Routine Ready',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final mustSetPassword = ref.watch(mustSetPasswordProvider);
    final isExplicitSignOut = ref.watch(isExplicitSignOutProvider);

    // Latch recovery mode so it survives the subsequent userUpdated event.
    // Reset the explicit-signout flag when the user signs back in so the next
    // unintentional session loss shows the expired screen again, not the form.
    ref.listen(authStateProvider, (_, next) {
      next.whenData((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          ref.read(mustSetPasswordProvider.notifier).state = true;
        }
        if (state.event == AuthChangeEvent.signedIn) {
          ref.read(isExplicitSignOutProvider.notifier).state = false;
        }
      });
    });

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const LoginScreen(),
      data: (state) {
        // Must intercept before the session check — recovery/invite arrive WITH
        // a session. Direct event check avoids a flash before the flag latches.
        if (mustSetPassword || state.event == AuthChangeEvent.passwordRecovery) {
          return const SetPasswordScreen();
        }
        if (state.session == null) {
          // Only show the full login form when the user deliberately signed out.
          // An unexpected session loss (token refresh failure, expiry) shows a
          // non-interactive notice so the display doesn't expose a login form
          // unattended in a classroom.
          return isExplicitSignOut
              ? const LoginScreen()
              : const SessionExpiredScreen();
        }
        return const _AuthenticatedRouter();
      },
    );
  }
}

class _AuthenticatedRouter extends ConsumerWidget {
  const _AuthenticatedRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaffAdmin = ref.watch(isStaffAdminProvider);
    final staffAdminMode = ref.watch(staffAdminModeProvider);

    // Staff admin mode — bypass membership check entirely
    if (isStaffAdmin && staffAdminMode) {
      return const StaffAdminShell();
    }

    // RoutineReady staff always land on the staff gate first — even if their
    // account also has an org membership — so Staff Admin is always reachable.
    // They can opt into the all-orgs classroom view from the gate.
    if (isStaffAdmin && !ref.watch(staffViewAsMemberProvider)) {
      return _StaffAdminGate();
    }
    // Staff in member view: super-admin over all orgs' classrooms.
    if (isStaffAdmin) {
      return const _StaffMemberRouter();
    }

    final membershipAsync = ref.watch(membershipProvider);

    return membershipAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error loading membership: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(membershipProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (membership) {
        // No org membership
        if (membership == null) {
          return const _LegacyRouter();
        }

        // Has membership — role-based routing
        return _RoleBasedRouter(membership: membership);
      },
    );
  }
}

/// Super-admin classroom flow for RoutineReady staff: pick any classroom from
/// any org, then edit it full like a school admin. School load is driven purely
/// by the selected classroom (RLS staff bypass permits read/write).
class _StaffMemberRouter extends ConsumerWidget {
  const _StaffMemberRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedClassroom = ref.watch(selectedClassroomProvider);
    final sessionMode = ref.watch(sessionModeProvider);

    if (selectedClassroom == null) {
      return const AllClassroomsPickerScreen();
    }

    final schoolState = ref.watch(schoolProvider);

    return schoolState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error loading classroom: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(schoolProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        if (state == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (sessionMode == null) {
          return const ModeSelectScreen();
        }
        if (sessionMode == 'display') {
          return const DisplayScreen();
        }
        return const AdminShell();
      },
    );
  }
}

/// Gate screen for RoutineReady staff. Always reachable for staff accounts so
/// Staff Admin is never blocked by also having an org membership.
class _StaffAdminGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, size: 64, color: AppColors.brandPrimary),
            const SizedBox(height: 16),
            const Text(
              'Routine Ready Staff',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('You are signed in with a staff account.'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(staffAdminModeProvider.notifier).state = true;
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Open Staff Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(staffViewAsMemberProvider.notifier).state = true;
              },
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('View all classrooms'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(authActionsProvider).signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legacy router for users without org membership (backward compat).
/// Handles existing teacher accounts that own schools directly.
class _LegacyRouter extends ConsumerWidget {
  const _LegacyRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolState = ref.watch(schoolProvider);
    final sessionMode = ref.watch(sessionModeProvider);
    final isPaid = ref.watch(isPaidProvider);

    return schoolState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error loading data: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(schoolProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        if (state == null) {
          if (isPaid) {
            return const SetupWizardScreen();
          }
          // Free user: initialize in-memory data and go to mode select
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(schoolProvider.notifier).initFreeMode();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Subscription switched off by RR staff. Only lock on a *confirmed*
        // inactive classroom — cached/offline data falls through so the display
        // never goes blank on a network blip.
        if (!state.school.isActive && !state.isUsingCachedData) {
          return const SubscriptionLockedScreen();
        }

        if (sessionMode == null) {
          return const ModeSelectScreen();
        }

        if (sessionMode == 'display') {
          return const DisplayScreen();
        }

        return const AdminShell();
      },
    );
  }
}

/// Role-based router for users with org membership.
class _RoleBasedRouter extends ConsumerWidget {
  final OrgMember membership;

  const _RoleBasedRouter({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedClassroom = ref.watch(selectedClassroomProvider);
    final sessionMode = ref.watch(sessionModeProvider);

    // Display role: check for remembered classroom first
    if (membership.role == UserRole.display && selectedClassroom == null) {
      return _DisplayAutoRestore(membership: membership);
    }

    // No classroom selected → classroom picker
    if (selectedClassroom == null) {
      return const ClassroomPickerScreen();
    }

    // Classroom selected — load school data
    final schoolState = ref.watch(schoolProvider);

    return schoolState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error loading classroom: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(schoolProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        if (state == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Subscription switched off by RR staff. Only lock on a *confirmed*
        // inactive classroom — cached/offline data falls through so the display
        // never goes blank on a network blip.
        if (!state.school.isActive && !state.isUsingCachedData) {
          return const SubscriptionLockedScreen();
        }

        // Enable session-only mode for staff (edits don't persist)
        if (membership.isSessionOnly && !state.isSessionOnlyMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(schoolProvider.notifier).enableSessionOnlyMode();
          });
        }

        // Route by role
        switch (membership.role) {
          case UserRole.display:
            return const DisplayScreen();

          case UserRole.staff:
            // Staff goes straight to display (can edit session-only)
            return const DisplayScreen();

          case UserRole.teacher:
          case UserRole.schoolAdmin:
            // Full editor for any classroom they pick in their org.
            // (School admin is org-wide; teacher manages their classrooms.)
            if (sessionMode == null) {
              return const ModeSelectScreen();
            }
            if (sessionMode == 'display') {
              return const DisplayScreen();
            }
            return const AdminShell();
        }
      },
    );
  }
}

/// Auto-restore remembered classroom for Display role devices.
class _DisplayAutoRestore extends ConsumerWidget {
  final OrgMember membership;

  const _DisplayAutoRestore({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rememberedIdAsync = ref.watch(rememberedClassroomIdProvider);

    return rememberedIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const ClassroomPickerScreen(),
      data: (rememberedId) {
        if (rememberedId == null) {
          return const ClassroomPickerScreen();
        }

        // Try to find the remembered classroom in the org's classrooms
        final classroomsAsync = ref.watch(classroomsProvider);
        return classroomsAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const ClassroomPickerScreen(),
          data: (classrooms) {
            final remembered = classrooms
                .where((c) => c.id == rememberedId)
                .firstOrNull;

            if (remembered == null) {
              // Remembered classroom no longer exists — pick again
              return const ClassroomPickerScreen();
            }

            // Auto-select the remembered classroom
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedClassroomProvider.notifier).state = remembered;
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}
