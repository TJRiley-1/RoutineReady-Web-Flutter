import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/active_timeline.dart';
import '../../models/display_settings.dart';
import '../../models/end_card.dart';
import '../../models/theme_config.dart';
import '../../utils/theme_utils.dart';
import '../../utils/time_utils.dart';
import '../../widgets/display/task_card.dart';
import '../../widgets/display/transition_indicator.dart';

class HorizontalDisplay extends StatefulWidget {
  final ActiveTimeline timeline;
  final DisplaySettings displaySettings;
  final ThemeConfig theme;
  final int currentTaskIndex;
  final double elapsedInTask;

  const HorizontalDisplay({
    super.key,
    required this.timeline,
    required this.displaySettings,
    required this.theme,
    required this.currentTaskIndex,
    required this.elapsedInTask,
  });

  @override
  State<HorizontalDisplay> createState() => _HorizontalDisplayState();
}

class _HorizontalDisplayState extends State<HorizontalDisplay> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrolledToIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HorizontalDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTaskIndex != _lastScrolledToIndex &&
        widget.currentTaskIndex >= 0) {
      _scrollToCurrentTask();
    }
  }

  void _scrollToCurrentTask() {
    if (!_scrollController.hasClients) return;
    _lastScrolledToIndex = widget.currentTaskIndex;

    // Calculate approximate scroll position:
    // Each task = task.width + transition(task.width*1.5) + gaps(16)
    // Plus the start time card (~140 + 8)
    double offset = 148; // start time card width + gap
    for (var i = 0; i < widget.currentTaskIndex; i++) {
      final task = widget.timeline.tasks[i];
      offset += task.width +
          (task.width * 1.5 * task.transitionScale) +
          16; // card + transition + gaps
    }

    // Center the current task on screen
    final screenWidth = _scrollController.position.viewportDimension;
    final targetOffset = (offset - screenWidth / 2 +
            widget.timeline.tasks[widget.currentTaskIndex].width / 2)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = parseHexColor(widget.theme.timeCardAccentColor);
    final endAccentColor = widget.theme.timeCardAccentColorAlt != null
        ? parseHexColor(widget.theme.timeCardAccentColorAlt!)
        : accentColor;

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Start time card
              _TimeCard(
                time: widget.timeline.startTime,
                label: 'Start',
                accentColor: accentColor,
              ),
              const SizedBox(width: 8),
              // Tasks with transitions
              ...List.generate(widget.timeline.tasks.length, (index) {
                final task = widget.timeline.tasks[index];
                final isCurrent = index == widget.currentTaskIndex;
                final isPast = index < widget.currentTaskIndex;
                final transitionWidth = (task.width * 1.5 * task.transitionScale);

                return Row(
                  children: [
                    TaskCard(
                      task: task,
                      theme: widget.theme,
                      isCurrent: isCurrent,
                      isPast: isPast,
                      index: index,
                    ),
                    const SizedBox(width: 4),
                    TransitionIndicator(
                      displaySettings: widget.displaySettings,
                      theme: widget.theme,
                      taskDuration: task.duration,
                      elapsed: widget.elapsedInTask,
                      isPast: isPast,
                      isActive: isCurrent,
                      width: transitionWidth,
                    ),
                    const SizedBox(width: 4),
                  ],
                );
              }),
              // End ("Home Time") card — the last task's trailing transition
              // above leads into it, giving that task its progress indicator.
              if ((widget.timeline.endCard ?? EndCard.initial()).enabled) ...[
                TaskCard(
                  task: (widget.timeline.endCard ?? EndCard.initial()).task,
                  theme: widget.theme,
                  index: widget.timeline.tasks.length,
                ),
                const SizedBox(width: 8),
              ],
              // End time card
              _TimeCard(
                time: calculateEndTime(
                    widget.timeline.startTime, widget.timeline.tasks),
                label: 'End',
                accentColor: endAccentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String time;
  final String label;
  final Color accentColor;

  const _TimeCard({
    required this.time,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clock, size: 48, color: accentColor),
          const SizedBox(height: 12),
          Text(
            time,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C2B2A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
