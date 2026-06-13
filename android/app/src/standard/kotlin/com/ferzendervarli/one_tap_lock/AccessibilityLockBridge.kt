package com.ferzendervarli.one_tap_lock

import android.content.Context

/**
 * STANDARD (no-accessibility) implementation. There is no AccessibilityService in
 * this flavor, so the bridge is an inert stub: the UI never offers Biometric Lock,
 * and any lock request falls through to Device Admin.
 */
object AccessibilityLockBridge {

    /** Whether accessibility lock is compiled into this build. */
    const val isSupported: Boolean = false

    fun isEnabled(context: Context): Boolean = false

    fun lock(): Boolean = false
}
