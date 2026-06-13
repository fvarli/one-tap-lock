import 'package:flutter/services.dart';

/// Thin, typed wrapper around the single platform [MethodChannel] that connects
/// the Flutter UI to the native Android code. All screen-lock and overlay logic
/// lives natively; this class only routes requests and reports permission state.
class LockBridge {
  LockBridge._();

  static const MethodChannel _channel =
      MethodChannel('one_tap_lock/channel');

  /// Whether SYSTEM_ALERT_WINDOW ("display over other apps") is granted.
  static Future<bool> isOverlayGranted() async {
    return await _channel.invokeMethod<bool>('isOverlayGranted') ?? false;
  }

  /// Opens the system "display over other apps" settings page for this app.
  static Future<void> openOverlaySettings() {
    return _channel.invokeMethod('openOverlaySettings');
  }

  /// Whether our Device Admin is active (required for lockNow()).
  static Future<bool> isAdminActive() async {
    return await _channel.invokeMethod<bool>('isAdminActive') ?? false;
  }

  /// Launches the system dialog to activate our Device Admin.
  static Future<void> requestAdmin() {
    return _channel.invokeMethod('requestAdmin');
  }

  /// Whether the floating-button foreground service is currently running.
  static Future<bool> isServiceRunning() async {
    return await _channel.invokeMethod<bool>('isServiceRunning') ?? false;
  }

  /// Starts the floating lock button. Throws a [PlatformException] if a required
  /// permission is missing (handled by the caller).
  static Future<void> startService() {
    return _channel.invokeMethod('startService');
  }

  /// Stops the floating lock button and removes the overlay.
  static Future<void> stopService() {
    return _channel.invokeMethod('stopService');
  }
}
