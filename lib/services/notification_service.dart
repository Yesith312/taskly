import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/task.dart';

/// Todas las notificaciones se programan LOCALMENTE en el dispositivo
/// (flutter_local_notifications), así que funcionan aunque el celular
/// no tenga internet en el momento del aviso. Cada tarea genera hasta
/// 2 notificaciones:
///  1) el aviso normal (X días antes de la fecha, a la hora configurada)
///  2) si llega la fecha de entrega y la tarea sigue sin marcarse como
///     hecha, una notificación de "recordatorio" que se repite cada
///     7 días hasta que el usuario la marque como hecha o la borre.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // IDs de notificación derivados del id de Firestore para poder
  // cancelarlas/reprogramarlas cuando la tarea cambia.
  int _reminderId(String taskId) => taskId.hashCode & 0x7fffffff;
  int _nudgeId(String taskId) => (taskId.hashCode ^ 0x5a5a5a5a) & 0x7fffffff;

  Future<void> scheduleForTask(TaskModel task) async {
    await cancelForTask(task.id);
    if (task.isDone) return; // no se avisa nada de una tarea ya hecha

    final reminderDate = task.dueDate.subtract(
      Duration(days: task.notifyDaysBefore),
    );
    final reminderDateTime = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      task.notifyHour,
      task.notifyMinute,
    );

    if (reminderDateTime.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _reminderId(task.id),
        task.title,
        'Vence el ${_formatDate(task.dueDate)}',
        tz.TZDateTime.from(reminderDateTime, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Recordatorio semanal: empieza justo el día de la entrega, a la
    // misma hora configurada, y se repite cada 7 días. Se cancela solo
    // (con cancelForTask) en cuanto la tarea se marca como hecha.
    final nudgeStart = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      task.notifyHour,
      task.notifyMinute,
    );

    await _plugin.zonedSchedule(
      _nudgeId(task.id),
      task.title,
      'No marcaste esta tarea como hecha',
      tz.TZDateTime.from(nudgeStart, tz.local),
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelForTask(String taskId) async {
    await _plugin.cancel(_reminderId(taskId));
    await _plugin.cancel(_nudgeId(taskId));
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'taskly_tasks',
        'Tareas',
        channelDescription: 'Avisos de tareas de Taskly',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
