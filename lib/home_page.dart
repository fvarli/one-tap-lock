import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_bridge.dart';
import 'lock_settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  LockSettings _settings = LockSettings.defaults;
  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;
  bool _adminActive = false;
  bool _serviceRunning = false;
  bool _loading = true;

  /// Whether the lock mechanism for the selected method is ready.
  bool get _lockReady =>
      _settings.usesAccessibility ? _accessibilityEnabled : _adminActive;

  bool get _ready => _overlayGranted && _lockReady;

  /// Show the Device Admin tile when it is the selected method, or when it is
  /// needed as a fallback because Accessibility is selected but not enabled.
  bool get _showAdminTile =>
      !_settings.usesAccessibility ||
      (_settings.usesAccessibility && !_accessibilityEnabled);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when returning from a system settings screen.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _load() async {
    try {
      _settings = await LockBridge.getSettings();
    } catch (_) {
      _settings = LockSettings.defaults;
    }
    await _refreshStatus();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshStatus() async {
    try {
      final overlay = await LockBridge.isOverlayGranted();
      final accessibility = await LockBridge.isAccessibilityEnabled();
      final admin = await LockBridge.isAdminActive();
      final running = await LockBridge.isServiceRunning();
      if (!mounted) return;
      setState(() {
        _overlayGranted = overlay;
        _accessibilityEnabled = accessibility;
        _adminActive = admin;
        _serviceRunning = running;
      });
    } catch (_) {/* keep last known state */}
  }

  Future<void> _update(LockSettings next) async {
    setState(() => _settings = next);
    try {
      await LockBridge.saveSettings(next);
    } on PlatformException catch (e) {
      _snack(e.message ?? 'Could not save settings.');
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
      _snack(_settings.usesAccessibility
          ? 'Grant overlay and enable the accessibility service first.'
          : 'Grant overlay and enable device admin first.');
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
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('One Tap Lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _intro(),
                  const SizedBox(height: 20),
                  _section('Lock method'),
                  _lockMethodSelector(),
                  const SizedBox(height: 16),
                  _section('Permissions'),
                  ..._statusTiles(),
                  const SizedBox(height: 20),
                  _section('Floating button'),
                  ..._behaviorSettings(),
                  const SizedBox(height: 12),
                  ..._appearanceSettings(),
                  const SizedBox(height: 24),
                  _startButton(),
                ],
              ),
            ),
    );
  }

  // --- Sections ----------------------------------------------------------

  Widget _intro() => Text(
        'A small floating button stays on the chosen screen edge. Tap it to '
        'lock the screen — a software replacement for the power button.',
        style: Theme.of(context).textTheme.bodyMedium,
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );

  Widget _lockMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: LockSettings.methodAccessibility,
              label: Text('Accessibility'),
              icon: Icon(Icons.accessibility_new),
            ),
            ButtonSegment(
              value: LockSettings.methodDeviceAdmin,
              label: Text('Device Admin'),
              icon: Icon(Icons.admin_panel_settings),
            ),
          ],
          selected: {_settings.lockMethod},
          onSelectionChanged: (s) =>
              _update(_settings.copyWith(lockMethod: s.first)),
        ),
        const SizedBox(height: 6),
        Text(
          _settings.usesAccessibility
              ? 'Recommended for Android 9+. Biometric unlock can keep working.'
              : 'Fallback / legacy. Locking this way may require PIN/password on '
                  'unlock (biometrics may not appear).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _settings.usesAccessibility
                    ? Theme.of(context).hintColor
                    : Theme.of(context).colorScheme.error,
              ),
        ),
      ],
    );
  }

  List<Widget> _statusTiles() {
    return [
      _PermissionTile(
        title: 'Display over other apps',
        subtitle: 'Lets the floating button stay visible on top.',
        granted: _overlayGranted,
        actionLabel: 'Grant',
        onAction: LockBridge.openOverlaySettings,
      ),
      if (_settings.usesAccessibility) ...[
        const SizedBox(height: 10),
        _PermissionTile(
          title: 'Accessibility service',
          subtitle: 'Locks the screen without forcing PIN. Privacy-minimal: it '
              'does not read screen content.',
          granted: _accessibilityEnabled,
          actionLabel: 'Enable',
          onAction: LockBridge.openAccessibilitySettings,
        ),
      ],
      if (_showAdminTile) ...[
        const SizedBox(height: 10),
        _PermissionTile(
          title: _settings.usesAccessibility
              ? 'Device admin (fallback)'
              : 'Device admin (lock screen)',
          subtitle: 'Used only to lock. May require PIN/password on unlock.',
          granted: _adminActive,
          actionLabel: 'Enable',
          onAction: LockBridge.requestAdmin,
        ),
      ],
    ];
  }

  List<Widget> _behaviorSettings() {
    return [
      _LabeledRow(
        label: 'Tap mode',
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'single', label: Text('Single')),
            ButtonSegment(value: 'double', label: Text('Double')),
          ],
          selected: {_settings.tapMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              _update(_settings.copyWith(tapMode: s.first)),
        ),
      ),
      const SizedBox(height: 12),
      _LabeledRow(
        label: 'Edge',
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'left', label: Text('Left')),
            ButtonSegment(value: 'right', label: Text('Right')),
          ],
          selected: {_settings.edge},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _update(_settings.copyWith(edge: s.first)),
        ),
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Haptic feedback'),
        subtitle: const Text('Short vibration when locking.'),
        value: _settings.haptic,
        onChanged: (v) => _update(_settings.copyWith(haptic: v)),
      ),
      Text(
        'Long-press the button to open this screen.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
      ),
    ];
  }

  List<Widget> _appearanceSettings() {
    return [
      _slider(
        label: 'Size',
        value: _settings.sizeDp.toDouble(),
        min: 36,
        max: 60,
        suffix: '${_settings.sizeDp}dp',
        onChanged: (v) =>
            _update(_settings.copyWith(sizeDp: v.round())),
      ),
      _slider(
        label: 'Opacity',
        value: _settings.opacity.toDouble(),
        min: 20,
        max: 80,
        suffix: '${_settings.opacity}%',
        onChanged: (v) =>
            _update(_settings.copyWith(opacity: v.round())),
      ),
      _slider(
        label: 'Edge margin',
        value: _settings.marginDp.toDouble(),
        min: 0,
        max: 12,
        suffix: '${_settings.marginDp}dp',
        onChanged: (v) =>
            _update(_settings.copyWith(marginDp: v.round())),
      ),
    ];
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: suffix,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(suffix, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  Widget _startButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _ready ? _toggleService : null,
          icon: Icon(_serviceRunning ? Icons.stop_circle : Icons.lock),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          label: Text(
            _serviceRunning ? 'Stop floating button' : 'Start floating button',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _serviceRunning
              ? 'Active. Drag vertically; tap to lock; long-press to open.'
              : _ready
                  ? 'Ready. Tap Start to show the floating button.'
                  : 'Grant the permissions above to enable.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A permission row: status icon, description, and a fix button hidden once granted.
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

/// A label paired with a control on the right (used for segmented toggles).
class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        child,
      ],
    );
  }
}
