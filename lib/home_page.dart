import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_bridge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _overlayGranted = false;
  bool _adminActive = false;
  bool _serviceRunning = false;
  bool _loading = true;

  bool get _ready => _overlayGranted && _adminActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when returning from a system settings screen.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final overlay = await LockBridge.isOverlayGranted();
      final admin = await LockBridge.isAdminActive();
      final running = await LockBridge.isServiceRunning();
      if (!mounted) return;
      setState(() {
        _overlayGranted = overlay;
        _adminActive = admin;
        _serviceRunning = running;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleService() async {
    if (!_ready) {
      _snack('Grant both permissions first.');
      return;
    }
    try {
      if (_serviceRunning) {
        await LockBridge.stopService();
      } else {
        await LockBridge.startService();
      }
    } on PlatformException catch (e) {
      _snack(e.message ?? 'Could not change the floating button state.');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('One Tap Lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A small floating button stays on the right edge of your '
                    'screen. Tap it to lock the screen — a software replacement '
                    'for the power button.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Two one-time permissions are required:',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _PermissionTile(
                    title: 'Display over other apps',
                    subtitle: 'Lets the floating button stay visible on top.',
                    granted: _overlayGranted,
                    actionLabel: 'Grant overlay',
                    onAction: () => LockBridge.openOverlaySettings(),
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    title: 'Device admin (lock screen)',
                    subtitle:
                        'Lets the app lock the screen. Only the "lock screen" '
                        'policy is used.',
                    granted: _adminActive,
                    actionLabel: 'Enable admin',
                    onAction: () => LockBridge.requestAdmin(),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _ready ? _toggleService : null,
                    icon: Icon(
                      _serviceRunning ? Icons.stop_circle : Icons.lock,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    label: Text(
                      _serviceRunning
                          ? 'Stop floating button'
                          : 'Start floating button',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _serviceRunning
                        ? 'Floating button is active. Drag it vertically; tap to lock.'
                        : _ready
                            ? 'Ready. Tap Start to show the floating button.'
                            : 'Grant both permissions above to enable.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tip: set a PIN/pattern lock so the screen locks securely. '
                    'On ColorOS, allow background activity and auto-launch so the '
                    'button survives. After a reboot, open this app and tap Start.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A single permission row: status icon, description, and a fix button that is
/// hidden once the permission is granted.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.error_outline,
              color: granted ? Colors.green : theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!granted)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
