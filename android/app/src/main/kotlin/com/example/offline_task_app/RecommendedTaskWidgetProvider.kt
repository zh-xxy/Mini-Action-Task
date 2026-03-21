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

            // 1. 查看按钮：保持跳转到 App
            val openRecommendedIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_OPEN_RECOMMENDED
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openRecommendedPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 1,
                openRecommendedIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val refreshIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_REFRESH_RECOMMENDED
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val refreshPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 2,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 3. 新建任务按钮：保持跳转
            val createTaskIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_CREATE_TASK
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val createTaskPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 3,
                createTaskIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 移除根布局的点击事件，仅为按钮设置点击
            views.setOnClickPendingIntent(R.id.widgetOpenRecommend, openRecommendedPendingIntent)
            views.setOnClickPendingIntent(R.id.widgetRefresh, refreshPendingIntent)
            views.setOnClickPendingIntent(R.id.widgetCreateTask, createTaskPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
