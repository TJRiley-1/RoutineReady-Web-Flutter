class Task {
  final dynamic id;
  final String type;
  final String content;
  final int duration;
  final String? imageUrl;
  final String? icon;
  final int width;
  final int height;

  /// Multi-row mode: force a new row to start after this task, regardless of the
  /// road width. Lets the user compose rows manually (e.g. 3 on top, 4 below).
  final bool breakAfter;

  Task({
    required this.id,
    this.type = 'text',
    this.content = 'New Task',
    this.duration = 30,
    this.imageUrl,
    this.icon,
    this.width = 200,
    this.height = 160,
    this.breakAfter = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? 'New Task',
      duration: json['duration'] as int? ?? 30,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      icon: json['icon'] as String?,
      width: json['width'] as int? ?? 200,
      height: json['height'] as int? ?? 160,
      breakAfter:
          json['breakAfter'] as bool? ?? json['break_after'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
        'duration': duration,
        'imageUrl': imageUrl,
        'icon': icon,
        'width': width,
        'height': height,
        'breakAfter': breakAfter,
      };

  Task copyWith({
    dynamic id,
    String? type,
    String? content,
    int? duration,
    String? imageUrl,
    bool clearImageUrl = false,
    String? icon,
    int? width,
    int? height,
    bool? breakAfter,
  }) {
    return Task(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      duration: duration ?? this.duration,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      icon: icon ?? this.icon,
      width: width ?? this.width,
      height: height ?? this.height,
      breakAfter: breakAfter ?? this.breakAfter,
    );
  }
}
