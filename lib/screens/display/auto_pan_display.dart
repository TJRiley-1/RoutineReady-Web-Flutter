import 'package:flutter/material.dart';
import '../../data/icon_library.dart';
import '../../models/active_timeline.dart';
import '../../models/display_settings.dart';
import '../../models/theme_config.dart';
import '../../utils/theme_utils.dart';
import '../../widgets/display/banner_bar.dart';
import '../../widgets/display/transition_indicator.dart';

class AutoPanDisplay extends StatefulWidget {
  final ActiveTimeline timeline;
  final DisplaySettings displaySettings;
  final ThemeConfig theme;
  final int currentTaskIndex;
  final double elapsedInTask;

  const AutoPanDisplay({
    super.key,
    required this.timeline,
    required this.displaySettings,
    required this.theme,
    required this.currentTaskIndex,
    required this.elapsedInTask,
  });

  @override
  State<AutoPanDisplay> createState() => _AutoPanDisplayState();
}

class _AutoPanDisplayState extends State<AutoPanDisplay> {
  @override
  Widget build(BuildContext context) {
    final currentTask =
        widget.currentTaskIndex >= 0 && widget.currentTaskIndex < widget.timeline.tasks.length
            ? widget.timeline.tasks[widget.currentTaskIndex]
            : null;
    final nextTask = widget.currentTaskIndex + 1 < widget.timeline.tasks.length
        ? widget.timeline.tasks[widget.currentTaskIndex + 1]
        : null;

    final borderColor = parseHexColor(widget.theme.cardBorderColor);
    final glowColor = parseHexColor(widget.theme.currentGlowColor);
    final remaining = ((currentTask?.duration ?? 0) - widget.elapsedInTask)
        .clamp(0, double.infinity)
        .floor();
    final minuteWord = remaining == 1 ? 'Minute' : 'Minutes';

    return Column(
      children: [
        // Top Banner
        BannerBar(
          imageUrl: widget.displaySettings.topBannerImage,
          height: widget.displaySettings.topBannerHeight,
          theme: widget.theme,
          showClock: widget.displaySettings.showClock,
          isTop: true,
        ),

        // Main content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Current task (flex 1)
                Expanded(
                  flex: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      color: parseColorString(widget.theme.currentBgOverlay),
                      borderRadius: BorderRadius.circular(widget.theme.borderRadius),
                      border: Border.all(
                        color: widget.theme.currentBorderEnhance
                            ? glowColor
                            : borderColor,
                        width: widget.theme.borderWidthValue * 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: currentTask != null
                          ? _TaskContent(
                              key: ValueKey('current-${widget.currentTaskIndex}'),
                              label: 'CURRENT TASK',
                              labelColor: glowColor,
                              task: currentTask,
                              theme: widget.theme,
                              iconColor: borderColor,
                              iconSize: 80,
                              fontSize: 36,
                              durationFontSize: 24,
                            )
                          : const Center(
                              key: ValueKey('no-task'),
                              child: Text(
                                'No current task',
                                style: TextStyle(
                                    fontSize: 24, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                    ),
                  ),
                ),

                // Transition indicator (flex 3)
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TransitionIndicator(
                        displaySettings: widget.displaySettings,
                        theme: widget.theme,
                        taskDuration: currentTask?.duration ?? 30,
                        elapsed: widget.elapsedInTask,
                        isPast: false,
                        isActive: true,
                        width: MediaQuery.of(context).size.width *
                            (widget.displaySettings.autoPanRoadWidth / 100),
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          '$remaining $minuteWord Remaining',
                          key: ValueKey(remaining),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Next task (flex 1)
                Expanded(
                  flex: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      color: parseHexColor(widget.theme.cardBgColor),
                      borderRadius: BorderRadius.circular(widget.theme.borderRadius),
                      border: Border.all(
                        color: borderColor,
                        width: widget.theme.borderWidthValue,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: nextTask != null
                          ? _TaskContent(
                              key: ValueKey('next-${widget.currentTaskIndex + 1}'),
                              label: 'NEXT TASK',
                              labelColor: const Color(0xFF9CA3AF),
                              task: nextTask,
                              theme: widget.theme,
                              iconColor: borderColor,
                              iconSize: 64,
                              fontSize: 28,
                              durationFontSize: 20,
                            )
                          : const Center(
                              key: ValueKey('all-done'),
                              child: Text(
                                'All done!',
                                style: TextStyle(
                                    fontSize: 20, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Banner
        BannerBar(
          imageUrl: widget.displaySettings.bottomBannerImage,
          height: widget.displaySettings.bottomBannerHeight,
          theme: widget.theme,
          isTop: false,
        ),
      ],
    );
  }
}

class _TaskContent extends StatelessWidget {
  final String label;
  final Color labelColor;
  final dynamic task;
  final ThemeConfig theme;
  final Color iconColor;
  final double iconSize;
  final double fontSize;
  final double durationFontSize;

  const _TaskContent({
    super.key,
    required this.label,
    required this.labelColor,
    required this.task,
    required this.theme,
    required this.iconColor,
    required this.iconSize,
    required this.fontSize,
    required this.durationFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 16),
        if (task.type == 'image' && task.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              task.imageUrl!,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_not_supported,
                size: iconSize,
                color: Colors.grey,
              ),
            ),
          )
        else if (task.icon != null)
          Icon(
            getIconData(task.icon),
            size: iconSize,
            color: iconColor,
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            theme.fontTransform == 'uppercase'
                ? task.content.toUpperCase()
                : task.content,
            textAlign: TextAlign.center,
            style: getThemeTextStyle(theme, fontSize).copyWith(
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${task.duration} min',
          style: TextStyle(
            fontSize: durationFontSize,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
