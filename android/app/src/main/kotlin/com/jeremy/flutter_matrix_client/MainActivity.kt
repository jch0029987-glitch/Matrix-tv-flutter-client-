package com.jeremy.flutter_matrix_client

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.jeremy.flutter_matrix_client/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    MatrixForegroundService.startService(this)
                    result.success(true)
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "Matrix Notification"
                    val body = call.argument<String>("body") ?: ""
                    
                    MatrixForegroundService.showMessageNotification(this, title, body)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
