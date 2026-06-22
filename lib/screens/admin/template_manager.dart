import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme_constants.dart';
import '../../models/template.dart';
import '../../models/weekly_schedule.dart';
import '../../providers/school_provider.dart';
import '../../utils/time_utils.dart';

class TemplateManager extends ConsumerStatefulWidget {
  final List<TaskTemplate> templates;
  final WeeklySchedule weeklySchedule;

  const TemplateManager({
    super.key,
    required this.templates,
    required this.weeklySchedule,
  });

  @override
  ConsumerState<TemplateManager> createState() => _TemplateManagerState();
}

class _TemplateManagerState extends ConsumerState<TemplateManager> {
  String? _assigningTemplateId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Weekly Schedule section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Weekly Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Assign templates to days. Templates auto-load when the display starts.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.brandTextMuted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']
                      .map((day) => Expanded(
                            child: _DayCard(
                              day: day,
                              templateId: widget.weeklySchedule.getForDay(day),
                              templates: widget.templates,
                              isAssigning: _assigningTemplateId != null,
                              onAssign: () {
                                if (_assigningTemplateId != null) {
                                  ref
                                      .read(schoolProvider.notifier)
                                      .updateWeeklySchedule(
                                        widget.weeklySchedule.setForDay(
                                            day, _assigningTemplateId),
                                      );
                                  setState(() => _assigningTemplateId = null);
                                }
                              },
                              onRemove: () {
                                ref
                                    .read(schoolProvider.notifier)
                                    .updateWeeklySchedule(
                                      widget.weeklySchedule
                                          .setForDay(day, null),
                                    );
                              },
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Available Templates
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Available Templates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _assigningTemplateId != null
                      ? 'Now click a day above to assign'
                      : 'Click "Assign" to select, then click a day above',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.brandTextMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: widget.templates.map((template) {
                    final isAssigning =
                        _assigningTemplateId == template.id.toString();
                    return _TemplateCard(
                      template: template,
                      isAssigning: isAssigning,
                      onAssign: () {
                        setState(() {
                          _assigningTemplateId = isAssigning
                              ? null
                              : template.id.toString();
                        });
                      },
                      onLoad: () => _loadTemplate(template),
                      onDelete: () => _deleteTemplate(template),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _loadTemplate(TaskTemplate template) {
    // Applies the template's tasks AND its per-template settings + theme.
    ref.read(schoolProvider.notifier).loadTemplate(template);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded "${template.name}"')),
    );
  }

  void _deleteTemplate(TaskTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Delete this template? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(schoolProvider.notifier).updateTemplates(
                    widget.templates
                        .where(
                            (t) => t.id.toString() != template.id.toString())
                        .toList(),
                  );
              // Clean up weekly schedule references
              final schedule = widget.weeklySchedule;
              var updated = schedule;
              for (final day in [
                'monday',
                'tuesday',
                'wednesday',
                'thursday',
                'friday'
              ]) {
                if (updated.getForDay(day) == template.id.toString()) {
                  updated = updated.setForDay(day, null);
                }
              }
              ref.read(schoolProvider.notifier).updateWeeklySchedule(updated);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String day;
  final String? templateId;
  final List<TaskTemplate> templates;
  final bool isAssigning;
  final VoidCallback onAssign;
  final VoidCallback onRemove;

  const _DayCard({
    required this.day,
    this.templateId,
    required this.templates,
    required this.isAssigning,
    required this.onAssign,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = getDayKey(DateTime.now().weekday) == day;
    final template = templateId != null
        ? templates
            .where((t) => t.id.toString() == templateId)
            .firstOrNull
        : null;
    final dayLabel = day[0].toUpperCase() + day.substring(1);

    return GestureDetector(
      onTap: isAssigning ? onAssign : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          border: Border.all(
            color: isAssigning
                ? AppColors.brandPrimary
                : template != null
                    ? AppColors.brandSuccess
                    : AppColors.brandBorder,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isAssigning
              ? AppColors.brandPrimaryBg
              : template != null
                  ? Colors.green.shade50
                  : AppColors.brandBgSubtle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isToday ? AppColors.brandAccent : AppColors.brandText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (template != null) ...[
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandSuccess,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${template.startTime}-${template.endTime}',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.brandTextMuted),
              ),
              Text(
                '${template.tasks.length} tasks',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.brandTextMuted),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onRemove,
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.brandError,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              const Text(
                '+',
                style: TextStyle(
                    fontSize: 24, color: AppColors.brandTextMuted),
              ),
              Text(
                isAssigning ? 'Click to assign' : 'No template',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.brandTextMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final TaskTemplate template;
  final bool isAssigning;
  final VoidCallback onAssign;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.isAssigning,
    required this.onAssign,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isAssigning ? AppColors.brandPrimary : AppColors.brandBorder,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (template.id != 'default')
                GestureDetector(
                  onTap: onDelete,
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.brandError,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            template.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            '${template.startTime} - ${template.endTime}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.brandTextMuted),
          ),
          Text(
            '${template.tasks.length} tasks',
            style: const TextStyle(
                fontSize: 11, color: AppColors.brandTextMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAssign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAssigning
                        ? AppColors.brandBgSubtle
                        : AppColors.brandSuccess,
                    foregroundColor:
                        isAssigning ? AppColors.brandText : Colors.white,
                    padding: const EdgeInsets.all(8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(isAssigning ? 'Cancel' : 'Assign'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLoad,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Load'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
