import 'task.dart';

/// The card shown at the very end of a timeline (default "Home Time"). It's a
/// full, editable card (content/icon/image/size) like a task, but carries no
/// duration and lives outside the tasks list so progress/time/limit logic is
/// unaffected. Per-template, enabled by default.
class EndCard {
  final bool enabled;
  final Task task;

  const EndCard({this.enabled = true, required this.task});

  /// The out-of-the-box end card: a home icon labelled "Home Time".
  factory EndCard.initial() => EndCard(
        task: Task(
          id: 'end-card',
          type: 'icon',
          content: 'Home Time',
          icon: 'home',
          duration: 0,
        ),
      );

  factory EndCard.fromJson(Map<String, dynamic> json) {
    final taskJson = json['task'];
    return EndCard(
      enabled: json['enabled'] as bool? ?? true,
      task: taskJson is Map<String, dynamic>
          ? Task.fromJson(taskJson)
          : EndCard.initial().task,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'task': task.toJson(),
      };

  EndCard copyWith({bool? enabled, Task? task}) => EndCard(
        enabled: enabled ?? this.enabled,
        task: task ?? this.task,
      );
}
