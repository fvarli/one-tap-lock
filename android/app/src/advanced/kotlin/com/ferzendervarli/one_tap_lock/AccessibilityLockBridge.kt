package com.ferzendervarli.one_tap_lock

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.text.TextUtils

/**
 * ADVANCED implementation. Shared code talks to this object so the accessibility
 * service class only needs to exist in this flavor.
 */
object AccessibilityLockBridge {

    /** Whether accessibility lock is compiled into this build. */
    const val isSupported: Boolean = true

    /** Reads the secure setting so status is correct regardless of process state. */
    fun isEnabled(context: Context): Boolean {
        val expected = ComponentName(context, LockAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (ComponentName.unflattenFromString(splitter.next()) == expected) return true
        }
        return false
    }

    /** Locks via the global action; false if the service is off/unsupported. */
    fun lock(): Boolean = LockAccessibilityService.lock()
}
