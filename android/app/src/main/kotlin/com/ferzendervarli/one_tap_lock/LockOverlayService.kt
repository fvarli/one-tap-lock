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
import android.view.GestureDetector
import android.view.Gravity
import android.view.HapticFeedbackConstants
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
 *
 * Behaviour is driven entirely by [LockPrefs]:
 *  - tap / double-tap → lock (via the selected method)
 *  - long-press → open the app
 *  - vertical drag → reposition (Y is remembered; X stays pinned to the chosen edge)
 *
 * Send an Intent with action [ACTION_REFRESH] to rebuild the button after a
 * settings change while the service is running.
 */
class LockOverlayService : Service() {

    companion object {
        @Volatile
        var isRunning = false

        const val ACTION_REFRESH = "com.ferzendervarli.one_tap_lock.REFRESH"

        private const val CHANNEL_ID = "otl_overlay"
        private const val NOTIF_ID = 1001
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
        if (intent?.action == ACTION_REFRESH) {
            // Apply changed appearance/position settings to the live button.
            removeButton()
            addButton()
        }
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
        val sizePx = (LockPrefs.sizeDp(this) * density).roundToInt()
        val padPx = (sizePx * 0.24f).roundToInt()
        val opacity = LockPrefs.opacity(this) / 100f
        val isLeft = LockPrefs.edge(this) == "left"

        // Semi-transparent dark circle with a white lock glyph — subtle, not annoying.
        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0xFF202A33.toInt()) // base colour; transparency comes from view alpha
        }

        val button = ImageView(this).apply {
            setImageResource(R.drawable.ic_lock)
            setPadding(padPx, padPx, padPx, padPx)
            this.background = background
            alpha = opacity
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
            // Pin to the chosen edge; x is the inward margin, so the button always
            // snaps back to that edge after a (vertical-only) drag.
            gravity = Gravity.TOP or (if (isLeft) Gravity.START else Gravity.END)
            x = (LockPrefs.marginDp(this@LockOverlayService) * density).roundToInt()
            y = LockPrefs.y(this@LockOverlayService, resources.displayMetrics.heightPixels / 3)
        }

        attachTouchListener(button, lp)

        windowManager.addView(button, lp)
        buttonView = button
        params = lp
    }

    private fun attachTouchListener(button: View, lp: WindowManager.LayoutParams) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop

        // Tap / double-tap / long-press are handled by GestureDetector; vertical
        // dragging is handled manually so we can move the overlay window itself.
        val gestureDetector = GestureDetector(
            this,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onSingleTapUp(e: MotionEvent): Boolean {
                    if (LockPrefs.tapMode(this@LockOverlayService) == "single") {
                        performLock(button)
                    }
                    return true
                }

                override fun onDoubleTap(e: MotionEvent): Boolean {
                    if (LockPrefs.tapMode(this@LockOverlayService) == "double") {
                        performLock(button)
                    }
                    return true
                }

                override fun onLongPress(e: MotionEvent) {
                    openApp()
                }
            },
        )

        var initialY = 0
        var initialTouchY = 0f
        var dragging = false

        button.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = lp.y
                    initialTouchY = event.rawY
                    dragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = (event.rawY - initialTouchY).roundToInt()
                    if (abs(dy) > touchSlop) dragging = true
                    if (dragging) {
                        lp.y = (initialY + dy).coerceAtLeast(0)
                        windowManager.updateViewLayout(button, lp)
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) LockPrefs.saveY(this, lp.y)
                }
            }
            true
        }
    }

    private fun removeButton() {
        buttonView?.let { runCatching { windowManager.removeView(it) } }
        buttonView = null
        params = null
    }

    // --- Lock --------------------------------------------------------------

    private fun performLock(view: View) {
        if (LockPrefs.haptic(this)) {
            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
        }
        when (LockPrefs.method(this)) {
            LockPrefs.METHOD_ACCESSIBILITY -> lockViaAccessibility()
            else -> lockViaDeviceAdmin(announce = true)
        }
    }

    private fun lockViaAccessibility() {
        if (LockAccessibilityService.lock()) return
        // Service disabled or unsupported — fall back to Device Admin if available.
        if (deviceAdminActive()) {
            Toast.makeText(this, "Accessibility off — used Device Admin.", Toast.LENGTH_SHORT).show()
            lockViaDeviceAdmin(announce = false)
        } else {
            Toast.makeText(this, "Enable the accessibility service to lock.", Toast.LENGTH_SHORT).show()
        }
    }

    private fun lockViaDeviceAdmin(announce: Boolean) {
        if (!deviceAdminActive()) {
            Toast.makeText(this, "Device admin is off — enable it in the app.", Toast.LENGTH_SHORT).show()
            return
        }
        try {
            (getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager).lockNow()
        } catch (e: SecurityException) {
            Toast.makeText(this, "Could not lock the screen.", Toast.LENGTH_SHORT).show()
        }
    }

    private fun deviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(ComponentName(this, LockDeviceAdminReceiver::class.java))
    }

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent != null) startActivity(intent)
    }

    // --- Foreground notification (low importance, silent, minimal) ---------

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Floating lock button",
                NotificationManager.IMPORTANCE_LOW // no sound, no peek
            ).apply { setShowBadge(false) }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("One Tap Lock")
            .setSmallIcon(R.drawable.ic_lock)
            .setOngoing(true)
            .build()
    }
}
