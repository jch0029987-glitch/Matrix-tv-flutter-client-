package com.jeremy.flutter_matrix_client

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView

class ScreenOverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_BODY = "extra_body"

        fun showOverlay(context: Context, title: String, body: String) {
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
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Matrix TV"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""

        showFloatingView(title, body)
        return START_NOT_STICKY
    }

    private fun showFloatingView(titleText: String, bodyText: String) {
        // Remove existing view if already present to prevent stacking
        if (overlayView != null) {
            windowManager.removeView(overlayView)
            overlayView = null
        }

        // Layout parameters for a system overlay window that sits on top of full-screen apps
        val LAYOUT_TYPE = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            LAYOUT_TYPE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or 
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP.let { Gravity.TOP or Gravity.CENTER_HORIZONTAL }
            y = 50 // Padding from top of TV screen
        }

        // Programmatically create a clean TV-friendly notification banner view
        val context = this
        val view = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(32, 24, 32, 24)
            setBackgroundColor(0xEE111111.toInt()) // Dark semi-transparent background
            
            // Optional: add a border look via background or padding wrapper
            
            addView(TextView(context).apply {
                text = titleText
                setTextColor(0xFF00E676.toInt()) // Teal accent
                textSize = 16f
                setTypeface(null, android.graphics.Typeface.BOLD)
            })

            addView(TextView(context).apply {
                text = bodyText
                setTextColor(0xFFFFFFFF.toInt())
                textSize = 14f
                setPadding(0, 4, 0, 0)
            })
        }

        overlayView = view
        try {
            windowManager.addView(view, params)

            // Auto-dismiss the overlay after 4 seconds
            handler.postDelayed({
                removeOverlay()
            }, 4000)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun removeOverlay() {
        try {
            overlayView?.let {
                windowManager.removeView(it)
                overlayView = null
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        stopSelf()
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }
}
