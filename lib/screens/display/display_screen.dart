import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/active_timeline.dart';
import '../../models/display_settings.dart';
import '../../models/theme_config.dart';
import '../../providers/school_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/session_provider.dart';
import '../../utils/theme_utils.dart';
import '../../utils/time_utils.dart';
import 'horizontal_display.dart';
import 'multi_row_display.dart';
import 'auto_pan_display.dart';

class DisplayScreen extends ConsumerStatefulWidget {
  const DisplayScreen({super.key});

  @override
  ConsumerState<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends ConsumerState<DisplayScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _currentTaskIndex = -1;
  double _elapsedInTask = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Kiosk: immersive mode + landscape lock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Web fullscreen hint
    if (kIsWeb) {
      // Chromium --kiosk handles this; no extra action needed
    }

    // Subscribe to realtime only if real data is already loaded.
    // If only cached data is available yet, the ref.listen in build() will
    // subscribe once the Supabase load completes and replaces the cache.
    final schoolState = ref.read(schoolProvider).valueOrNull;
    if (schoolState != null && !schoolState.isUsingCachedData) {
      ref.read(realtimeProvider).subscribe(schoolState.school.id);
    }

    // Update progress every 500ms for smooth animations
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _updateProgress(),
    );
    _updateProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    ref.read(realtimeProvider).unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final schoolState = ref.read(schoolProvider).valueOrNull;
      if (schoolState != null && !schoolState.isUsingCachedData) {
        ref.read(realtimeProvider).subscribe(schoolState.school.id);
      }
      _updateProgress();
    }
  }

  void _updateProgress() {
    final schoolState = ref.read(schoolProvider).valueOrNull;
    if (schoolState == null) return;

    final progress = getCurrentTaskProgress(
      DateTime.now(),
      schoolState.timeline.startTime,
      schoolState.timeline.tasks,
    );

    if (mounted) {
      setState(() {
        _currentTaskIndex = progress.currentTaskIndex;
        _elapsedInTask = progress.elapsedInTask;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to realtime as soon as real data replaces the startup cache,
    // or whenever the active classroom changes (e.g. staff switching rooms).
    ref.listen<AsyncValue<SchoolState?>>(schoolProvider, (previous, next) {
      final prev = previous?.valueOrNull;
      final curr = next.valueOrNull;
      if (curr == null || curr.isUsingCachedData) return;
      final prevId = (prev != null && !prev.isUsingCachedData) ? prev.school.id : null;
      if (curr.school.id != prevId) {
        ref.read(realtimeProvider).subscribe(curr.school.id);
      }
    });

    final schoolState = ref.watch(schoolProvider).valueOrNull;
    if (schoolState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final timeline = schoolState.timeline;
    final settings = schoolState.displaySettings;
    final theme = getActiveTheme(
      schoolState.currentTheme,
      schoolState.customThemes,
    );
    final scaleFactor = settings.scale / 100;
    final screenSize = MediaQuery.of(context).size;

    // Calculate scale to fit the virtual resolution into the physical screen
    final fitScaleX = screenSize.width / (settings.width * scaleFactor);
    final fitScaleY = screenSize.height / (settings.height * scaleFactor);
    final fitScale = fitScaleX < fitScaleY ? fitScaleX : fitScaleY;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen background
          Container(
            decoration: BoxDecoration(gradient: getBackgroundGradient(theme)),
          ),
          // Scaled display container, centred in the viewport. The virtual
          // canvas (settings.width × settings.height) is scaled to fit and
          // centred via a Center + sized FittedBox, so any leftover space is
          // split evenly instead of pooling at the bottom (which it did when the
          // canvas was anchored top-left).
          Center(
            child: SizedBox(
              width: settings.width * fitScale * scaleFactor,
              height: settings.height * fitScale * scaleFactor,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: settings.width.toDouble(),
                  height: settings.height.toDouble(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: getBackgroundGradient(theme),
                    ),
                    child: _buildDisplayMode(timeline, settings, theme),
                  ),
                ),
              ),
            ),
          ),
          // Subtle offline indicator — small grey dot in bottom-left corner,
          // visible to teachers but not distracting to children
          if (_isOffline(schoolState))
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          // Admin button overlay
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _exitToModeSelect,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\u2699\uFE0F', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Select display mode: use saved setting, or auto-detect from aspect ratio.
  String _resolveDisplayMode(DisplaySettings settings) {
    final mode = settings.mode;
    if (mode != 'auto') return mode;

    // Auto-detect based on screen aspect ratio
    final size = MediaQuery.of(context).size;
    final aspectRatio = size.width / size.height;

    if (aspectRatio > 2.5) {
      return 'horizontal'; // Ultra-wide panels
    } else if (aspectRatio < 2.0) {
      return 'multi-row'; // Standard screens / tablets
    } else {
      return 'horizontal'; // In-between — horizontal still works well
    }
  }

  Widget _buildDisplayMode(
    ActiveTimeline timeline,
    DisplaySettings settings,
    ThemeConfig theme,
  ) {
    final mode = _resolveDisplayMode(settings);
    switch (mode) {
      case 'horizontal':
        return HorizontalDisplay(
          timeline: timeline,
          displaySettings: settings,
          theme: theme,
          currentTaskIndex: _currentTaskIndex,
          elapsedInTask: _elapsedInTask,
        );
      case 'multi-row':
        return MultiRowDisplay(
          timeline: timeline,
          displaySettings: settings,
          theme: theme,
          currentTaskIndex: _currentTaskIndex,
          elapsedInTask: _elapsedInTask,
        );
      case 'auto-pan':
      default:
        return AutoPanDisplay(
          timeline: timeline,
          displaySettings: settings,
          theme: theme,
          currentTaskIndex: _currentTaskIndex,
          elapsedInTask: _elapsedInTask,
        );
    }
  }

  bool _isOffline(SchoolState schoolState) {
    return schoolState.isUsingCachedData;
  }

  void _exitToModeSelect() {
    ref.read(sessionModeProvider.notifier).state = null;
  }
}
