import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/school.dart';
import '../models/display_settings.dart';
import '../models/active_timeline.dart';
import '../models/template.dart';
import '../models/task.dart';
import '../models/weekly_schedule.dart';
import '../models/theme_config.dart';
import '../data/defaults.dart';
import '../data/preset_themes.dart';
import '../utils/time_utils.dart';
import 'auth_provider.dart';
import 'membership_provider.dart';
import 'schedule_cache.dart';

final schoolProvider =
    AsyncNotifierProvider<SchoolNotifier, SchoolState?>(() => SchoolNotifier());

class SchoolState {
  final School school;
  final DisplaySettings displaySettings;
  final ActiveTimeline timeline;
  final List<TaskTemplate> templates;
  final WeeklySchedule weeklySchedule;
  final String currentTheme;
  final List<ThemeConfig> customThemes;
  final String? activeTemplateId;
  final bool hasUnsavedChanges;
  final bool isSaving;
  final bool isFreeMode;
  final bool isSessionOnlyMode;
  final bool isUsingCachedData;

  SchoolState({
    required this.school,
    this.displaySettings = const DisplaySettings(),
    required this.timeline,
    this.templates = const [],
    required this.weeklySchedule,
    this.currentTheme = 'routine-ready',
    this.customThemes = const [],
    this.activeTemplateId,
    this.hasUnsavedChanges = false,
    this.isSaving = false,
    this.isFreeMode = false,
    this.isSessionOnlyMode = false,
    this.isUsingCachedData = false,
  });

  SchoolState copyWith({
    School? school,
    DisplaySettings? displaySettings,
    ActiveTimeline? timeline,
    List<TaskTemplate>? templates,
    WeeklySchedule? weeklySchedule,
    String? currentTheme,
    List<ThemeConfig>? customThemes,
    String? activeTemplateId,
    bool? hasUnsavedChanges,
    bool? isSaving,
    bool? isFreeMode,
    bool? isSessionOnlyMode,
    bool? isUsingCachedData,
  }) {
    return SchoolState(
      school: school ?? this.school,
      displaySettings: displaySettings ?? this.displaySettings,
      timeline: timeline ?? this.timeline,
      templates: templates ?? this.templates,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      currentTheme: currentTheme ?? this.currentTheme,
      customThemes: customThemes ?? this.customThemes,
      activeTemplateId: activeTemplateId ?? this.activeTemplateId,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isSaving: isSaving ?? this.isSaving,
      isFreeMode: isFreeMode ?? this.isFreeMode,
      isSessionOnlyMode: isSessionOnlyMode ?? this.isSessionOnlyMode,
      isUsingCachedData: isUsingCachedData ?? this.isUsingCachedData,
    );
  }
}

class SchoolNotifier extends AsyncNotifier<SchoolState?> {
  SupabaseClient get _client => ref.read(supabaseClientProvider);

  // Debounce timers — prevents hammering Supabase on rapid changes (e.g. slider drags)
  Timer? _displaySettingsDebounce;
  Timer? _timelineDebounce;
  Timer? _customThemesDebounce;
  static const _debounceDelay = Duration(milliseconds: 800);

  @override
  Future<SchoolState?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    // Load cached display data first so the display has something to show immediately
    final cachedState = await _loadFromCache();
    if (cachedState != null) {
      state = AsyncData(cachedState);
    }

    try {
      // If a classroom is selected (org-based flow), load by classroom ID
      final selectedClassroom = ref.watch(selectedClassroomProvider);
      SchoolState? result;
      if (selectedClassroom != null) {
        result = await _loadByClassroomId(selectedClassroom.id);
      } else {
        // Legacy flow: load by owner_id (for users without org membership)
        result = await _loadAllData(user.id);
      }

      if (result != null) {
        // Cache display-critical data for offline resilience
        _cacheDisplayData(result);
        return result;
      }

      // Supabase returned null (no school found) — keep cache if available
      return cachedState;
    } catch (e) {
      // Supabase failed — fall back to cached data silently
      if (cachedState != null) return cachedState;
      rethrow;
    }
  }

  /// Build a minimal SchoolState from cached timeline + display settings.
  Future<SchoolState?> _loadFromCache() async {
    final timeline = await ScheduleCache.loadTimeline();
    if (timeline == null) return null;

    final dsData = await ScheduleCache.loadDisplaySettings();

    return SchoolState(
      school: School(
        id: 'cached',
        ownerId: '',
        schoolName: '',
        className: '',
        teacherName: '',
      ),
      timeline: timeline,
      displaySettings: dsData?.settings ?? const DisplaySettings(),
      currentTheme: dsData?.currentTheme ?? 'routine-ready',
      customThemes: dsData?.customThemes ?? const [],
      weeklySchedule: WeeklySchedule(),
      isUsingCachedData: true,
    );
  }

  /// Cache display-critical data (fire-and-forget).
  void _cacheDisplayData(SchoolState schoolState) {
    ScheduleCache.saveAll(
      schoolState.timeline,
      schoolState.displaySettings,
      schoolState.currentTheme,
      schoolState.customThemes,
    );
  }

  /// Re-fetch all data from Supabase (e.g. after realtime reconnection).
  Future<void> reload() async {
    final current = state.valueOrNull;
    if (current != null && current.isFreeMode) return; // Free mode: no DB to reload from

    try {
      final selectedClassroom = ref.read(selectedClassroomProvider);
      SchoolState? result;
      if (selectedClassroom != null) {
        result = await _loadByClassroomId(selectedClassroom.id);
      } else {
        final user = ref.read(currentUserProvider);
        if (user == null) return;
        result = await _loadAllData(user.id);
      }

      if (result != null) {
        _cacheDisplayData(result);
        state = AsyncData(result);
      }
    } catch (_) {
      // Reload failed (network down) — keep current state (may be cached)
    }
  }

  /// Enable session-only mode (staff/non-owner edits don't persist).
  void enableSessionOnlyMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(isSessionOnlyMode: true));
  }

  /// Initialize in-memory-only state for free tier users (no DB reads/writes).
  void initFreeMode() {
    if (state.valueOrNull != null) return; // Already initialized
    state = AsyncData(SchoolState(
      school: School(
        id: 'free-local',
        ownerId: '',
        schoolName: '',
        className: '',
        teacherName: '',
      ),
      timeline: defaultTimelineConfig,
      weeklySchedule: WeeklySchedule(),
      isFreeMode: true,
    ));
  }

  /// Load all data for a specific classroom (org-based flow).
  Future<SchoolState?> _loadByClassroomId(String classroomId) async {
    final schoolRes = await _client
        .from('schools')
        .select()
        .eq('id', classroomId)
        .limit(1)
        .maybeSingle();

    if (schoolRes == null) return null;

    final school = School.fromJson(schoolRes);
    return _loadSchoolData(school);
  }

  Future<SchoolState?> _loadAllData(String userId) async {
    // 1. Load school
    final schoolRes = await _client
        .from('schools')
        .select()
        .eq('owner_id', userId)
        .limit(1)
        .maybeSingle();

    if (schoolRes == null) return null;

    final school = School.fromJson(schoolRes);
    return _loadSchoolData(school);
  }

  Future<SchoolState?> _loadSchoolData(School school) async {
    // 2. Load display settings
    final dsRes = await _client
        .from('display_settings')
        .select()
        .eq('school_id', school.id)
        .limit(1)
        .maybeSingle();

    final displaySettings =
        dsRes != null ? DisplaySettings.fromDbJson(dsRes) : const DisplaySettings();
    final currentTheme =
        dsRes != null ? (dsRes['current_theme'] as String? ?? 'routine-ready') : 'routine-ready';

    // 3. Load templates with tasks
    final templatesRes = await _client
        .from('templates')
        .select()
        .eq('school_id', school.id)
        .order('created_at');

    final templates = <TaskTemplate>[];
    for (final t in (templatesRes as List)) {
      final tasksRes = await _client
          .from('tasks')
          .select()
          .eq('template_id', t['id'])
          .order('sort_order');

      templates.add(TaskTemplate(
        id: t['id'],
        name: t['name'] ?? 'Untitled',
        startTime: t['start_time'] ?? '08:00',
        endTime: t['end_time'] ?? '10:30',
        tasks: (tasksRes as List).map((task) => Task(
          id: task['id'],
          type: task['type'] ?? 'text',
          content: task['content'] ?? 'New Task',
          duration: task['duration'] ?? 30,
          imageUrl: task['image_url'],
          icon: task['icon'],
          width: task['width'] ?? 200,
          height: task['height'] ?? 160,
        )).toList(),
      ));
    }

    // 4. Load active timeline
    final atRes = await _client
        .from('active_timeline')
        .select()
        .eq('school_id', school.id)
        .limit(1)
        .maybeSingle();

    final timeline = atRes != null
        ? ActiveTimeline(
            startTime: atRes['start_time'] ?? '08:00',
            endTime: atRes['end_time'] ?? '10:30',
            tasks: ((atRes['tasks_json'] ?? []) as List)
                .map((t) => Task.fromJson(t as Map<String, dynamic>))
                .toList(),
          )
        : defaultTimelineConfig;

    final activeTemplateId = atRes?['template_id'] as String?;

    // 5. Load weekly schedule
    final wsRes = await _client
        .from('weekly_schedules')
        .select()
        .eq('school_id', school.id)
        .limit(1)
        .maybeSingle();

    final weeklySchedule =
        wsRes != null ? WeeklySchedule.fromJson(wsRes) : WeeklySchedule();

    // 6. Load custom themes
    final ctRes = await _client
        .from('custom_themes')
        .select()
        .eq('school_id', school.id)
        .order('created_at');

    final customThemes = (ctRes as List).map((t) {
      final base = presetThemes['routine-ready']!;
      return base.copyWith(
        id: t['id'],
        name: t['name'] ?? 'Custom Theme',
        emoji: t['emoji'] ?? '\u{1F3A8}',
        cardBgColor: t['card_bg'],
        cardBorderColor: t['card_border'],
        cardBorderWidth: t['card_border_width'],
        bgGradientFrom: t['page_bg'] ?? base.bgGradientFrom,
        bgGradientTo: t['page_gradient'] ?? base.bgGradientTo,
        fontFamily: t['font_family'] ?? 'sans-serif',
        tickPastColor: t['dot_completed'] ?? base.tickPastColor,
        tickCurrentColor: t['dot_current'] ?? base.tickCurrentColor,
        tickFutureColor: t['dot_upcoming'] ?? base.tickFutureColor,
      );
    }).toList();

    var result = SchoolState(
      school: school,
      displaySettings: displaySettings,
      timeline: timeline,
      templates: templates,
      weeklySchedule: weeklySchedule,
      currentTheme: currentTheme,
      customThemes: customThemes,
      activeTemplateId: activeTemplateId,
    );

    // Auto-load today's template from weekly schedule
    final todayKey = getDayKey(DateTime.now().weekday);
    final todayTemplateId =
        todayKey != null ? weeklySchedule.getForDay(todayKey) : null;
    if (todayTemplateId != null && todayTemplateId != activeTemplateId) {
      final todayTemplate = templates
          .where((t) => t.id.toString() == todayTemplateId)
          .firstOrNull;
      if (todayTemplate != null) {
        final autoTimeline = ActiveTimeline(
          startTime: todayTemplate.startTime,
          endTime: todayTemplate.endTime,
          tasks: todayTemplate.tasks
              .map((t) => Task.fromJson(t.toJson()))
              .toList(),
        );
        result = result.copyWith(
          timeline: autoTimeline,
          activeTemplateId: todayTemplateId,
        );
        // Persist the auto-loaded timeline
        _autoSaveTimeline(school.id, autoTimeline, todayTemplateId);
      }
    }

    return result;
  }

  Future<void> _autoSaveTimeline(
      String schoolId, ActiveTimeline timeline, String? templateId) async {
    final payload = {
      'school_id': schoolId,
      'template_id': templateId,
      'start_time': timeline.startTime,
      'end_time': timeline.endTime,
      'tasks_json': timeline.tasks.map((t) => t.toJson()).toList(),
    };

    final existing = await _client
        .from('active_timeline')
        .select('id')
        .eq('school_id', schoolId)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('active_timeline')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('active_timeline').insert(payload);
    }
  }

  Future<void> createSchool({
    required String userId,
    required String schoolName,
    required String className,
    required String teacherName,
    String deviceName = 'Display 1',
  }) async {
    final res = await _client
        .from('schools')
        .insert({
          'owner_id': userId,
          'school_name': schoolName,
          'class_name': className,
          'teacher_name': teacherName,
          'device_name': deviceName,
        })
        .select()
        .single();

    final school = School.fromJson(res);

    // Create default display settings
    await _client.from('display_settings').insert({
      'school_id': school.id,
      'current_theme': 'routine-ready',
    });

    // Create default template with tasks
    final templateRes = await _client
        .from('templates')
        .insert({
          'school_id': school.id,
          'name': 'Template 1',
          'start_time': '08:00',
          'end_time': '10:30',
        })
        .select()
        .single();

    await _client.from('tasks').insert(
      defaultTasks
          .asMap()
          .entries
          .map((e) => {
                'template_id': templateRes['id'],
                'sort_order': e.key,
                'type': e.value.type,
                'content': e.value.content,
                'duration': e.value.duration,
                'width': e.value.width,
                'height': e.value.height,
              })
          .toList(),
    );

    // Create active timeline
    await _client.from('active_timeline').insert({
      'school_id': school.id,
      'start_time': '08:00',
      'end_time': '10:30',
      'tasks_json': defaultTasks.map((t) => t.toJson()).toList(),
    });

    // Create weekly schedule
    await _client.from('weekly_schedules').insert({
      'school_id': school.id,
    });

    ref.invalidateSelf();
  }

  void updateTimeline(ActiveTimeline timeline) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      timeline: timeline,
      hasUnsavedChanges: true,
      isUsingCachedData: false,
    ));
    ScheduleCache.saveTimeline(timeline);
    _timelineDebounce?.cancel();
    _timelineDebounce = Timer(_debounceDelay, () {
      _saveTimelineToDb(timeline, current.activeTemplateId);
    });
  }

  /// Updates display settings in memory (drives the live admin preview) and the
  /// local cache for offline display. Does NOT write to the database — DB
  /// persistence is explicit via [saveDisplaySettingsNow] (the dialog's Save
  /// button) or [saveAll] (the global "Save Changes" button).
  void updateDisplaySettings(DisplaySettings settings) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      displaySettings: settings,
      isUsingCachedData: false,
    ));
    ScheduleCache.saveDisplaySettings(settings, current.currentTheme, current.customThemes);
  }

  /// Persists the current display settings to the database immediately.
  /// Throws if saving is unavailable (free plan / staff session) or if the
  /// write fails, so callers can surface the outcome to the user.
  Future<void> saveDisplaySettingsNow() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.isFreeMode) {
      throw StateError('Saving is unavailable on the free plan.');
    }
    if (current.isSessionOnlyMode) {
      throw StateError("Staff sessions don't save changes.");
    }
    _displaySettingsDebounce?.cancel();
    await _saveDisplaySettingsToDb(current.displaySettings, current.currentTheme);
  }

  void updateCurrentTheme(String themeId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      currentTheme: themeId,
      isUsingCachedData: false,
    ));
    ScheduleCache.saveDisplaySettings(current.displaySettings, themeId, current.customThemes);
    _displaySettingsDebounce?.cancel();
    _displaySettingsDebounce = Timer(_debounceDelay, () {
      _saveDisplaySettingsToDb(current.displaySettings, themeId);
    });
  }

  void updateTemplates(List<TaskTemplate> templates) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      templates: templates,
      hasUnsavedChanges: true,
    ));
  }

  void updateWeeklySchedule(WeeklySchedule schedule) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      weeklySchedule: schedule,
      hasUnsavedChanges: true,
    ));
  }

  void updateCustomThemes(List<ThemeConfig> themes) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(customThemes: themes));
    _customThemesDebounce?.cancel();
    _customThemesDebounce = Timer(_debounceDelay, () {
      _saveCustomThemesToDb(themes);
    });
  }

  void setActiveTemplateId(String? id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(activeTemplateId: id));
  }

  Future<void> saveAll() async {
    // Cancel any pending debounced saves — we're saving everything now
    _displaySettingsDebounce?.cancel();
    _timelineDebounce?.cancel();
    _customThemesDebounce?.cancel();

    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final idMap = await _saveTemplatesToDb(current.templates);

      final remappedTemplates = current.templates
          .map((t) => t.copyWith(id: idMap[t.id.toString()] ?? t.id))
          .toList();

      final remappedSchedule = current.weeklySchedule.remapIds(idMap);

      final newActiveId = current.activeTemplateId != null &&
              idMap.containsKey(current.activeTemplateId!)
          ? idMap[current.activeTemplateId!]
          : current.activeTemplateId;

      await Future.wait([
        _saveWeeklyScheduleToDb(remappedSchedule),
        _saveTimelineConfigToDb(current.timeline, newActiveId),
        // Also persist display settings + custom themes here: their debounces
        // were cancelled above, so without these their pending changes would be
        // dropped when the user clicks "Save Changes".
        _saveDisplaySettingsToDb(current.displaySettings, current.currentTheme),
        _saveCustomThemesToDb(current.customThemes),
      ]);

      state = AsyncData(current.copyWith(
        templates: remappedTemplates,
        weeklySchedule: remappedSchedule,
        activeTemplateId: newActiveId,
        hasUnsavedChanges: false,
        isSaving: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> updateSchoolInfo({
    required String schoolName,
    required String className,
    required String teacherName,
    String? deviceName,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _client.from('schools').update({
      'school_name': schoolName,
      'class_name': className,
      'teacher_name': teacherName,
      if (deviceName != null) 'device_name': deviceName, // ignore: use_null_aware_elements
    }).eq('id', current.school.id);

    state = AsyncData(current.copyWith(
      school: current.school.copyWith(
        schoolName: schoolName,
        className: className,
        teacherName: teacherName,
        deviceName: deviceName,
      ),
    ));
  }

  Future<void> resetAll() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _client.from('schools').delete().eq('id', current.school.id);
    ref.invalidateSelf();
  }

  Map<String, dynamic> exportBackup() {
    final current = state.valueOrNull;
    if (current == null) return {};

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'school': current.school.toJson(),
      'displaySettings': current.displaySettings.toDbJson(),
      'currentTheme': current.currentTheme,
      'timeline': current.timeline.toJson(),
      'templates': current.templates.map((t) => t.toJson()).toList(),
      'weeklySchedule': current.weeklySchedule.toJson(),
      'customThemes': current.customThemes.map((t) => t.toJson()).toList(),
    };
  }

  Future<void> importBackup(Map<String, dynamic> data) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final timeline = ActiveTimeline.fromJson(
        data['timeline'] as Map<String, dynamic>? ?? {});
    final displaySettings = DisplaySettings.fromDbJson(
        data['displaySettings'] as Map<String, dynamic>? ?? {});
    final currentTheme = data['currentTheme'] as String? ?? 'routine-ready';
    final templates = ((data['templates'] as List?) ?? [])
        .map((t) => TaskTemplate.fromJson(t as Map<String, dynamic>))
        .toList();
    final weeklySchedule = WeeklySchedule.fromJson(
        data['weeklySchedule'] as Map<String, dynamic>? ?? {});
    final customThemes = ((data['customThemes'] as List?) ?? [])
        .map((t) => ThemeConfig.fromJson(t as Map<String, dynamic>))
        .toList();

    state = AsyncData(current.copyWith(
      timeline: timeline,
      displaySettings: displaySettings,
      currentTheme: currentTheme,
      templates: templates,
      weeklySchedule: weeklySchedule,
      customThemes: customThemes,
      hasUnsavedChanges: true,
    ));

    // Persist everything
    await Future.wait([
      _saveDisplaySettingsToDb(displaySettings, currentTheme),
      _saveTimelineToDb(timeline, null),
      _saveCustomThemesToDb(customThemes),
    ]);
    final idMap = await _saveTemplatesToDb(templates);
    final remappedSchedule = weeklySchedule.remapIds(idMap);
    await _saveWeeklyScheduleToDb(remappedSchedule);

    state = AsyncData(current.copyWith(
      timeline: timeline,
      displaySettings: displaySettings,
      currentTheme: currentTheme,
      templates: templates,
      weeklySchedule: remappedSchedule,
      customThemes: customThemes,
      hasUnsavedChanges: false,
    ));
  }

  // --- Private DB helpers ---

  /// Returns true if DB writes should be skipped (free tier).
  bool get _skipDbWrites =>
      (state.valueOrNull?.isFreeMode ?? false) ||
      (state.valueOrNull?.isSessionOnlyMode ?? false);

  Future<void> _saveDisplaySettingsToDb(
      DisplaySettings settings, String theme) async {
    if (_skipDbWrites) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final payload = {
      ...settings.toDbJson(),
      'school_id': current.school.id,
      'current_theme': theme,
    };

    final existing = await _client
        .from('display_settings')
        .select('id')
        .eq('school_id', current.school.id)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('display_settings')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('display_settings').insert(payload);
    }
  }

  Future<void> _saveTimelineToDb(
      ActiveTimeline timeline, String? templateId) async {
    if (_skipDbWrites) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final payload = {
      'school_id': current.school.id,
      'template_id': templateId,
      'start_time': timeline.startTime,
      'end_time': timeline.endTime,
      'tasks_json': timeline.tasks.map((t) => t.toJson()).toList(),
    };

    final existing = await _client
        .from('active_timeline')
        .select('id')
        .eq('school_id', current.school.id)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('active_timeline')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('active_timeline').insert(payload);
    }
  }

  Future<void> _saveTimelineConfigToDb(
      ActiveTimeline timeline, String? templateId) async {
    await _saveTimelineToDb(timeline, templateId);
  }

  Future<Map<String, String>> _saveTemplatesToDb(
      List<TaskTemplate> allTemplates) async {
    if (_skipDbWrites) return {};
    final current = state.valueOrNull;
    if (current == null) return {};

    await _client.from('templates').delete().eq('school_id', current.school.id);

    final idMap = <String, String>{};

    for (final t in allTemplates) {
      final res = await _client
          .from('templates')
          .insert({
            'school_id': current.school.id,
            'name': t.name,
            'start_time': t.startTime,
            'end_time': t.endTime,
          })
          .select()
          .single();

      idMap[t.id.toString()] = res['id'];

      if (t.tasks.isNotEmpty) {
        await _client.from('tasks').insert(
          t.tasks.asMap().entries.map((e) {
            return {
              'template_id': res['id'],
              'sort_order': e.key,
              'type': e.value.type,
              'content': e.value.content,
              'duration': e.value.duration,
              'image_url': e.value.imageUrl,
              'icon': e.value.icon,
              'width': e.value.width,
              'height': e.value.height,
            };
          }).toList(),
        );
      }
    }

    return idMap;
  }

  Future<void> _saveWeeklyScheduleToDb(WeeklySchedule schedule) async {
    if (_skipDbWrites) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final payload = {
      'school_id': current.school.id,
      ...schedule.toJson(),
    };

    final existing = await _client
        .from('weekly_schedules')
        .select('id')
        .eq('school_id', current.school.id)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('weekly_schedules')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('weekly_schedules').insert(payload);
    }
  }

  Future<void> _saveCustomThemesToDb(List<ThemeConfig> themes) async {
    if (_skipDbWrites) return;
    final current = state.valueOrNull;
    if (current == null) return;

    await _client
        .from('custom_themes')
        .delete()
        .eq('school_id', current.school.id);

    for (final theme in themes) {
      await _client.from('custom_themes').insert({
        'id': theme.id,
        'school_id': current.school.id,
        'name': theme.name,
        'card_bg': theme.cardBgColor,
        'card_border': theme.cardBorderColor,
        'card_border_width': theme.cardBorderWidth,
        'page_bg': theme.bgGradientFrom,
        'page_gradient': theme.bgGradientTo,
        'font_family': theme.fontFamily,
        'dot_completed': theme.tickPastColor,
        'dot_current': theme.tickCurrentColor,
        'dot_upcoming': theme.tickFutureColor,
        'emoji': theme.emoji,
      });
    }
  }
}
