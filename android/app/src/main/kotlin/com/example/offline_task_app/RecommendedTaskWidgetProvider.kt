package com.example.offline_task_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class RecommendedTaskWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val sp = context.getSharedPreferences("mini_action_task_widget", Context.MODE_PRIVATE)
        val title = sp.getString("title", "暂无推荐任务") ?: "暂无推荐任务"
        val nextAction = sp.getString("nextAction", "先打开应用获取推荐") ?: "先打开应用获取推荐"
        appWidgetIds.forEach { id ->
            updateOne(context, appWidgetManager, id, title, nextAction)
        }
    }

    companion object {
        fun updateAll(context: Context, title: String, nextAction: String) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, RecommendedTaskWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            ids.forEach { id ->
                updateOne(context, manager, id, title, nextAction)
            }
        }

        private fun updateOne(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            title: String,
            nextAction: String
        ) {
            val views = RemoteViews(context.packageName, R.layout.recommended_task_widget)
            views.setTextViewText(R.id.widgetTaskTitle, title)
            views.setTextViewText(R.id.widgetTaskAction, nextAction)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_CREATE_TASK
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
