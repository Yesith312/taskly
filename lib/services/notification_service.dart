import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
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

    // Sin esto, la librería asume UTC por defecto y todos los avisos
    // llegarían con el desfase de tu zona horaria (ej. 5 horas tarde
    // en Colombia). Detectamos la zona horaria real del celular y se
    // la indicamos explícitamente.
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('No se pudo detectar la zona horaria del celular: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      // En Android 12+ hay que pedir aparte el permiso de "alarmas
      // exactas" — si no se concede, las notificaciones programadas
      // pueden llegar tarde o directamente no llegar. Esto abre la
      // pantalla de ajustes del sistema para que el usuario lo active
      // (no hay forma de concederlo con un simple diálogo).
      final canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
      if (canScheduleExact == false) {
        await androidPlugin?.requestExactAlarmsPermission();
      }

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('No se pudieron pedir los permisos de notificaciones: $e');
    }
  }

  // IDs de notificación derivados del id de Firestore para poder
  // cancelarlas/reprogramarlas cuando la tarea cambia.
  int _reminderId(String taskId) => taskId.hashCode & 0x7fffffff;
  int _nudgeId(String taskId) => (taskId.hashCode ^ 0x5a5a5a5a) & 0x7fffffff;

  /// [dueBody] y [nudgeBody] ya vienen traducidos al idioma que la app
  /// tiene configurado (no necesariamente el del celular) — se arman
  /// afuera, con AppLocalizations, porque este servicio no tiene
  /// acceso al widget tree.
  ///
  /// Devuelve null si todo salió bien, o un texto describiendo el
  /// error si algo falló — así la pantalla que llama a esto puede
  /// mostrártelo, en vez de quedar oculto para siempre en el log.
  Future<String?> scheduleForTask(
    TaskModel task, {
    required String dueBody,
    required String nudgeBody,
  }) async {
    try {
      await cancelForTask(task.id);
      if (task.isDone) return null; // no se avisa nada de una tarea ya hecha

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
          dueBody,
          tz.TZDateTime.from(reminderDateTime, tz.local),
          _details(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

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
        nudgeBody,
        tz.TZDateTime.from(nudgeStart, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      return null;
    } catch (e, st) {
      debugPrint('No se pudo programar la notificación de "${task.title}": $e\n$st');
      return e.toString();
    }
  }

  /// Devuelve true si, con la configuración actual de la tarea, el
  /// aviso "X días antes" ya no alcanza a dispararse (porque esa fecha
  /// y hora ya pasaron). Se usa para avisarle al usuario en el
  /// formulario, antes de guardar, en vez de dejarlo sin ningún aviso
  /// y sin explicación.
  bool reminderAlreadyPassed(TaskModel task) {
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
    return !reminderDateTime.isAfter(DateTime.now());
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
