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
  bool _saving = false;

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

  /// true = el usuario confirmó que quiere guardar igual; false = se
  /// canceló para corregir la fecha/hora.
  Future<bool> _confirmIfPastOrNoReminder(TaskModel candidate) async {
    final now = DateTime.now();
    final dueDateOnly = DateTime(_dueDate.year, _dueDate.month, _dueDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    final isPastDueDate = dueDateOnly.isBefore(todayOnly);

    final notificationService = context.read<NotificationService>();
    final reminderWontFire = notificationService.reminderAlreadyPassed(candidate);

    if (!isPastDueDate && !reminderWontFire) return true; // todo normal, no hay nada que avisar

    if (!mounted) return true;

    final t = AppLocalizations.of(context)!;
    final message = isPastDueDate
        ? t.taskDatePassedMessage
        : t.reminderWontArriveMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.warningTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.fixDateTime),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.saveAnyway),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_saving) return;

    final t = AppLocalizations.of(context)!;
    final taskService = context.read<TaskService>();
    final notificationService = context.read<NotificationService>();
    final userId = context.read<AuthService>().currentUser!.uid;

    // Se arma la tarea candidata primero (sin guardar todavía) para
    // poder chequear la fecha/hora de aviso antes de escribir nada.
    final candidate = (widget.existingTask ?? TaskModel(
      id: '',
      ownerId: userId,
      title: '',
      description: '',
      dueDate: _dueDate,
      category: _category,
    )).copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDate,
      category: _category,
      notifyDaysBefore: _notifyDaysBefore,
      notifyHour: _notifyTime.hour,
      notifyMinute: _notifyTime.minute,
    );

    final shouldContinue = await _confirmIfPastOrNoReminder(candidate);
    if (!shouldContinue) return;
    if (!mounted) return;

    setState(() => _saving = true);

    try {
      final dueBody = t.notificationDueBody(_formatDate(candidate.dueDate));
      final nudgeBody = t.notificationNudgeBody;

      if (_isEditing) {
        await taskService.updateTask(candidate);
        await notificationService.scheduleForTask(
          candidate,
          dueBody: dueBody,
          nudgeBody: nudgeBody,
        );
      } else {
        final id = await taskService.createTask(candidate);
        final savedTask = TaskModel.fromMap(id, candidate.toMap());
        await notificationService.scheduleForTask(
          savedTask,
          dueBody: dueBody,
          nudgeBody: nudgeBody,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? t.taskUpdated : t.taskCreated)),
      );
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Si algo falla guardando en Firestore (sin internet y sin caché
      // local todavía, por ejemplo), avisamos en vez de quedarnos
      // pegados en esta pantalla sin explicación.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.saveFailed}: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
      setState(() => _saving = true);
      await notificationService.cancelForTask(widget.existingTask!.id);
      await taskService.deleteTask(widget.existingTask!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.taskDeleted)),
      );
      await Future.delayed(const Duration(seconds: 3));
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
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.save),
          ),
        ],
      ),
    );
  }
}
