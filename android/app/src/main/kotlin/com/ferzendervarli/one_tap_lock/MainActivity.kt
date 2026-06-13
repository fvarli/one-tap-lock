package com.ferzendervarli.one_tap_lock

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the single MethodChannel that the Flutter UI uses to read/write
 * settings, check permissions, open the relevant system settings screens, and
 * start/stop the floating-button service.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "one_tap_lock/channel"

    private val adminComponent: ComponentName
        get() = ComponentName(this, LockDeviceAdminReceiver::class.java)

    private val dpm: DevicePolicyManager
        get() = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    handle(call, result)
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // --- Permission status ---
            "isOverlayGranted" -> result.success(Settings.canDrawOverlays(this))
            "isAdminActive" -> result.success(dpm.isAdminActive(adminComponent))
            "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
            "isServiceRunning" -> result.success(LockOverlayService.isRunning)

            // --- Open system settings ---
            "openOverlaySettings" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            }

            "requestAdmin" -> {
                startActivity(
                    Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                        .putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "One Tap Lock needs this only as a fallback to lock the screen."
                        )
                )
                result.success(null)
            }

            "openAccessibilitySettings" -> {
                startActivity(
                    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            }

            // --- Settings ---
            "getSettings" -> result.success(LockPrefs.asMap(this))

            "saveSettings" -> {
                @Suppress("UNCHECKED_CAST")
                val values = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                LockPrefs.write(this, values)
                // Apply appearance/behaviour changes to the live button immediately.
                if (LockOverlayService.isRunning) {
                    startService(
                        Intent(this, LockOverlayService::class.java)
                            .setAction(LockOverlayService.ACTION_REFRESH)
                    )
                }
                result.success(null)
            }

            // --- Service control ---
            "startService" -> startServiceChecked(result)

            "stopService" -> {
                stopService(Intent(this, LockOverlayService::class.java))
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun startServiceChecked(result: MethodChannel.Result) {
        if (!Settings.canDrawOverlays(this)) {
            result.error("no_overlay", "Overlay permission not granted.", null)
            return
        }
        // Require the lock mechanism for the selected method to be ready.
        if (LockPrefs.method(this) == LockPrefs.METHOD_ACCESSIBILITY) {
            if (!isAccessibilityEnabled()) {
                result.error("no_accessibility", "Enable the accessibility service first.", null)
                return
            }
        } else {
            if (!dpm.isAdminActive(adminComponent)) {
                result.error("no_admin", "Enable device admin first.", null)
                return
            }
        }
        val intent = Intent(this, LockOverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        result.success(null)
    }

    /** Reads the secure setting so status is correct regardless of process state. */
    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(this, LockAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            val component = ComponentName.unflattenFromString(splitter.next())
            if (component == expected) return true
        }
        return false
    }
}
