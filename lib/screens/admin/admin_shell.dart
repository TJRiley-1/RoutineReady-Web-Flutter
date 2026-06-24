import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme_constants.dart';
import '../../models/task.dart';
import '../../models/template.dart';
import '../../providers/school_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/theme_utils.dart';
import '../../utils/time_utils.dart';
import '../../widgets/admin/onboarding_tour.dart';
import '../paywall/paywall_screen.dart';
import 'timeline_editor.dart';
import 'template_manager.dart';
import 'display_settings_modal.dart';
import 'theme_chooser_modal.dart';
import 'theme_editor_modal.dart';
import 'user_settings_modal.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  Timer? _timer;
  int _currentTaskIndex = -1;
  double _elapsedInTask = 0;
  bool _showTour = false;
  final ScrollController _scrollController = ScrollController();

  // GlobalKeys for tour spotlight targets
  final _keyTaskEditor = GlobalKey();
  final _keyAddTask = GlobalKey();
  final _keyDisplaySettings = GlobalKey();
  final _keyChangeTheme = GlobalKey();
  final _keySaveButton = GlobalKey();
  final _keyExitAdmin = GlobalKey();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateProgress());
    _updateProgress();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final seen = await hasSeenOnboarding();
    if (!seen && mounted) {
      // Delay to let the UI render so GlobalKeys have valid contexts
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showTour = true);
    }
  }

  void startTour() {
    setState(() => _showTour = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    final schoolState = ref.read(schoolProvider).valueOrNull;
    if (schoolState == null) return;

    final progress = getCurrentTaskProgress(
      DateTime.now(),
      schoolState.timeline.startTime,
      schoolState.timeline.tasks,
    );

    if (mounted &&
        (_currentTaskIndex != progress.currentTaskIndex ||
            _elapsedInTask != progress.elapsedInTask)) {
      setState(() {
        _currentTaskIndex = progress.currentTaskIndex;
        _elapsedInTask = progress.elapsedInTask;
      });
    }
  }

  void _exitAdmin() {
    ref.read(sessionModeProvider.notifier).state = null;
  }


  Future<void> _saveAll() async {
    try {
      await ref.read(schoolProvider.notifier).saveAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _showSaveAsTemplate() {
    final schoolState = ref.read(schoolProvider).valueOrNull;
    if (schoolState == null) return;

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'e.g. Morning Routine',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final newTemplate = TaskTemplate(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text.trim(),
                  startTime: schoolState.timeline.startTime,
                  endTime: schoolState.timeline.endTime,
                  tasks: schoolState.timeline.tasks
                      .map((t) => Task.fromJson(t.toJson()))
                      .toList(),
                  // Capture the current look so it follows this template.
                  settings: schoolState.displaySettings,
                  theme: schoolState.currentTheme,
                  endCard: schoolState.timeline.endCard,
                );
                ref.read(schoolProvider.notifier).updateTemplates(
                    [...schoolState.templates, newTemplate]);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template saved!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDisplaySettings() {
    showDialog(
      context: context,
      builder: (_) => const DisplaySettingsModal(),
    );
  }

  void _showThemeChooser() {
    showDialog(
      context: context,
      builder: (_) => ThemeChooserModal(
        onCreateCustom: () {
          Navigator.pop(context);
          _showThemeEditor(null);
        },
        onEditCustom: (theme) {
          Navigator.pop(context);
          _showThemeEditor(theme);
        },
      ),
    );
  }

  void _showThemeEditor(dynamic editingTheme) {
    showDialog(
      context: context,
      builder: (_) => ThemeEditorModal(
        editingTheme: editingTheme,
        onBack: () {
          Navigator.pop(context);
          _showThemeChooser();
        },
      ),
    );
  }

  void _showUserSettings() {
    showDialog(
      context: context,
      builder: (_) => UserSettingsModal(onStartTour: startTour),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolState = ref.watch(schoolProvider);

    return schoolState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (state) {
        if (state == null) {
          return const Scaffold(
            body: Center(child: Text('No data')),
          );
        }

        final theme = getActiveTheme(state.currentTheme, state.customThemes);

        return Scaffold(
          body: Stack(
            children: [
              Column(
            children: [
              // Toolbar
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centred title
                      Column(
                        children: [
                          const Text(
                            'Timeline Editor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandText,
                            ),
                          ),
                          Text(
                            '${state.school.schoolName} - ${state.school.className}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.brandTextMuted,
                            ),
                          ),
                        ],
                      ),
                      // Left + right buttons
                      Row(
                        children: [
                          // Left buttons
                          if (!state.isFreeMode && !state.isSessionOnlyMode) ...[
                            ElevatedButton.icon(
                              key: _keySaveButton,
                              onPressed: state.hasUnsavedChanges && !state.isSaving
                                  ? _saveAll
                                  : null,
                              icon: const Icon(LucideIcons.save, size: 18),
                              label: Text(state.isSaving
                                  ? 'Saving...'
                                  : state.hasUnsavedChanges
                                      ? 'Save Changes'
                                      : 'Saved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: state.hasUnsavedChanges
                                    ? AppColors.brandAccent
                                    : Colors.grey.shade200,
                                foregroundColor: state.hasUnsavedChanges
                                    ? AppColors.brandPrimaryDark
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton.icon(
                            key: _keyDisplaySettings,
                            onPressed: _showDisplaySettings,
                            icon: const Icon(LucideIcons.monitor, size: 18),
                            label: const Text('Display Settings'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            key: _keyChangeTheme,
                            onPressed: _showThemeChooser,
                            icon: const Icon(LucideIcons.palette, size: 18),
                            label: const Text('Change Theme'),
                          ),
                          const Spacer(),
                          // Right buttons
                          OutlinedButton.icon(
                            onPressed: _showUserSettings,
                            icon: const Icon(LucideIcons.settings, size: 18),
                            label: const Text('User Settings'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            key: _keyExitAdmin,
                            onPressed: _exitAdmin,
                            icon: const Icon(LucideIcons.arrowLeft, size: 18),
                            label: const Text('Exit Admin'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Free tier banner
              if (state.isFreeMode)
                Container(
                  key: _keySaveButton, // Reuse key for tour step 6 (free variant)
                  color: AppColors.brandPrimaryBg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.sparkles,
                          color: AppColors.brandPrimary, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Free plan — 5 tasks, preset themes only, no saving. Upgrade for full features!',
                          style: TextStyle(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaywallScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandPrimary,
                          side: const BorderSide(color: AppColors.brandPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                ),

              // Session-only mode banner (staff)
              if (state.isSessionOnlyMode)
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Session-only mode — changes are temporary and will not be saved.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Unsaved changes banner
              if (state.hasUnsavedChanges && !state.isFreeMode && !state.isSessionOnlyMode)
                Container(
                  color: Colors.amber.shade50,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You have unsaved changes. Click "Save Changes" to save.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: state.isSaving ? null : _saveAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandAccent,
                          foregroundColor: AppColors.brandPrimaryDark,
                        ),
                        child: Text(
                            state.isSaving ? 'Saving...' : 'Save Now'),
                      ),
                    ],
                  ),
                ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Weekly Schedule (paid + teacher only)
                      if (!state.isFreeMode && !state.isSessionOnlyMode) ...[
                        TemplateManager(
                          templates: state.templates,
                          weeklySchedule: state.weeklySchedule,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Task Editor
                      TimelineEditor(
                        timeline: state.timeline,
                        displaySettings: state.displaySettings,
                        theme: theme,
                        currentTaskIndex: _currentTaskIndex,
                        elapsedInTask: _elapsedInTask,
                        tourKeyEditor: _keyTaskEditor,
                        tourKeyAddTask: _keyAddTask,
                        onSaveAsTemplate: (state.isFreeMode || state.isSessionOnlyMode) ? null : _showSaveAsTemplate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

              // Onboarding tour overlay
              if (_showTour)
                OnboardingTourOverlay(
                  steps: _buildTourSteps(state.isFreeMode, state.isSessionOnlyMode),
                  onComplete: () => setState(() => _showTour = false),
                ),
            ],
          ),
        );
      },
    );
  }

  List<TourStep> _buildTourSteps(bool isFreeMode, [bool isSessionOnly = false]) {
    return [
      TourStep(
        targetKey: _keyTaskEditor,
        title: 'Your Timeline',
        description:
            'This is your daily schedule. Set the start time so the display '
            'knows when your first task begins, then add tasks with names, '
            'icons, and durations.',
      ),
      TourStep(
        targetKey: _keyAddTask,
        title: 'Add Tasks',
        description:
            'Add a new task to your timeline. Each task has a name, an optional '
            'icon, and a duration. Tap an existing task card to edit its details.',
      ),
      TourStep(
        targetKey: _keyDisplaySettings,
        title: 'Display Settings',
        description:
            'Configure how your timeline appears on screen. Choose between '
            'horizontal, multi-row, or auto-pan layouts. Set up banners, '
            'clock display, and screen resolution.',
      ),
      TourStep(
        targetKey: _keyChangeTheme,
        title: 'Visual Themes',
        description:
            'Select a visual theme for your classroom display. '
            '${isFreeMode ? 'Preset themes are included with the free plan. Upgrade to create custom themes.' : 'Choose a preset theme or create your own with custom colours, fonts, and styles.'}',
      ),
      TourStep(
        targetKey: _keySaveButton,
        title: isFreeMode ? 'Free Plan' : 'Save Your Work',
        description: isFreeMode
            ? 'You are on the free plan. Changes are stored in your browser '
              'for this session. Upgrade to save your schedules, sync across '
              'devices, and access all features.'
            : 'Save your changes to sync them across all connected displays '
              'in real time. Any device logged into your classroom will '
              'update automatically.',
      ),
      TourStep(
        targetKey: _keyExitAdmin,
        title: 'View Your Display',
        description:
            'When your schedule is ready, exit the admin panel to see the '
            'classroom display. Open this same link on your classroom screen '
            'and select Display Mode to show the timeline.',
      ),
    ];
  }
}
