import 'package:flutter/material.dart';
import '../../config/theme_constants.dart';
import '../../data/icon_library.dart';
import '../../models/task.dart';
import '../../utils/image_upload.dart';

class TaskEditorModal extends StatefulWidget {
  final Task task;
  final ValueChanged<Task> onSave;
  final String schoolId;
  final bool isFreeMode;

  /// Hide the duration control (the end card has no duration).
  final bool hideDuration;

  /// Dialog title.
  final String title;

  const TaskEditorModal({
    super.key,
    required this.task,
    required this.onSave,
    required this.schoolId,
    this.isFreeMode = false,
    this.hideDuration = false,
    this.title = 'Edit Task',
  });

  @override
  State<TaskEditorModal> createState() => _TaskEditorModalState();
}

class _TaskEditorModalState extends State<TaskEditorModal> {
  late String _type;
  late TextEditingController _contentController;
  late int _duration;
  late String? _icon;
  late String? _imageUrl;
  late int _width;
  late int _height;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.task.type;
    _contentController = TextEditingController(text: widget.task.content);
    _duration = widget.task.duration;
    _icon = widget.task.icon;
    _imageUrl = widget.task.imageUrl;
    _width = widget.task.width;
    _height = widget.task.height;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploading = true);

    final result = await pickAndUploadTaskImage(widget.schoolId);

    if (!mounted) return;
    setState(() => _uploading = false);

    if (result.error == 'cancelled') return;

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
      );
      return;
    }

    if (result.isWarning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded but is large — consider using a smaller file for faster loading'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    setState(() {
      _imageUrl = result.publicUrl;
      _type = 'image';
    });
  }

  Future<void> _removeImage() async {
    if (_imageUrl != null) {
      deleteTaskImage(_imageUrl!);
    }
    setState(() {
      _imageUrl = null;
      if (_type == 'image') _type = 'text';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Task type
                const Text('Task Type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'text', label: Text('Text')),
                    const ButtonSegment(value: 'icon', label: Text('Icon')),
                    if (!widget.isFreeMode)
                      const ButtonSegment(value: 'image', label: Text('Image')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (v) => setState(() => _type = v.first),
                ),
                const SizedBox(height: 16),

                // Content
                const Text('Task Name', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(hintText: 'e.g. Maths'),
                ),
                const SizedBox(height: 16),

                // Duration
                if (!widget.hideDuration) ...[
                  const Text('Duration (minutes)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _duration.toDouble(),
                          min: 5,
                          max: 180,
                          divisions: 35,
                          label: '$_duration min',
                          onChanged: (v) =>
                              setState(() => _duration = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '$_duration min',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Image upload (paid only)
                if (widget.isFreeMode) ...[
                  Text(
                    'Image upload available on paid plans',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ] else ...[
                  const Text('Task Image', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_imageUrl != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _imageUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _uploading ? null : _pickImage,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Replace image'),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickImage,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate, size: 18),
                      label: Text(_uploading ? 'Uploading...' : 'Choose image'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG, GIF or WebP. Max 2MB.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
                const SizedBox(height: 16),

                // Icon picker
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _iconButton(null, 'None'),
                    ...iconLibrary.map(
                      (entry) => _iconButton(entry.id, entry.name),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Size controls
                const Text('Tile Size', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Width: '),
                    Expanded(
                      child: Slider(
                        value: _width.toDouble(),
                        min: 120,
                        max: 400,
                        divisions: 28,
                        label: '${_width}px',
                        onChanged: (v) =>
                            setState(() => _width = v.round()),
                      ),
                    ),
                    Text('$_width'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Height: '),
                    Expanded(
                      child: Slider(
                        value: _height.toDouble(),
                        min: 100,
                        max: 300,
                        divisions: 20,
                        label: '${_height}px',
                        onChanged: (v) =>
                            setState(() => _height = v.round()),
                      ),
                    ),
                    Text('$_height'),
                  ],
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _uploading ? null : () {
                        widget.onSave(widget.task.copyWith(
                          type: _type,
                          content: _contentController.text,
                          duration: _duration,
                          icon: _icon,
                          imageUrl: _imageUrl,
                          width: _width,
                          height: _height,
                        ));
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(String? iconId, String name) {
    final isSelected = _icon == iconId;
    final iconData = iconId != null ? getIconData(iconId) : null;

    return Tooltip(
      message: name,
      child: InkWell(
        onTap: () => setState(() => _icon = iconId),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isSelected ? AppColors.brandPrimary : AppColors.brandBorder,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? AppColors.brandPrimaryBg : Colors.white,
          ),
          child: Center(
            child: iconData != null
                ? Icon(iconData,
                    size: 24,
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.brandTextMuted)
                : const Text('--',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.brandTextMuted)),
          ),
        ),
      ),
    );
  }
}
