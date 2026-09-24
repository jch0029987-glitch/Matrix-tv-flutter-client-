package com.jeremy.flutter_matrix_client

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.jeremy.flutter_matrix_client/notifications"
    private val FOREGROUND_CHANNEL = "com.jeremy.flutter_matrix_client/foreground"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel for direct WindowManager overlays
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "showScreenOverlay") {
                val title = call.argument<String>("title") ?: "Matrix TV"
                val body = call.argument<String>("body") ?: ""
                ScreenOverlayService.showOverlay(context, title, body)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        // Channel for keeping the HTTP server alive via foreground service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startForegroundService") {
                val intent = Intent(context, MatrixForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
