import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme_constants.dart';
import '../../data/preset_themes.dart';
import '../../models/theme_config.dart';
import '../../providers/school_provider.dart';
import '../../utils/theme_utils.dart';

class ThemeEditorModal extends ConsumerStatefulWidget {
  final ThemeConfig? editingTheme;
  final VoidCallback onBack;

  const ThemeEditorModal({
    super.key,
    this.editingTheme,
    required this.onBack,
  });

  @override
  ConsumerState<ThemeEditorModal> createState() => _ThemeEditorModalState();
}

class _ThemeEditorModalState extends ConsumerState<ThemeEditorModal> {
  late ThemeConfig _theme;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _theme = widget.editingTheme ??
        presetThemes['routine-ready']!.copyWith(
          id: const Uuid().v4(),
          name: 'Custom Theme',
          emoji: '\u{1F3A8}',
        );
    _nameController = TextEditingController(text: _theme.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final schoolState = ref.read(schoolProvider).valueOrNull;
    if (schoolState == null) return;

    final updatedTheme = _theme.copyWith(name: _nameController.text);

    final existingIndex =
        schoolState.customThemes.indexWhere((t) => t.id == updatedTheme.id);
    final updatedThemes = [...schoolState.customThemes];

    if (existingIndex >= 0) {
      updatedThemes[existingIndex] = updatedTheme;
    } else {
      updatedThemes.add(updatedTheme);
    }

    ref.read(schoolProvider.notifier).updateCustomThemes(updatedThemes);
    ref.read(schoolProvider.notifier).updateCurrentTheme(updatedTheme.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onBack();
                        },
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Theme Editor',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Theme'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    // Controls
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                  labelText: 'Theme Name'),
                            ),
                            const SizedBox(height: 16),

                            // Start from preset
                            const Text('Start from preset:',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children:
                                  presetThemes.entries.map((entry) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _theme = entry.value.copyWith(
                                        id: _theme.id,
                                        name: _nameController.text,
                                      );
                                    });
                                  },
                                  child: Chip(
                                    label: Text(
                                      '${entry.value.emoji} ${entry.value.name}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            _ColorPicker(
                              label: 'Background Top',
                              currentColor: _theme.bgGradientFrom,
                              onChanged: (c) => setState(
                                  () => _theme = _theme.copyWith(
                                      bgGradientFrom: c)),
                            ),
                            _ColorPicker(
                              label: 'Background Bottom',
                              currentColor: _theme.bgGradientTo,
                              onChanged: (c) => setState(
                                  () => _theme = _theme.copyWith(
                                      bgGradientTo: c)),
                            ),
                            _ColorPicker(
                              label: 'Card Border',
                              currentColor: _theme.cardBorderColor,
                              onChanged: (c) => setState(
                                  () => _theme = _theme.copyWith(
                                      cardBorderColor: c)),
                            ),
                            _ColorPicker(
                              label: 'Card Background',
                              currentColor: _theme.cardBgColor,
                              onChanged: (c) => setState(
                                  () => _theme = _theme.copyWith(
                                      cardBgColor: c)),
                            ),
                            _ColorPicker(
                              label: 'Glow Color',
                              currentColor: _theme.currentGlowColor,
                              onChanged: (c) => setState(
                                  () => _theme = _theme.copyWith(
                                      currentGlowColor: c)),
                            ),
                            _ColorPicker(
                              label: 'Accent Color',
                              currentColor: _theme.timeCardAccentColor,
                              onChanged: (c) => setState(
                                  () => _theme = _theme.copyWith(
                                      timeCardAccentColor: c)),
                            ),

                            const SizedBox(height: 16),
                            // Corner style
                            const Text('Corner Style',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            DropdownButton<String>(
                              value: _theme.cardRounded,
                              items: const [
                                DropdownMenuItem(
                                    value: 'rounded-sm',
                                    child: Text('Sharp')),
                                DropdownMenuItem(
                                    value: 'rounded-md',
                                    child: Text('Medium')),
                                DropdownMenuItem(
                                    value: 'rounded-lg',
                                    child: Text('Large')),
                                DropdownMenuItem(
                                    value: 'rounded-xl',
                                    child: Text('Extra Large')),
                                DropdownMenuItem(
                                    value: 'rounded-2xl',
                                    child: Text('Round')),
                                DropdownMenuItem(
                                    value: 'rounded-3xl',
                                    child: Text('Very Round')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _theme =
                                      _theme.copyWith(cardRounded: v));
                                }
                              },
                            ),

                            const SizedBox(height: 16),
                            // Border width
                            const Text('Border Width',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _theme.borderWidthValue,
                                    min: 1,
                                    max: 6,
                                    divisions: 5,
                                    onChanged: (v) => setState(() =>
                                        _theme = _theme.copyWith(
                                            cardBorderWidth:
                                                '${v.round()}px')),
                                  ),
                                ),
                                Text('${_theme.borderWidthValue.round()}px',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),

                            const SizedBox(height: 16),
                            // Font family
                            const Text('Font Style',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            DropdownButton<String>(
                              value: _theme.fontFamily,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: 'sans-serif',
                                    child: Text('System Default')),
                                DropdownMenuItem(
                                    value: 'twinkl-cursive-looped',
                                    child: Text('Twinkl Cursive Looped')),
                                DropdownMenuItem(
                                    value: 'twinkl-cursive-unlooped',
                                    child: Text('Twinkl Cursive Unlooped')),
                                DropdownMenuItem(
                                    value: 'twinkl-precursive',
                                    child: Text('Twinkl Precursive')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _theme =
                                      _theme.copyWith(fontFamily: v));
                                }
                              },
                            ),

                            const SizedBox(height: 16),
                            // Font weight
                            const Text('Font Weight',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            DropdownButton<String>(
                              value: _theme.fontWeight,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: '300',
                                    child: Text('Light')),
                                DropdownMenuItem(
                                    value: '400',
                                    child: Text('Regular')),
                                DropdownMenuItem(
                                    value: '500',
                                    child: Text('Medium')),
                                DropdownMenuItem(
                                    value: '600',
                                    child: Text('Semi-Bold')),
                                DropdownMenuItem(
                                    value: '700',
                                    child: Text('Bold')),
                                DropdownMenuItem(
                                    value: '800',
                                    child: Text('Extra Bold')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _theme =
                                      _theme.copyWith(fontWeight: v));
                                }
                              },
                            ),

                            const SizedBox(height: 8),
                            // Font transform
                            SwitchListTile(
                              title: const Text('UPPERCASE Text'),
                              value: _theme.fontTransform == 'uppercase',
                              onChanged: (v) => setState(() => _theme =
                                  _theme.copyWith(
                                      fontTransform:
                                          v ? 'uppercase' : 'none')),
                            ),

                            const SizedBox(height: 16),
                            // Theme emoji
                            const Text('Theme Emoji',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                '\u{1F3A8}', '\u{2705}', '\u{1F30A}',
                                '\u{1F332}', '\u{2600}', '\u{1F49C}',
                                '\u{26AB}', '\u{26A1}', '\u{1F31F}',
                                '\u{1F3B5}', '\u{1F680}', '\u{1F308}',
                              ].map((emoji) {
                                final isSelected = _theme.emoji == emoji;
                                return GestureDetector(
                                  onTap: () => setState(() =>
                                      _theme = _theme.copyWith(
                                          emoji: emoji)),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.brandPrimary
                                            : AppColors.brandBorder,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                        child: Text(emoji,
                                            style: const TextStyle(
                                                fontSize: 20))),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),
                            // Dot/tick colors
                            const Text('Progress Dot Colors',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            _ColorPicker(
                              label: 'Completed',
                              currentColor: _theme.tickPastColor,
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      tickPastColor: c)),
                            ),
                            _ColorPicker(
                              label: 'Current',
                              currentColor: _theme.tickCurrentColor,
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      tickCurrentColor: c)),
                            ),
                            _ColorPicker(
                              label: 'Upcoming',
                              currentColor: _theme.tickFutureColor,
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      tickFutureColor: c)),
                            ),

                            const SizedBox(height: 16),
                            // Progress line colors
                            const Text('Progress Line Gradient',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            _ColorPicker(
                              label: 'Line Start',
                              currentColor:
                                  _theme.progressLineColors['from'] ??
                                      '#22c55e',
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      progressLineColors: {
                                    ..._theme.progressLineColors,
                                    'from': c,
                                  })),
                            ),
                            _ColorPicker(
                              label: 'Line End',
                              currentColor:
                                  _theme.progressLineColors['to'] ??
                                      '#3b82f6',
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      progressLineColors: {
                                    ..._theme.progressLineColors,
                                    'to': c,
                                  })),
                            ),
                            _ColorPicker(
                              label: 'Line Background',
                              currentColor: _theme.progressBgColor,
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      progressBgColor: c)),
                            ),

                            const SizedBox(height: 16),
                            // Current task overlay
                            _ColorPicker(
                              label: 'Current Task Overlay',
                              currentColor: _theme.currentBgOverlay,
                              onChanged: (c) => setState(() =>
                                  _theme = _theme.copyWith(
                                      currentBgOverlay: c)),
                            ),

                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Enhanced Current Border'),
                              value: _theme.currentBorderEnhance,
                              onChanged: (v) => setState(() => _theme =
                                  _theme.copyWith(
                                      currentBorderEnhance: v)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Live preview
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: getBackgroundGradient(_theme),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brandBorder),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Preview',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            // Sample current task
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: parseColorString(
                                    _theme.currentBgOverlay),
                                borderRadius: BorderRadius.circular(
                                    _theme.borderRadius),
                                border: Border.all(
                                  color: parseHexColor(
                                      _theme.currentGlowColor),
                                  width: _theme.borderWidthValue * 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: parseHexColor(
                                            _theme.currentGlowColor)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Text('Current Task',
                                  style: getThemeTextStyle(_theme, 16)
                                      .copyWith(
                                          fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 16),
                            // Sample regular task
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    parseHexColor(_theme.cardBgColor),
                                borderRadius: BorderRadius.circular(
                                    _theme.borderRadius),
                                border: Border.all(
                                  color: parseHexColor(
                                      _theme.cardBorderColor),
                                  width: _theme.borderWidthValue,
                                ),
                              ),
                              child: Text('Regular Task',
                                  style: getThemeTextStyle(_theme, 14)),
                            ),
                            const SizedBox(height: 16),
                            // Progress dots
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                _Dot(parseHexColor(
                                    _theme.tickPastColor)),
                                _Dot(parseHexColor(
                                    _theme.tickCurrentColor)),
                                _Dot(parseHexColor(
                                    _theme.tickFutureColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String label;
  final String currentColor;
  final ValueChanged<String> onChanged;

  const _ColorPicker({
    required this.label,
    required this.currentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showPicker(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: parseHexColor(currentColor),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 80,
            child: TextField(
              controller: TextEditingController(text: currentColor),
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final colors = [
      '#0D9488', '#3b82f6', '#166534', '#f97316', '#a78bfa',
      '#000000', '#dc2626', '#7c3aed', '#fbbf24', '#06b6d4',
      '#ffffff', '#f3f4f6', '#F0FDFA', '#eff6ff', '#fefce8',
      '#faf5ff', '#fee2e2', '#f0fdf4', '#fce7f3', '#ccfbf1',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pick $label'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((c) {
            return GestureDetector(
              onTap: () {
                onChanged(c);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: parseHexColor(c),
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
