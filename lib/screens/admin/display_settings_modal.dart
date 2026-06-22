import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme_constants.dart';
import '../../data/transition_presets.dart';
import '../../models/display_settings.dart';
import '../../providers/school_provider.dart';

class DisplaySettingsModal extends ConsumerStatefulWidget {
  const DisplaySettingsModal({super.key});

  @override
  ConsumerState<DisplaySettingsModal> createState() =>
      _DisplaySettingsModalState();
}

class _DisplaySettingsModalState extends ConsumerState<DisplaySettingsModal> {
  late DisplaySettings _settings;

  @override
  void initState() {
    super.initState();
    _settings =
        ref.read(schoolProvider).valueOrNull?.displaySettings ??
            const DisplaySettings();
  }

  void _update(DisplaySettings s) {
    setState(() => _settings = s);
    // Auto-saves (debounced): classroom-wide fields (mode/transition/size) to the
    // school; everything else to the active template + the live snapshot.
    ref.read(schoolProvider.notifier).updateDisplaySettings(s);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Display Settings',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display mode
                      const Text('Display Mode',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'horizontal',
                              label: Text('Horizontal')),
                          ButtonSegment(
                              value: 'multi-row',
                              label: Text('Multi-Row')),
                          ButtonSegment(
                              value: 'auto-pan',
                              label: Text('Auto-Pan')),
                        ],
                        selected: {_settings.mode},
                        onSelectionChanged: (v) =>
                            _update(_settings.copyWith(mode: v.first)),
                      ),
                      const SizedBox(height: 16),

                      if (_settings.mode == 'multi-row') ...[
                        Text('Rows: ${_settings.rows}'),
                        Slider(
                          value: _settings.rows.toDouble(),
                          min: 1,
                          max: (_settings.height / 250).floor().clamp(1, 6).toDouble(),
                          divisions: ((_settings.height / 250).floor().clamp(1, 6) - 1).clamp(1, 5),
                          onChanged: (v) =>
                              _update(_settings.copyWith(rows: v.round())),
                        ),
                        const SizedBox(height: 8),
                        const Text('Path Direction',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'sequential',
                                label: Text('Sequential')),
                            ButtonSegment(
                                value: 'snake',
                                label: Text('Snake')),
                          ],
                          selected: {_settings.pathDirection},
                          onSelectionChanged: (v) =>
                              _update(_settings.copyWith(
                                  pathDirection: v.first)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _settings.pathDirection == 'snake'
                                ? 'Rows alternate: left→right, right→left'
                                : 'All rows flow left→right',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.brandTextMuted),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Transition type
                      const Text('Transition Type',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'progress-line',
                              label: Text('Progress Line')),
                          ButtonSegment(
                              value: 'mascot',
                              label: Text('Mascot Road')),
                        ],
                        selected: {_settings.transitionType},
                        onSelectionChanged: (v) =>
                            _update(_settings.copyWith(
                                transitionType: v.first)),
                      ),
                      const SizedBox(height: 16),

                      if (_settings.transitionType == 'mascot') ...[
                        // Sprite picker
                        const Text('Sprite',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: spritePresets.map((s) {
                            final isSelected =
                                _settings.selectedSprite == s.id;
                            return GestureDetector(
                              onTap: () => _update(_settings.copyWith(
                                  selectedSprite: s.id)),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.brandPrimary
                                        : AppColors.brandBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isSelected
                                      ? AppColors.brandPrimaryBg
                                      : Colors.white,
                                ),
                                child: Center(
                                    child: Text(s.emoji,
                                        style: const TextStyle(
                                            fontSize: 24))),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Surface picker
                        const Text('Surface',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: surfacePresets.map((s) {
                            final isSelected =
                                _settings.selectedSurface == s.id;
                            return GestureDetector(
                              onTap: () => _update(_settings.copyWith(
                                  selectedSurface: s.id)),
                              child: Container(
                                width: 80,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: s.gradientColors),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.brandPrimary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Text(
                                    s.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: s.id == 'tarmac'
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        Text('Road Height: ${_settings.roadHeight}px'),
                        Slider(
                          value: _settings.roadHeight.toDouble(),
                          min: 16,
                          max: 64,
                          divisions: 12,
                          onChanged: (v) => _update(
                              _settings.copyWith(roadHeight: v.round())),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Resolution
                      const Text('Resolution',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _resolutionButton(2560, 1080, 'Ultra-wide'),
                                _resolutionButton(1920, 1080, 'Full HD'),
                                _resolutionButton(1280, 720, 'HD'),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('or custom',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.brandTextMuted)),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Width',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 10),
                                        ),
                                        keyboardType: TextInputType.number,
                                        controller: TextEditingController(
                                            text: '${_settings.width}'),
                                        onSubmitted: (v) {
                                          final w = int.tryParse(v);
                                          if (w != null && w > 0) {
                                            _update(_settings.copyWith(width: w));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 20),
                                    child: Text('x'),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Height',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 10),
                                        ),
                                        keyboardType: TextInputType.number,
                                        controller: TextEditingController(
                                            text: '${_settings.height}'),
                                        onSubmitted: (v) {
                                          final h = int.tryParse(v);
                                          if (h != null && h > 0) {
                                            _update(_settings.copyWith(height: h));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final view = ui.PlatformDispatcher.instance.implicitView;
                                  if (view != null) {
                                    final pixelWidth = view.physicalSize.width.round();
                                    final pixelHeight = view.physicalSize.height.round();
                                    _update(_settings.copyWith(
                                      width: pixelWidth,
                                      height: pixelHeight,
                                    ));
                                  }
                                },
                                icon: const Icon(Icons.screen_search_desktop_outlined, size: 18),
                                label: const Text('Detect screen size'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Scale
                      Text('Scale: ${_settings.scale}%'),
                      Slider(
                        value: _settings.scale.toDouble(),
                        min: 25,
                        max: 200,
                        divisions: 35,
                        onChanged: (v) =>
                            _update(_settings.copyWith(scale: v.round())),
                      ),
                      const SizedBox(height: 16),

                      // Auto-pan tile height + road width
                      if (_settings.mode == 'auto-pan') ...[
                        Text(
                            'Task Tile Height: ${_settings.autoPanTileHeight}%'),
                        Slider(
                          value: _settings.autoPanTileHeight.toDouble(),
                          min: 30,
                          max: 90,
                          divisions: 12,
                          onChanged: (v) => _update(_settings.copyWith(
                              autoPanTileHeight: v.round())),
                        ),
                        const SizedBox(height: 16),
                        Text('Road Width: ${_settings.autoPanRoadWidth}%'),
                        Slider(
                          value: _settings.autoPanRoadWidth.toDouble(),
                          min: 20,
                          max: 90,
                          divisions: 14,
                          onChanged: (v) => _update(_settings.copyWith(
                              autoPanRoadWidth: v.round())),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Clock toggle
                      SwitchListTile(
                        title: const Text('Show Live Clock'),
                        value: _settings.showClock,
                        onChanged: (v) =>
                            _update(_settings.copyWith(showClock: v)),
                      ),

                      // Banner heights
                      Text(
                          'Top Banner Height: ${_settings.topBannerHeight}px'),
                      Slider(
                        value: _settings.topBannerHeight.toDouble(),
                        min: 24,
                        max: 120,
                        divisions: 24,
                        onChanged: (v) => _update(
                            _settings.copyWith(topBannerHeight: v.round())),
                      ),
                      Text(
                          'Bottom Banner Height: ${_settings.bottomBannerHeight}px'),
                      Slider(
                        value: _settings.bottomBannerHeight.toDouble(),
                        min: 24,
                        max: 120,
                        divisions: 24,
                        onChanged: (v) => _update(_settings.copyWith(
                            bottomBannerHeight: v.round())),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Auto-optimise toggle
                      SwitchListTile(
                        title: const Text('Auto-optimise layout'),
                        subtitle: const Text(
                          'Recommend the best display mode and rows for your tasks',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _settings.autoOptimise,
                        onChanged: (v) =>
                            _update(_settings.copyWith(autoOptimise: v)),
                      ),

                      // Recommendation banner
                      if (_settings.autoOptimise)
                        Builder(builder: (context) {
                          final taskCount = ref.watch(schoolProvider).valueOrNull?.timeline.tasks.length ?? 0;
                          final rec = _getLayoutRecommendation(
                            taskCount,
                            _settings.width,
                            _settings.height,
                            _settings.mode,
                          );
                          if (rec == null) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimaryBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lightbulb_outline,
                                    color: AppColors.brandPrimary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rec.message,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _update(rec.applyTo(_settings)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              _buildSaveFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveFooter() {
    final schoolState = ref.watch(schoolProvider).valueOrNull;
    final freeMode = schoolState?.isFreeMode ?? false;
    final sessionMode = schoolState?.isSessionOnlyMode ?? false;

    if (freeMode || sessionMode) {
      return Row(
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppColors.brandTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              freeMode
                  ? 'Saving is unavailable on the free plan.'
                  : "Staff sessions don't save changes.",
              style: const TextStyle(
                  fontSize: 12, color: AppColors.brandTextMuted),
            ),
          ),
        ],
      );
    }

    return const Row(
      children: [
        Icon(Icons.cloud_done_outlined,
            size: 16, color: AppColors.brandTextMuted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Changes save automatically. Mode, transition style and screen size '
            'apply to the whole classroom; everything else is saved to the '
            'current template.',
            style:
                TextStyle(fontSize: 12, color: AppColors.brandTextMuted),
          ),
        ),
      ],
    );
  }

  Widget _resolutionButton(int w, int h, String label) {
    final isSelected = _settings.width == w && _settings.height == h;
    return OutlinedButton(
      onPressed: () => _update(_settings.copyWith(width: w, height: h)),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            isSelected ? AppColors.brandPrimaryBg : Colors.white,
        side: BorderSide(
          color:
              isSelected ? AppColors.brandPrimary : AppColors.brandBorder,
        ),
      ),
      child: Text('$label\n${w}x$h',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11)),
    );
  }

  _LayoutRecommendation? _getLayoutRecommendation(
    int taskCount,
    int displayWidth,
    int displayHeight,
    String currentMode,
  ) {
    if (taskCount == 0) return null;

    const estimatedCardWidth = 200;
    const estimatedTransitionWidth = 120;
    final slotWidth = estimatedCardWidth + estimatedTransitionWidth;
    final maxCardsPerRow = (displayWidth / slotWidth).floor().clamp(1, 100);

    if (currentMode == 'horizontal' && taskCount > maxCardsPerRow) {
      final optimalRows = (taskCount / maxCardsPerRow).ceil().clamp(1, 6);
      return _LayoutRecommendation(
        message:
            'For $taskCount tasks on ${displayWidth}x$displayHeight, we recommend: Multi-Row, $optimalRows rows',
        mode: 'multi-row',
        rows: optimalRows,
      );
    }

    if (currentMode == 'multi-row') {
      final optimalRows = (taskCount / maxCardsPerRow).ceil().clamp(1, 6);
      final maxRowsFit = (displayHeight / 250).floor().clamp(1, 6);
      if (optimalRows > maxRowsFit) {
        return _LayoutRecommendation(
          message:
              'Too many tasks for multi-row at this resolution. We recommend: Auto-Pan mode',
          mode: 'auto-pan',
          rows: 1,
        );
      }
      if (_settings.rows != optimalRows) {
        return _LayoutRecommendation(
          message:
              'For $taskCount tasks on ${displayWidth}x$displayHeight, we recommend: $optimalRows rows',
          mode: 'multi-row',
          rows: optimalRows,
        );
      }
    }

    return null;
  }
}

class _LayoutRecommendation {
  final String message;
  final String mode;
  final int rows;

  const _LayoutRecommendation({
    required this.message,
    required this.mode,
    required this.rows,
  });

  DisplaySettings applyTo(DisplaySettings settings) {
    return settings.copyWith(mode: mode, rows: rows);
  }
}
