package com.ferzendervarli.one_tap_lock

import android.content.Context

/**
 * Single source of truth for all persisted settings (native SharedPreferences).
 * Both MainActivity (writes from the Flutter UI) and LockOverlayService (reads
 * when building the button) go through here so keys and defaults never drift.
 */
object LockPrefs {
    const val FILE = "otl_prefs"

    const val KEY_Y = "btn_y"
    const val KEY_METHOD = "lock_method"   // "accessibility" | "device_admin"
    const val KEY_TAP = "tap_mode"         // "single" | "double"
    const val KEY_EDGE = "edge"            // "left" | "right"
    const val KEY_SIZE = "size_dp"         // 36..60
    const val KEY_OPACITY = "opacity"      // 20..80 (percent)
    const val KEY_MARGIN = "margin_dp"     // 0..12
    const val KEY_HAPTIC = "haptic"        // boolean

    const val METHOD_ACCESSIBILITY = "accessibility"
    const val METHOD_DEVICE_ADMIN = "device_admin"

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    // Per-flavor default: the advanced build (accessibility compiled in) defaults
    // to Biometric/Accessibility; the standard build defaults to Device Admin.
    private val defaultMethod: String
        get() = if (AccessibilityLockBridge.isSupported) METHOD_ACCESSIBILITY
        else METHOD_DEVICE_ADMIN

    fun method(ctx: Context): String =
        prefs(ctx).getString(KEY_METHOD, defaultMethod) ?: defaultMethod

    fun tapMode(ctx: Context): String =
        prefs(ctx).getString(KEY_TAP, "single") ?: "single"

    fun edge(ctx: Context): String =
        prefs(ctx).getString(KEY_EDGE, "right") ?: "right"

    fun sizeDp(ctx: Context): Int = prefs(ctx).getInt(KEY_SIZE, 46).coerceIn(36, 60)

    fun opacity(ctx: Context): Int = prefs(ctx).getInt(KEY_OPACITY, 60).coerceIn(20, 80)

    fun marginDp(ctx: Context): Int = prefs(ctx).getInt(KEY_MARGIN, 6).coerceIn(0, 12)

    fun haptic(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_HAPTIC, true)

    fun y(ctx: Context, default: Int): Int = prefs(ctx).getInt(KEY_Y, default)

    fun saveY(ctx: Context, value: Int) {
        prefs(ctx).edit().putInt(KEY_Y, value).apply()
    }

    /** Snapshot of all UI-controlled settings, sent to Flutter. */
    fun asMap(ctx: Context): Map<String, Any> = mapOf(
        KEY_METHOD to method(ctx),
        KEY_TAP to tapMode(ctx),
        KEY_EDGE to edge(ctx),
        KEY_SIZE to sizeDp(ctx),
        KEY_OPACITY to opacity(ctx),
        KEY_MARGIN to marginDp(ctx),
        KEY_HAPTIC to haptic(ctx),
    )

    /** Persists any subset of the UI-controlled keys coming from Flutter. */
    fun write(ctx: Context, values: Map<*, *>) {
        val editor = prefs(ctx).edit()
        (values[KEY_METHOD] as? String)?.let { editor.putString(KEY_METHOD, it) }
        (values[KEY_TAP] as? String)?.let { editor.putString(KEY_TAP, it) }
        (values[KEY_EDGE] as? String)?.let { editor.putString(KEY_EDGE, it) }
        (values[KEY_SIZE] as? Number)?.let { editor.putInt(KEY_SIZE, it.toInt()) }
        (values[KEY_OPACITY] as? Number)?.let { editor.putInt(KEY_OPACITY, it.toInt()) }
        (values[KEY_MARGIN] as? Number)?.let { editor.putInt(KEY_MARGIN, it.toInt()) }
        (values[KEY_HAPTIC] as? Boolean)?.let { editor.putBoolean(KEY_HAPTIC, it) }
        editor.apply()
    }
}
