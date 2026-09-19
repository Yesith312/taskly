import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../l10n/app_localizations.dart';
import 'task_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final taskService = context.read<TaskService>();
    final notificationService = context.read<NotificationService>();
    final widgetService = context.read<WidgetService>();
    final t = AppLocalizations.of(context)!;
    final userId = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.myTasks),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: taskService.watchTasksForUser(userId),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];

          // Cada vez que cambian las tareas, reprogramamos notificaciones
          // y refrescamos el widget de pantalla de inicio.
          for (final task in tasks) {
            notificationService.scheduleForTask(
              task,
              dueBody: t.notificationDueBody(_formatDate(task.dueDate)),
              nudgeBody: t.notificationNudgeBody,
            );
          }
          widgetService.updateWidget(
            tasks.where((t) => t.dueDate.isAfter(DateTime.now())).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
          );

          final tasksForSelectedDay = tasks
              .where((task) => _isSameDay(task.dueDate, _selectedDay))
              .toList();

          return Column(
            children: [
              TableCalendar<TaskModel>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => _isSameDay(day, _selectedDay),
                eventLoader: (day) =>
                    tasks.where((task) => _isSameDay(task.dueDate, day)).toList(),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarStyle: const CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: tasksForSelectedDay.isEmpty
                    ? _EmptyState(message: t.noTasksToday)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: tasksForSelectedDay.length,
                        itemBuilder: (context, index) {
                          final task = tasksForSelectedDay[index];
                          return _TaskCard(task: task);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskFormScreen(initialDate: _selectedDay),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(t.newTask),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/sin-tareas.png', width: 200),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  String _statusIcon() {
    if (task.isDone) return 'assets/icons/hecho.svg';
    final isOverdue = task.dueDate.isBefore(DateTime.now());
    return isOverdue ? 'assets/icons/atrasado.svg' : 'assets/icons/pendiente.svg';
  }

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();
    final t = AppLocalizations.of(context)!;
    final categoryIcon = task.category == TaskCategory.school
        ? 'assets/icons/colegio.svg'
        : 'assets/icons/trabajo.svg';
    final categoryLabel = task.category == TaskCategory.school ? t.school : t.work;

    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskFormScreen(existingTask: task)),
        ),
        leading: SizedBox(
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => taskService.setDone(task.id, !task.isDone),
            child: SvgPicture.asset(_statusIcon()),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: SvgPicture.asset(categoryIcon),
            ),
            const SizedBox(width: 6),
            Text(categoryLabel),
          ],
        ),
      ),
    );
  }
}
