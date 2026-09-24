package com.jeremy.flutter_matrix_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MatrixForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "matrix_foreground_channel"
        const val NOTIFICATION_ID = 1337
        const val ACTION_START = "START_FOREGROUND"
        const val ACTION_STOP = "STOP_FOREGROUND"
        const val ACTION_SHOW_MESSAGE = "SHOW_MESSAGE_NOTIFICATION"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"

        fun startService(context: Context) {
            val intent = Intent(context, MatrixForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun showMessageNotification(context: Context, title: String, body: String) {
            val intent = Intent(context, MatrixForegroundService::class.java).apply {
                action = ACTION_SHOW_MESSAGE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val notification = createPersistentNotification("Matrix TV Service Running", "Listening for background events & web requests...")
                startForeground(NOTIFICATION_ID, notification)
            }
            ACTION_SHOW_MESSAGE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Matrix Message"
                val body = intent.getStringExtra(EXTRA_BODY) ?: ""
                dispatchMessageNotification(title, body)
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Matrix Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the Matrix TV server active in the background"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createPersistentNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun dispatchMessageNotification(title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val messageNotification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), messageNotification)
    }
}
