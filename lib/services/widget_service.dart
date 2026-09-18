import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/task.dart';

/// Empuja las próximas tareas hacia el widget de pantalla de inicio.
/// home_widget guarda estos datos en SharedPreferences/UserDefaults
/// nativos, que es lo que el widget nativo (Android/iOS) lee para
/// dibujarse sin tener que abrir la app.
class WidgetService {
  static const _appGroupId = 'group.com.taskly.app'; // usado en iOS
  static const _androidWidgetName = 'TasklyWidgetProvider';

  Future<void> updateWidget(List<TaskModel> upcomingTasks) async {
    await HomeWidget.setAppGroupId(_appGroupId);

    final nextTasks = upcomingTasks.where((t) => !t.isDone).take(3).map((t) {
      return {
        'title': t.title,
        'dueDate': t.dueDate.toIso8601String(),
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>('tasks_json', jsonEncode(nextTasks));
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: 'TasklyWidget',
    );
  }
}
