package com.jeremy.flutter_matrix_client

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class ScreenOverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "MatrixOverlay"
        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_BODY = "extra_body"

        fun showOverlay(context: Context, title: String, body: String) {
            Log.d(TAG, "showOverlay requested for title: '$title'")
            val intent = Intent(context, ScreenOverlayService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ScreenOverlayService created")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Matrix TV"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""
        Log.d(TAG, "onStartCommand received. Title: $title | Body: $body")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "matrix_overlay_foreground_channel"
            val channel = NotificationChannel(
                channelId,
                "Overlay Background Service",
                NotificationManager.IMPORTANCE_MIN
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)

            val notification = NotificationCompat.Builder(this, channelId)
                .setContentTitle("Matrix Overlay Active")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .build()
            
            startForeground(1338, notification)
        }

        showFloatingView(title, body)
        return START_NOT_STICKY
    }

    private fun showFloatingView(titleText: String, bodyText: String) {
        if (overlayView != null) {
            Log.d(TAG, "Removing existing active overlay view before adding a new one")
            try {
                windowManager.removeView(overlayView)
            } catch (e: Exception) {
                Log.e(TAG, "Error removing old overlay view", e)
            }
            overlayView = null
        }

        val layoutType = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or 
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 60
        }

        try {
            val context = applicationContext
            val view = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(50, 40, 50, 40)
                setBackgroundColor(0xEE1A1A1A.toInt())
                
                addView(TextView(context).apply {
                    text = titleText
                    setTextColor(0xFF00E676.toInt())
                    textSize = 18f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                })

                addView(TextView(context).apply {
                    text = bodyText
                    setTextColor(0xFFFFFFFF.toInt())
                    textSize = 15f
                    setPadding(0, 8, 0, 0)
                })
            }

            overlayView = view
            windowManager.addView(view, params)
            Log.d(TAG, "SUCCESS: Overlay view added to WindowManager.")

            handler.postDelayed({
                Log.d(TAG, "Auto-dismiss timer triggered, removing overlay view")
                removeOverlay()
            }, 4000)
        } catch (e: Exception) {
            Log.e(TAG, "CRITICAL EXCEPTION in showFloatingView: ${e.message}", e)
        }
    }

    private fun removeOverlay() {
        try {
            overlayView?.let {
                windowManager.removeView(it)
                overlayView = null
                Log.d(TAG, "Overlay view successfully removed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during overlay removal", e)
        }
        stopSelf()
    }

    override fun onDestroy() {
        Log.d(TAG, "ScreenOverlayService destroyed")
        removeOverlay()
        super.onDestroy()
    }
}
