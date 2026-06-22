import 'task.dart';
import 'display_settings.dart';
import 'end_card.dart';

class TaskTemplate {
  final dynamic id;
  final String name;
  final String startTime;
  final String endTime;
  final List<Task> tasks;

  /// Per-template display settings. The classroom-wide fields (mode, transition,
  /// width, height) are ignored here and resolved from `display_settings` at use.
  final DisplaySettings settings;

  /// Per-template theme id. Null falls back to the school default.
  final String? theme;

  /// Per-template end ("Home Time") card. Null falls back to the default.
  final EndCard? endCard;

  TaskTemplate({
    required this.id,
    required this.name,
    this.startTime = '08:00',
    this.endTime = '10:30',
    this.tasks = const [],
    this.settings = const DisplaySettings(),
    this.theme,
    this.endCard,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    final settingsJson = json['settings'] ?? json['settings_json'];
    final endCardJson = json['endCard'] ?? json['end_card_json'];
    return TaskTemplate(
      id: json['id'],
      name: json['name'] as String? ?? 'Untitled',
      startTime: json['startTime'] as String? ?? json['start_time'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? json['end_time'] as String? ?? '10:30',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => Task.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      settings: settingsJson is Map<String, dynamic>
          ? DisplaySettings.fromDbJson(settingsJson)
          : const DisplaySettings(),
      theme: json['theme'] as String? ?? json['current_theme'] as String?,
      endCard: endCardJson is Map<String, dynamic>
          ? EndCard.fromJson(endCardJson)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'settings': settings.toTemplateDbJson(),
        'theme': theme,
        'endCard': endCard?.toJson(),
      };

  TaskTemplate copyWith({
    dynamic id,
    String? name,
    String? startTime,
    String? endTime,
    List<Task>? tasks,
    DisplaySettings? settings,
    String? theme,
    EndCard? endCard,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tasks: tasks ?? this.tasks,
      settings: settings ?? this.settings,
      theme: theme ?? this.theme,
      endCard: endCard ?? this.endCard,
    );
  }
}
