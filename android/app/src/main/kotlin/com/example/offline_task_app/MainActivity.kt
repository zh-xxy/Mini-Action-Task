package com.example.offline_task_app

import android.content.Intent
import android.content.Context
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
        const val CHANNEL_NAME = "mini_action_task/shortcut"
    }

    private var shortcutChannel: MethodChannel? = null
    private var isDartReady = false
    private var pendingActionMethod: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shortcutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        shortcutChannel?.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "ready") {
                isDartReady = true
                pendingActionMethod?.let {
                    shortcutChannel?.invokeMethod(it, null)
                    pendingActionMethod = null
                }
                result.success(true)
            } else if (call.method == "updateWidgetTasks") {
                val tasks = call.argument<List<Map<String, String>>>("tasks")
                val sp = getSharedPreferences("mini_action_task_widget", Context.MODE_PRIVATE)
                val editor = sp.edit()
                if (tasks != null && tasks.isNotEmpty()) {
                    editor.putInt("task_count", tasks.size)
                    for (i in tasks.indices) {
                        val title = tasks[i]["title"] ?: "暂无推荐任务"
                        val nextAction = tasks[i]["nextAction"] ?: "先新增一个任务开始吧"
                        editor.putString("title_$i", title)
                        editor.putString("nextAction_$i", nextAction)
                    }
                } else {
                    editor.putInt("task_count", 0)
                }
                editor.putInt("current_index", 0)
                editor.apply()
                RecommendedTaskWidgetProvider.updateAll(this)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.action ?: return
        val method = when (action) {
            ACTION_CREATE_TASK -> "openNewTask"
            ACTION_OPEN_RECOMMENDED -> "openRecommendedTasks"
            ACTION_REFRESH_RECOMMENDED -> "refreshRecommendation"
            else -> null
        }
        method?.let {
            if (isDartReady) {
                shortcutChannel?.invokeMethod(it, null)
            } else {
                pendingActionMethod = it
            }
        }
    }
}
