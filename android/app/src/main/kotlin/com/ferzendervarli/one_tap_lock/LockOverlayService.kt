package com.ferzendervarli.one_tap_lock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.ImageView
import android.widget.Toast
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Foreground service that displays the floating lock button over other apps.
 * A tap locks the screen via DevicePolicyManager.lockNow(); a vertical drag
 * repositions the button (its Y is remembered across restarts).
 */
class LockOverlayService : Service() {

    companion object {
        @Volatile
        var isRunning = false

        private const val PREFS = "otl_prefs"
        private const val KEY_Y = "btn_y"
        private const val CHANNEL_ID = "otl_overlay"
        private const val NOTIF_ID = 1001
        private const val BUTTON_DP = 46
    }

    private lateinit var windowManager: WindowManager
    private var buttonView: View? = null
    private var params: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        addButton()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIF_ID, buildNotification())
        return START_STICKY
    }

    override fun onDestroy() {
        removeButton()
        isRunning = false
        super.onDestroy()
    }

    // --- Overlay button ----------------------------------------------------

    private fun addButton() {
        if (buttonView != null) return

        val density = resources.displayMetrics.density
        val sizePx = (BUTTON_DP * density).roundToInt()
        val padPx = (11 * density).roundToInt()

        // Semi-transparent dark circle with a white lock glyph — subtle, not annoying.
        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0x99202A33.toInt()) // ~60% opacity blue-grey
        }

        val button = ImageView(this).apply {
            setImageResource(R.drawable.ic_lock)
            setPadding(padPx, padPx, padPx, padPx)
            this.background = background
            alpha = 0.85f
            scaleType = ImageView.ScaleType.FIT_CENTER
        }

        val layoutType =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE

        val lp = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = (6 * density).roundToInt() // small margin from the right edge
            y = restoreY(density)
        }

        attachTouchListener(button, lp, density)

        windowManager.addView(button, lp)
        buttonView = button
        params = lp
    }

    private fun attachTouchListener(
        button: View,
        lp: WindowManager.LayoutParams,
        density: Float,
    ) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        var initialY = 0
        var initialTouchY = 0f
        var dragging = false

        button.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = lp.y
                    initialTouchY = event.rawY
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = (event.rawY - initialTouchY).roundToInt()
                    if (abs(dy) > touchSlop) dragging = true
                    if (dragging) {
                        lp.y = (initialY + dy).coerceAtLeast(0)
                        windowManager.updateViewLayout(button, lp)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) {
                        saveY(lp.y)
                    } else {
                        lockScreen()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun removeButton() {
        buttonView?.let {
            runCatching { windowManager.removeView(it) }
        }
        buttonView = null
        params = null
    }

    // --- Lock --------------------------------------------------------------

    private fun lockScreen() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(this, LockDeviceAdminReceiver::class.java)
        if (!dpm.isAdminActive(admin)) {
            Toast.makeText(this, "Device admin is off — re-enable it in the app.", Toast.LENGTH_SHORT).show()
            stopSelf()
            return
        }
        try {
            dpm.lockNow()
        } catch (e: SecurityException) {
            Toast.makeText(this, "Could not lock the screen.", Toast.LENGTH_SHORT).show()
        }
    }

    // --- Position persistence ---------------------------------------------

    private fun restoreY(density: Float): Int {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val default = (resources.displayMetrics.heightPixels / 3)
        return prefs.getInt(KEY_Y, default)
    }

    private fun saveY(y: Int) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_Y, y)
            .apply()
    }

    // --- Foreground notification (low importance, silent) ------------------

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Floating lock button",
                NotificationManager.IMPORTANCE_LOW // no sound, no peek
            ).apply {
                description = "Keeps the floating lock button running."
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("One Tap Lock")
            .setContentText("Floating lock button is active.")
            .setSmallIcon(R.drawable.ic_lock)
            .setOngoing(true)
            .build()
    }
}
