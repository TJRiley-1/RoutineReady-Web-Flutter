import 'package:flutter/material.dart';
import '../../models/active_timeline.dart';
import '../../models/display_settings.dart';
import '../../models/task.dart';
import '../../models/theme_config.dart';
import '../../widgets/display/task_card.dart';
import '../../widgets/display/transition_indicator.dart';

/// Multi-row display. Cards flow left→right and wrap to the next row when they'd
/// exceed the configured road width (a percentage of the display width), so the
/// number of rows is automatic. The whole block is scaled down to fit if a very
/// narrow road forces more rows than the height can hold.
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
    final tasks = timeline.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink();

    final isSnake = displaySettings.pathDirection == 'snake';
    final roadFraction = displaySettings.multiRowWidth.clamp(20, 100) / 100;
    // Width budget for the cards + transitions on a single row.
    final available =
        (displaySettings.width * roadFraction - _timeLabelReserve)
            .clamp(_scale * 100, displaySettings.width.toDouble());

    final rowsIdx = _packRows(tasks, available);

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
              _buildRow(rowsIdx[r], isSnake && r.isOdd),
            ],
          ],
        ),
      ),
    );
  }

  /// Greedily packs task indices into rows so each row stays within [available].
  /// A card is preceded by a connector (transition + gaps) when it isn't first
  /// in its row. A task with [Task.breakAfter] forces the row to close after it,
  /// letting the user compose rows manually regardless of width.
  List<List<int>> _packRows(List<Task> tasks, double available) {
    final rows = <List<int>>[];
    var row = <int>[];
    var width = 0.0;
    for (var i = 0; i < tasks.length; i++) {
      final cardW = tasks[i].width * _scale;
      final connector =
          row.isEmpty ? 0.0 : (tasks[i - 1].width * _scale + _gap * 2);
      if (row.isNotEmpty && width + connector + cardW > available) {
        rows.add(row);
        row = [i];
        width = cardW;
      } else {
        row.add(i);
        width += connector + cardW;
      }
      if (tasks[i].breakAfter) {
        rows.add(row);
        row = [];
        width = 0.0;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  Widget _buildRow(List<int> indices, bool isReversed) {
    final ordered = isReversed ? indices.reversed.toList() : indices;
    final startTime = _calculateTimeAtIndex(indices.first);
    final endTime = _calculateTimeAtIndex(indices.last + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _timeLabel(isReversed ? endTime : startTime),
          ...List.generate(ordered.length, (j) {
            final idx = ordered[j];
            final task = timeline.tasks[idx];
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
                    width: task.width * _scale,
                  ),
                  const SizedBox(width: _gap),
                ],
              ],
            );
          }),
          _timeLabel(isReversed ? startTime : endTime),
        ],
      ),
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

  String _calculateTimeAtIndex(int taskIndex) {
    if (taskIndex <= 0) return timeline.startTime;

    final parts = timeline.startTime.split(':');
    var totalMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

    for (var i = 0; i < taskIndex && i < timeline.tasks.length; i++) {
      totalMinutes += timeline.tasks[i].duration;
    }

    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
