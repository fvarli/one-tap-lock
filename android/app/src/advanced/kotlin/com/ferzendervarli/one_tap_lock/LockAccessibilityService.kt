package com.ferzendervarli.one_tap_lock

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * ADVANCED flavor only. Privacy-minimal accessibility service: it processes no
 * events and reads no window content; its ONLY purpose is to expose
 * performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN) so the floating button can lock
 * the screen without forcing strong authentication (so biometric unlock can keep
 * working).
 */
class LockAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        private var instance: LockAccessibilityService? = null

        /** True only while the service is connected/enabled in this process. */
        val isConnected: Boolean get() = instance != null

        /**
         * Locks the screen via the global action. Returns false if the service
         * is not connected or the platform is older than Android 9 (API 28).
         */
        fun lock(): Boolean {
            val service = instance ?: return false
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
            return service.performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    // No event processing — intentionally empty for privacy.
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
