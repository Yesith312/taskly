import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';

class TaskFormScreen extends StatefulWidget {
  final TaskModel? existingTask;
  final DateTime? initialDate;

  const TaskFormScreen({super.key, this.existingTask, this.initialDate});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _dueDate;
  late TaskCategory _category;
  late int _notifyDaysBefore;
  late TimeOfDay _notifyTime;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _dueDate = task?.dueDate ?? widget.initialDate ?? DateTime.now();
    _category = task?.category ?? TaskCategory.school;
    _notifyDaysBefore = task?.notifyDaysBefore ?? 1;
    _notifyTime = TimeOfDay(hour: task?.notifyHour ?? 12, minute: task?.notifyMinute ?? 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _notifyTime);
    if (picked != null) setState(() => _notifyTime = picked);
  }

  Future<void> _save() async {
    final taskService = context.read<TaskService>();
    final notificationService = context.read<NotificationService>();
    final userId = context.read<AuthService>().currentUser!.uid;

    if (_titleController.text.trim().isEmpty) return;

    if (_isEditing) {
      final updated = widget.existingTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        category: _category,
        notifyDaysBefore: _notifyDaysBefore,
        notifyHour: _notifyTime.hour,
        notifyMinute: _notifyTime.minute,
      );
      await taskService.updateTask(updated);
      await notificationService.scheduleForTask(updated);
    } else {
      final newTask = TaskModel(
        id: '', // Firestore le asigna el id real al crearla
        ownerId: userId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        category: _category,
        notifyDaysBefore: _notifyDaysBefore,
        notifyHour: _notifyTime.hour,
        notifyMinute: _notifyTime.minute,
      );
      final id = await taskService.createTask(newTask);
      final savedTask = TaskModel.fromMap(id, newTask.toMap());
      await notificationService.scheduleForTask(savedTask);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final taskService = context.read<TaskService>();
    final notificationService = context.read<NotificationService>();
    final t = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.confirmDeleteTitle),
        content: Text(t.confirmDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      ),
    );

    if (confirmed == true && widget.existingTask != null) {
      await notificationService.cancelForTask(widget.existingTask!.id);
      await taskService.deleteTask(widget.existingTask!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? t.editTask : t.newTask),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: t.taskTitle),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: t.taskDescription),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.dueDate),
            subtitle: Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          SegmentedButton<TaskCategory>(
            segments: [
              ButtonSegment(value: TaskCategory.school, label: Text(t.school)),
              ButtonSegment(value: TaskCategory.work, label: Text(t.work)),
            ],
            selected: {_category},
            onSelectionChanged: (selection) => setState(() => _category = selection.first),
          ),
          const SizedBox(height: 24),
          Text(t.notificationSettings, style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.notifyDaysBefore),
            trailing: DropdownButton<int>(
              value: _notifyDaysBefore,
              items: [0, 1, 2, 3]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (value) => setState(() => _notifyDaysBefore = value ?? 1),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.notifyTime),
            subtitle: Text(_notifyTime.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
