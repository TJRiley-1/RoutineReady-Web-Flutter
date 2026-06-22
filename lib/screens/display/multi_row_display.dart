import 'package:flutter/material.dart';
import '../../models/active_timeline.dart';
import '../../models/display_settings.dart';
import '../../models/end_card.dart';
import '../../models/task.dart';
import '../../models/theme_config.dart';
import '../../widgets/display/task_card.dart';
import '../../widgets/display/transition_indicator.dart';

/// Multi-row display. Cards flow left→right and wrap to the next row when they'd
/// exceed the configured road width (a percentage of the display width), so the
/// number of rows is automatic. A task with [Task.breakAfter] forces a new row.
/// The end ("Home Time") card, when enabled, is appended as a final item so the
/// last real task gets its connecting transition. The whole block scales down to
/// fit if a very narrow road forces more rows than the height can hold.
class MultiRowDisplay extends StatelessWidget {
  final ActiveTimeline timeline;
  final DisplaySettings displaySettings;
  final ThemeConfig theme;
  final int currentTaskIndex;
  final double elapsedInTask;

  /// Cards are rendered at this fraction of their natural size.
  static const _scale = 0.8;

  /// Width set aside for the start/end time labels that bracket each row.
  static const _timeLabelReserve = 96.0;

  /// Gap on each side of a transition indicator.
  static const _gap = 2.0;

  const MultiRowDisplay({
    super.key,
    required this.timeline,
    required this.displaySettings,
    required this.theme,
    required this.currentTaskIndex,
    required this.elapsedInTask,
  });

  @override
  Widget build(BuildContext context) {
    if (timeline.tasks.isEmpty) return const SizedBox.shrink();

    // The end card rides along as a final item so the last real task gets its
    // connecting transition. It never counts as current/past (its index is
    // beyond the real tasks).
    final endCard = timeline.endCard ?? EndCard.initial();
    final items = <Task>[
      ...timeline.tasks,
      if (endCard.enabled) endCard.task,
    ];

    final isSnake = displaySettings.pathDirection == 'snake';
    // Cards wrap at the full display width; per-transition widths (transitionScale)
    // let the user stretch a row to fill it.
    final available = (displaySettings.width - _timeLabelReserve)
        .clamp(_scale * 100, displaySettings.width.toDouble());

    final rowsIdx = _packRows(items, available);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rowsIdx.length; r++) ...[
              if (r > 0) const SizedBox(height: 24),
              _buildRow(
                items,
                rowsIdx[r],
                isSnake && r.isOdd,
                r < rowsIdx.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Greedily packs item indices into rows so each row stays within [available].
  /// A card is preceded by a connector (transition + gaps) when it isn't first
  /// in its row. A task with [Task.breakAfter] forces the row to close after it,
  /// letting the user compose rows manually regardless of width.
  List<List<int>> _packRows(List<Task> items, double available) {
    final rows = <List<int>>[];
    var row = <int>[];
    var width = 0.0;
    for (var i = 0; i < items.length; i++) {
      final cardW = items[i].width * _scale;
      final connector = row.isEmpty
          ? 0.0
          : (items[i - 1].width * _scale * items[i - 1].transitionScale +
              _gap * 2);
      if (row.isNotEmpty && width + connector + cardW > available) {
        rows.add(row);
        row = [i];
        width = cardW;
      } else {
        row.add(i);
        width += connector + cardW;
      }
      if (items[i].breakAfter) {
        rows.add(row);
        row = [];
        width = 0.0;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  Widget _buildRow(
      List<Task> items, List<int> indices, bool isReversed, bool hasNext) {
    final ordered = isReversed ? indices.reversed.toList() : indices;
    final startTime = _calculateTimeAtIndex(items, indices.first);
    final endTime = _calculateTimeAtIndex(items, indices.last + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _timeLabel(isReversed ? endTime : startTime),
          // For snake (reversed) rows the outgoing edge — where the road drops
          // to the next row — is on the left, so the bridge sits before the cards.
          if (isReversed && hasNext) _bridge(items, indices.last),
          ...List.generate(ordered.length, (j) {
            final idx = ordered[j];
            final task = items[idx];
            final isCurrent = idx == currentTaskIndex;
            final isPast = idx < currentTaskIndex;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TaskCard(
                  task: task,
                  theme: theme,
                  isCurrent: isCurrent,
                  isPast: isPast,
                  index: idx,
                  overrideWidth: task.width * _scale,
                  overrideHeight: task.height * _scale,
                ),
                if (j < ordered.length - 1) ...[
                  const SizedBox(width: _gap),
                  TransitionIndicator(
                    displaySettings: displaySettings,
                    theme: theme,
                    taskDuration: task.duration,
                    elapsed: elapsedInTask,
                    isPast: isPast,
                    isActive: isCurrent,
                    width: task.width * _scale * task.transitionScale,
                  ),
                  const SizedBox(width: _gap),
                ],
              ],
            );
          }),
          // Normal rows: the road continues off the right edge to the next row.
          if (!isReversed && hasNext) _bridge(items, indices.last),
          _timeLabel(isReversed ? startTime : endTime),
        ],
      ),
    );
  }

  /// The transition that carries the road from a row's last item ([itemIndex])
  /// onto the next row. Shown at the row's outgoing edge so a row break / wrap
  /// doesn't swallow the connecting transition.
  Widget _bridge(List<Task> items, int itemIndex) {
    final task = items[itemIndex];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: _gap),
        TransitionIndicator(
          displaySettings: displaySettings,
          theme: theme,
          taskDuration: task.duration,
          elapsed: elapsedInTask,
          isPast: itemIndex < currentTaskIndex,
          isActive: itemIndex == currentTaskIndex,
          width: task.width * _scale * task.transitionScale,
        ),
        const SizedBox(width: _gap),
      ],
    );
  }

  Widget _timeLabel(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10 * _scale,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      );

  String _calculateTimeAtIndex(List<Task> items, int itemIndex) {
    if (itemIndex <= 0) return timeline.startTime;

    final parts = timeline.startTime.split(':');
    var totalMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

    for (var i = 0; i < itemIndex && i < items.length; i++) {
      totalMinutes += items[i].duration;
    }

    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
