import 'dart:async';
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
      String notificationDiag = '';

      Future<void> saveAndSchedule() async {
        if (_isEditing) {
          await taskService.updateTask(candidate);
          notificationDiag = await notificationService.scheduleForTask(
            candidate,
            dueBody: dueBody,
            nudgeBody: nudgeBody,
          );
        } else {
          final id = await taskService.createTask(candidate);
          final savedTask = TaskModel.fromMap(id, candidate.toMap());
          notificationDiag = await notificationService.scheduleForTask(
            savedTask,
            dueBody: dueBody,
            nudgeBody: nudgeBody,
          );
        }
      }

      // Si en 4 segundos no responde (por ejemplo, mala conexión),
      // seguimos igual: Firestore ya guardó localmente la tarea desde
      // el momento en que se llamó, y se sincroniza sola en cuanto haya
      // señal. Como la app debe funcionar sin internet, no tiene
      // sentido bloquear al usuario esperando al servidor.
      final pendingSave = saveAndSchedule();
      try {
        await pendingSave.timeout(const Duration(seconds: 4));
      } on TimeoutException {
        pendingSave.catchError((e) {
          debugPrint('Guardado en segundo plano falló más tarde: $e');
        });
      }

      if (!mounted) return;

      // TEMPORAL, para encontrar el bug de las notificaciones: se
      // muestra el diagnóstico completo (hora calculada, zona horaria,
      // si se programó o no) en un diálogo que no se cierra solo, para
      // que te dé tiempo de leerlo o capturarlo con una foto.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diagnóstico de notificación'),
          content: SingleChildScrollView(child: Text(notificationDiag)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Un error real (ej. permiso denegado) sí se muestra de una vez;
      // el caso de "tardó mucho por mala conexión" ya no llega aquí,
      // se maneja arriba de forma optimista.
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
      try {
        final pendingDelete = Future(() async {
          await notificationService.cancelForTask(widget.existingTask!.id);
          await taskService.deleteTask(widget.existingTask!.id);
        });
        try {
          await pendingDelete.timeout(const Duration(seconds: 4));
        } on TimeoutException {
          pendingDelete.catchError((e) {
            debugPrint('Eliminación en segundo plano falló más tarde: $e');
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.taskDeleted)),
        );
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.saveFailed}: $e')),
          );
        }
      }
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
