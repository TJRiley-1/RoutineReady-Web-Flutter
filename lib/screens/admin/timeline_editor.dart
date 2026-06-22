import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme_constants.dart';
import '../../data/icon_library.dart';
import '../../models/active_timeline.dart';
import '../../models/display_settings.dart';
import '../../models/task.dart';
import '../../models/theme_config.dart';
import '../../providers/school_provider.dart';
import '../../utils/theme_utils.dart';
import '../../utils/time_utils.dart';
import '../../widgets/display/transition_indicator.dart';
import '../display/horizontal_display.dart';
import '../display/multi_row_display.dart';
import '../display/auto_pan_display.dart';
import 'task_editor_modal.dart';

class TimelineEditor extends ConsumerStatefulWidget {
  final ActiveTimeline timeline;
  final DisplaySettings displaySettings;
  final ThemeConfig theme;
  final int currentTaskIndex;
  final double elapsedInTask;
  final GlobalKey? tourKeyEditor;
  final GlobalKey? tourKeyAddTask;
  final VoidCallback? onSaveAsTemplate;

  const TimelineEditor({
    super.key,
    required this.timeline,
    required this.displaySettings,
    required this.theme,
    required this.currentTaskIndex,
    required this.elapsedInTask,
    this.tourKeyEditor,
    this.tourKeyAddTask,
    this.onSaveAsTemplate,
  });

  @override
  ConsumerState<TimelineEditor> createState() => _TimelineEditorState();
}

class _TimelineEditorState extends ConsumerState<TimelineEditor> {
  final ScrollController _taskScrollController = ScrollController();

  @override
  void dispose() {
    _taskScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeline = widget.timeline;
    final displaySettings = widget.displaySettings;
    final theme = widget.theme;
    final currentTaskIndex = widget.currentTaskIndex;
    final elapsedInTask = widget.elapsedInTask;

    return Card(
      key: widget.tourKeyEditor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Builder(builder: (context) {
              final isFree = ref.watch(schoolProvider).valueOrNull?.isFreeMode ?? false;
              final atLimit = isFree && timeline.tasks.length >= 5;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Centred title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Edit Tasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandText,
                        ),
                      ),
                      if (isFree) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${timeline.tasks.length}/5',
                          style: TextStyle(
                            fontSize: 14,
                            color: atLimit ? AppColors.brandError : AppColors.brandTextMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Right-aligned buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onSaveAsTemplate != null) ...[
                        ElevatedButton.icon(
                          onPressed: widget.onSaveAsTemplate,
                          icon: const Icon(LucideIcons.bookmarkPlus, size: 18),
                          label: const Text('Save as Template'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        key: widget.tourKeyAddTask,
                        onPressed: atLimit ? null : () => _addTask(context),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('Add Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandSuccess,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Scrollable task list
            SizedBox(
              height: 320,
              child: Scrollbar(
                controller: _taskScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _taskScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Start time
                      _StartTimeCard(
                        startTime: timeline.startTime,
                        onChanged: (time) => _updateStartTime(time),
                      ),
                      const SizedBox(width: 16),
                      // Tasks
                      ...List.generate(timeline.tasks.length, (index) {
                        final task = timeline.tasks[index];
                        return Row(
                          children: [
                            _TaskEditCard(
                              task: task,
                              displaySettings: displaySettings,
                              onEdit: () => _editTask(context, task),
                              onDelete: () => _deleteTask(task.id),
                              onTimeAdjust: (delta) =>
                                  _adjustTime(task.id, delta),
                            ),
                            const SizedBox(width: 8),
                            if (displaySettings.mode != 'auto-pan')
                              SizedBox(
                                width: 120,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Transition',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.brandTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TransitionIndicator(
                                      displaySettings: displaySettings,
                                      theme: theme,
                                      taskDuration: task.duration,
                                      elapsed: elapsedInTask,
                                      isPast: index < currentTaskIndex,
                                      isActive: index == currentTaskIndex,
                                      width: 100,
                                    ),
                                    // Manual row break (multi-row only) — not
                                    // shown after the last task.
                                    if (displaySettings.mode == 'multi-row' &&
                                        index <
                                            timeline.tasks.length - 1) ...[
                                      const SizedBox(height: 6),
                                      _RowBreakToggle(
                                        active: task.breakAfter,
                                        onTap: () =>
                                            _toggleBreakAfter(task.id),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            const SizedBox(width: 8),
                          ],
                        );
                      }),
                      // End time
                      _EndTimeCard(
                        endTime:
                            calculateEndTime(timeline.startTime, timeline.tasks),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Live Preview header
            Text(
              'Live Display Preview - ${displaySettings.width}x${displaySettings.height} at ${displaySettings.scale}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.brandText,
              ),
            ),
            const SizedBox(height: 8),

            // Road width — multi-row only. Lives here (not in Display Settings)
            // so the reflow is visible live in the preview below. Saved per
            // template via updateDisplaySettings.
            if (displaySettings.mode == 'multi-row') ...[
              Row(
                children: [
                  const Icon(Icons.swap_horiz,
                      size: 18, color: AppColors.brandTextMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Road width: ${displaySettings.multiRowWidth}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandText,
                    ),
                  ),
                ],
              ),
              Slider(
                value: displaySettings.multiRowWidth.clamp(40, 100).toDouble(),
                min: 40,
                max: 100,
                divisions: 12,
                label: '${displaySettings.multiRowWidth}%',
                onChanged: (v) => ref
                    .read(schoolProvider.notifier)
                    .updateDisplaySettings(
                        displaySettings.copyWith(multiRowWidth: v.round())),
              ),
              const Text(
                'Wider fills more of the display; cards wrap to the next row at the edge.',
                style:
                    TextStyle(fontSize: 11, color: AppColors.brandTextMuted),
              ),
              const SizedBox(height: 12),
            ],

            // Live preview — use LayoutBuilder to fill available width
            LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = displaySettings.width / displaySettings.height;
                final previewWidth = constraints.maxWidth;
                final previewHeight = previewWidth / aspectRatio;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: previewWidth,
                    height: previewHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.brandBorder, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: displaySettings.width.toDouble(),
                        height: displaySettings.height.toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: getBackgroundGradient(theme),
                          ),
                          child: _buildDisplayMode(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayMode() {
    final displaySettings = widget.displaySettings;
    final timeline = widget.timeline;
    final theme = widget.theme;
    final currentTaskIndex = widget.currentTaskIndex;
    final elapsedInTask = widget.elapsedInTask;

    switch (displaySettings.mode) {
      case 'horizontal':
        return HorizontalDisplay(
          timeline: timeline,
          displaySettings: displaySettings,
          theme: theme,
          currentTaskIndex: currentTaskIndex,
          elapsedInTask: elapsedInTask,
        );
      case 'multi-row':
        return MultiRowDisplay(
          timeline: timeline,
          displaySettings: displaySettings,
          theme: theme,
          currentTaskIndex: currentTaskIndex,
          elapsedInTask: elapsedInTask,
        );
      case 'auto-pan':
      default:
        return AutoPanDisplay(
          timeline: timeline,
          displaySettings: displaySettings,
          theme: theme,
          currentTaskIndex: currentTaskIndex,
          elapsedInTask: elapsedInTask,
        );
    }
  }

  void _addTask(BuildContext context) {
    final timeline = widget.timeline;
    final isFree = ref.read(schoolProvider).valueOrNull?.isFreeMode ?? false;
    if (isFree && timeline.tasks.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free plan is limited to 5 tasks. Upgrade for unlimited tasks.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch,
      type: 'text',
      content: 'New Task',
      duration: 30,
    );
    final updated = timeline.copyWith(
      tasks: [...timeline.tasks, newTask],
    );
    ref.read(schoolProvider.notifier).updateTimeline(updated);
  }

  void _deleteTask(dynamic taskId) {
    final updated = widget.timeline.copyWith(
      tasks: widget.timeline.tasks.where((t) => t.id != taskId).toList(),
    );
    ref.read(schoolProvider.notifier).updateTimeline(updated);
  }

  void _adjustTime(dynamic taskId, int delta) {
    final updated = widget.timeline.copyWith(
      tasks: widget.timeline.tasks.map((t) {
        if (t.id == taskId) {
          return t.copyWith(
              duration: (t.duration + delta).clamp(5, 180));
        }
        return t;
      }).toList(),
    );
    ref.read(schoolProvider.notifier).updateTimeline(updated);
  }

  void _updateStartTime(String time) {
    final updated = widget.timeline.copyWith(startTime: time);
    ref.read(schoolProvider.notifier).updateTimeline(updated);
  }

  void _toggleBreakAfter(dynamic taskId) {
    final updated = widget.timeline.copyWith(
      tasks: widget.timeline.tasks
          .map((t) =>
              t.id == taskId ? t.copyWith(breakAfter: !t.breakAfter) : t)
          .toList(),
    );
    ref.read(schoolProvider.notifier).updateTimeline(updated);
  }

  void _editTask(BuildContext context, Task task) {
    final schoolId = ref.read(schoolProvider).valueOrNull?.school.id;
    if (schoolId == null) return;
    showDialog(
      context: context,
      builder: (_) => TaskEditorModal(
        task: task,
        schoolId: schoolId,
        isFreeMode: ref.read(schoolProvider).valueOrNull?.isFreeMode ?? false,
        onSave: (updatedTask) {
          final updated = widget.timeline.copyWith(
            tasks: widget.timeline.tasks
                .map((t) => t.id == updatedTask.id ? updatedTask : t)
                .toList(),
          );
          ref.read(schoolProvider.notifier).updateTimeline(updated);
        },
      ),
    );
  }
}

class _TaskEditCard extends StatelessWidget {
  final Task task;
  final DisplaySettings displaySettings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(int delta) onTimeAdjust;

  const _TaskEditCard({
    required this.task,
    required this.displaySettings,
    required this.onEdit,
    required this.onDelete,
    required this.onTimeAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = getIconData(task.icon);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandBorder, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null)
            Icon(iconData, size: 48, color: AppColors.brandPrimary),
          const SizedBox(height: 8),
          Text(
            task.content,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Time controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimeButton(
                label: '-5',
                enabled: task.duration > 5,
                isDecrease: true,
                onPressed: () => onTimeAdjust(-5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${task.duration} min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brandTextMuted,
                  ),
                ),
              ),
              _TimeButton(
                label: '+5',
                enabled: task.duration < 180,
                isDecrease: false,
                onPressed: () => onTimeAdjust(5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Edit/Delete buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                  ),
                  child: const Icon(LucideIcons.edit2, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandError,
                    padding: const EdgeInsets.all(8),
                  ),
                  child: const Icon(LucideIcons.trash2, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small toggle in a transition slot that forces a new row to start after the
/// preceding task (multi-row mode).
class _RowBreakToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _RowBreakToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.brandPrimary : AppColors.brandBgSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.brandPrimary : AppColors.brandBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subdirectory_arrow_left,
              size: 14,
              color: active ? Colors.white : AppColors.brandTextMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'New row',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.brandTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isDecrease;
  final VoidCallback onPressed;

  const _TimeButton({
    required this.label,
    required this.enabled,
    required this.isDecrease,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isDecrease ? Colors.red.shade100 : Colors.green.shade100,
          foregroundColor: isDecrease ? Colors.red.shade700 : Colors.green.shade700,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}

class _StartTimeCard extends StatelessWidget {
  final String startTime;
  final ValueChanged<String> onChanged;

  const _StartTimeCard({required this.startTime, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.clock, size: 32, color: AppColors.brandPrimary),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final parts = startTime.split(':').map(int.parse).toList();
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
              );
              if (picked != null) {
                onChanged(
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.brandPrimary),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                startTime,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brandPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndTimeCard extends StatelessWidget {
  final String endTime;

  const _EndTimeCard({required this.endTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clock, size: 32, color: AppColors.brandError),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brandError),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              endTime,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'End',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brandError,
            ),
          ),
        ],
      ),
    );
  }
}
