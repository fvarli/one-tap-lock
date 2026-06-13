package com.ferzendervarli.one_tap_lock

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the single MethodChannel that the Flutter UI uses to check permissions,
 * open the relevant system settings, and start/stop the floating-button service.
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
                    handle(call.method, result)
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }
    }

    private fun handle(method: String, result: MethodChannel.Result) {
        when (method) {
            "isOverlayGranted" -> result.success(Settings.canDrawOverlays(this))

            "openOverlaySettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            }

            "isAdminActive" -> result.success(dpm.isAdminActive(adminComponent))

            "requestAdmin" -> {
                val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                    .putExtra(
                        DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                        "One Tap Lock needs this to lock the screen when you tap the floating button."
                    )
                startActivity(intent)
                result.success(null)
            }

            "isServiceRunning" -> result.success(LockOverlayService.isRunning)

            "startService" -> {
                if (!Settings.canDrawOverlays(this)) {
                    result.error("no_overlay", "Overlay permission not granted.", null)
                    return
                }
                if (!dpm.isAdminActive(adminComponent)) {
                    result.error("no_admin", "Device admin not enabled.", null)
                    return
                }
                val intent = Intent(this, LockOverlayService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                result.success(null)
            }

            "stopService" -> {
                stopService(Intent(this, LockOverlayService::class.java))
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
