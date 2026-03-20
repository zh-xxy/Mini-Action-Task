package com.example.offline_task_app

import android.content.Intent
import android.content.Context
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val ACTION_CREATE_TASK = "com.example.miniactiontask.CREATE_TASK"
        const val ACTION_OPEN_RECOMMENDED = "com.example.miniactiontask.OPEN_RECOMMENDED"
        const val ACTION_REFRESH_RECOMMENDED = "com.example.miniactiontask.REFRESH_RECOMMENDED"
        const val ACTION_WIDGET_REFRESH = "com.example.offline_task_app.ACTION_WIDGET_REFRESH"
        const val CHANNEL_NAME = "mini_action_task/shortcut"
    }

    private var shortcutChannel: MethodChannel? = null
    
    private val widgetRefreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_WIDGET_REFRESH) {
                // 静默通知 Flutter 刷新数据
                shortcutChannel?.invokeMethod("refreshRecommendation", null)
            }
        }
    }

    override fun getInitialRoute(): String? {
        if (intent?.action == ACTION_CREATE_TASK) {
            return "/new-task"
        }
        return super.getInitialRoute()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shortcutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        shortcutChannel?.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "updateWidgetTask") {
                val title = call.argument<String>("title") ?: "暂无推荐任务"
                val nextAction = call.argument<String>("nextAction") ?: "先新增一个任务开始吧"
                val sp = getSharedPreferences("mini_action_task_widget", Context.MODE_PRIVATE)
                sp.edit()
                    .putString("title", title)
                    .putString("nextAction", nextAction)
                    .apply()
                RecommendedTaskWidgetProvider.updateAll(this, title, nextAction)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Android 14 (API 34) + 必须指定 RECEIVER_NOT_EXPORTED 标志
        val filter = IntentFilter(ACTION_WIDGET_REFRESH)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(widgetRefreshReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(widgetRefreshReceiver, filter)
        }
        
        if (intent?.action != ACTION_CREATE_TASK) {
            handleIntent(intent)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(widgetRefreshReceiver)
        } catch (e: Exception) {
            // 忽略未注册错误
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.action ?: return
        shortcutChannel?.let { channel ->
            val method = when (action) {
                ACTION_CREATE_TASK -> "openNewTask"
                ACTION_OPEN_RECOMMENDED -> "openRecommendedTasks"
                ACTION_REFRESH_RECOMMENDED -> "refreshRecommendation"
                else -> null
            }
            method?.let { channel.invokeMethod(it, null) }
        }
    }
}
