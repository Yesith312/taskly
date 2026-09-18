package com.taskly.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

// Este widget lee lo último que Flutter guardó con
// HomeWidget.saveWidgetData('tasks_json', ...) y dibuja hasta 3 tareas.
// Se actualiza solo cada vez que la app llama a HomeWidget.updateWidget(),
// no necesita internet propio: solo lee datos que la app ya sincronizó.
class TasklyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val tasksJson = prefs.getString("tasks_json", "[]") ?: "[]"
        val tasks = JSONArray(tasksJson)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.taskly_widget)

            views.setTextViewText(R.id.widget_title, "Taskly")

            val line1 = if (tasks.length() > 0) tasks.getJSONObject(0).getString("title") else "Sin tareas próximas"
            val line2 = if (tasks.length() > 1) tasks.getJSONObject(1).getString("title") else ""
            val line3 = if (tasks.length() > 2) tasks.getJSONObject(2).getString("title") else ""

            views.setTextViewText(R.id.widget_task_1, line1)
            views.setTextViewText(R.id.widget_task_2, line2)
            views.setTextViewText(R.id.widget_task_3, line3)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
