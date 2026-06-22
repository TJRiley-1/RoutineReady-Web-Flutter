import 'task.dart';
import 'display_settings.dart';
import 'end_card.dart';

class ActiveTimeline {
  final String startTime;
  final String endTime;
  final List<Task> tasks;

  /// Snapshot of the per-template display settings currently shown. Null for
  /// legacy/ad-hoc timelines that predate per-template settings.
  final DisplaySettings? settings;

  /// Snapshot of the theme currently shown. Null falls back to school default.
  final String? theme;

  /// The end ("Home Time") card. Null falls back to the default.
  final EndCard? endCard;

  ActiveTimeline({
    this.startTime = '08:00',
    this.endTime = '10:30',
    this.tasks = const [],
    this.settings,
    this.theme,
    this.endCard,
  });

  factory ActiveTimeline.fromJson(Map<String, dynamic> json) {
    final tasksJson = json['tasks_json'] ?? json['tasks'] ?? [];
    final settingsJson = json['settings_json'] ?? json['settings'];
    final endCardJson = json['end_card_json'] ?? json['endCard'];
    return ActiveTimeline(
      startTime: json['start_time'] as String? ?? json['startTime'] as String? ?? '08:00',
      endTime: json['end_time'] as String? ?? json['endTime'] as String? ?? '10:30',
      tasks: (tasksJson as List<dynamic>)
          .map((t) => Task.fromJson(t as Map<String, dynamic>))
          .toList(),
      settings: settingsJson is Map<String, dynamic>
          ? DisplaySettings.fromDbJson(settingsJson)
          : null,
      theme: json['current_theme'] as String? ?? json['theme'] as String?,
      endCard: endCardJson is Map<String, dynamic>
          ? EndCard.fromJson(endCardJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'settings': settings?.toTemplateDbJson(),
        'theme': theme,
        'endCard': endCard?.toJson(),
      };

  ActiveTimeline copyWith({
    String? startTime,
    String? endTime,
    List<Task>? tasks,
    DisplaySettings? settings,
    String? theme,
    EndCard? endCard,
  }) {
    return ActiveTimeline(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tasks: tasks ?? this.tasks,
      settings: settings ?? this.settings,
      theme: theme ?? this.theme,
      endCard: endCard ?? this.endCard,
    );
  }
}
