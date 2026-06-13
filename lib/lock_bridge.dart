import 'package:flutter/services.dart';

import 'lock_settings.dart';

/// Thin, typed wrapper around the single platform [MethodChannel] that connects
/// the Flutter UI to the native Android code. All screen-lock, overlay, and
/// persistence logic lives natively; this class only routes requests.
class LockBridge {
  LockBridge._();

  static const MethodChannel _channel = MethodChannel('one_tap_lock/channel');

  // --- Permission status ---

  /// Whether SYSTEM_ALERT_WINDOW ("display over other apps") is granted.
  static Future<bool> isOverlayGranted() async =>
      await _channel.invokeMethod<bool>('isOverlayGranted') ?? false;

  /// Whether the accessibility lock feature is compiled into this build (true
  /// only in the `advanced` flavor). Standard builds hide Biometric Lock.
  static Future<bool> isAccessibilitySupported() async =>
      await _channel.invokeMethod<bool>('isAccessibilitySupported') ?? false;

  /// Whether our accessibility service is enabled (experimental lock method).
  static Future<bool> isAccessibilityEnabled() async =>
      await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  /// Whether our Device Admin is active (fallback lock method).
  static Future<bool> isAdminActive() async =>
      await _channel.invokeMethod<bool>('isAdminActive') ?? false;

  /// Whether the floating-button foreground service is currently running.
  static Future<bool> isServiceRunning() async =>
      await _channel.invokeMethod<bool>('isServiceRunning') ?? false;

  // --- Open system settings ---

  static Future<void> openOverlaySettings() =>
      _channel.invokeMethod('openOverlaySettings');

  static Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  static Future<void> requestAdmin() => _channel.invokeMethod('requestAdmin');

  // --- Settings persistence (native SharedPreferences) ---

  static Future<LockSettings> getSettings() async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>('getSettings');
    return map == null ? LockSettings.defaults : LockSettings.fromMap(map);
  }

  /// Persists settings natively and live-refreshes the button if running.
  static Future<void> saveSettings(LockSettings settings) =>
      _channel.invokeMethod('saveSettings', settings.toMap());

  // --- Service control ---

  /// Starts the floating lock button. Throws a [PlatformException] if a required
  /// permission for the selected lock method is missing.
  static Future<void> startService() => _channel.invokeMethod('startService');

  static Future<void> stopService() => _channel.invokeMethod('stopService');
}
