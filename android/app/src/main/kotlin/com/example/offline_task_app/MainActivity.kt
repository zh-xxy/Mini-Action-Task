package com.example.offline_task_app

import android.content.Intent
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val ACTION_CREATE_TASK = "com.example.miniactiontask.CREATE_TASK"
    }

    private var shortcutChannel: MethodChannel? = null

    override fun getInitialRoute(): String? {
        return if (intent?.action == ACTION_CREATE_TASK) "/new-task" else super.getInitialRoute()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shortcutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mini_action_task/shortcut")
        shortcutChannel?.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "updateWidgetTask" -> {
                    val title = call.argument<String>("title") ?: "暂无推荐任务"
                    val nextAction = call.argument<String>("nextAction") ?: "先新增一个任务开始吧"
                    val sp = getSharedPreferences("mini_action_task_widget", Context.MODE_PRIVATE)
                    sp.edit()
                        .putString("title", title)
                        .putString("nextAction", nextAction)
                        .apply()
                    RecommendedTaskWidgetProvider.updateAll(this, title, nextAction)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_CREATE_TASK) {
            shortcutChannel?.invokeMethod("openNewTask", null)
        }
    }
}
