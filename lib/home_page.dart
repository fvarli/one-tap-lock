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
  bool _advancedAvailable = false; // true only in the `advanced` flavor
  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;
  bool _adminActive = false;
  bool _serviceRunning = false;
  bool _loading = true;

  /// Whether the lock mechanism for the selected method is ready.
  bool get _lockReady =>
      _settings.usesAccessibility ? _accessibilityEnabled : _adminActive;

  bool get _ready => _overlayGranted && _lockReady;

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
      _advancedAvailable = await LockBridge.isAccessibilitySupported();
      _settings = await LockBridge.getSettings();
    } catch (_) {
      _advancedAvailable = false;
      _settings = LockSettings.defaults;
    }
    // In the standard flavor accessibility doesn't exist — never run as Biometric.
    if (!_advancedAvailable && _settings.usesAccessibility) {
      _settings =
          _settings.copyWith(lockMethod: LockSettings.methodDeviceAdmin);
      await LockBridge.saveSettings(_settings);
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
                  if (_advancedAvailable) ...[
                    const SizedBox(height: 14),
                    _advancedNotice(),
                  ],
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

  /// Advanced-flavor notice explaining the biometric trade-off up front.
  Widget _advancedNotice() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Use Advanced only if you want fingerprint/face unlock after '
              'locking. Google Play Protect may warn because Android treats '
              'accessibility + overlay as sensitive.',
            ),
          ),
        ],
      ),
    );
  }

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
        _MethodCard(
          title: 'Standard Lock',
          lines: const [
            'Uses Device Admin.',
            'More secure and simple.',
            'May require PIN/password after locking.',
          ],
          selected: !_settings.usesAccessibility,
          onTap: () => _onSelectMethod(LockSettings.methodDeviceAdmin),
        ),
        // Biometric Lock exists only in the advanced flavor.
        if (_advancedAvailable) ...[
          const SizedBox(height: 10),
          _MethodCard(
            title: 'Biometric Lock (Experimental)',
            experimental: true,
            lines: const [
              'Uses Accessibility.',
              'May allow fingerprint/face unlock after locking on some devices.',
              'Google Play Protect may show a warning.',
              'Use only if you understand the trade-off.',
            ],
            selected: _settings.usesAccessibility,
            onTap: () => _onSelectMethod(LockSettings.methodAccessibility),
          ),
        ],
      ],
    );
  }

  /// Switches the lock method. Selecting the experimental Biometric (Accessibility)
  /// method requires explicit confirmation of the Play Protect trade-off first.
  Future<void> _onSelectMethod(String method) async {
    if (method == _settings.lockMethod) return;

    if (method == LockSettings.methodAccessibility) {
      final confirmed = await _confirmBiometric();
      if (confirmed != true) return; // keep Standard Lock
      await _update(_settings.copyWith(lockMethod: method));
      // Guide the user straight to enabling the service.
      if (!_accessibilityEnabled) {
        await LockBridge.openAccessibilitySettings();
      }
    } else {
      await _update(_settings.copyWith(lockMethod: method));
    }
  }

  Future<bool?> _confirmBiometric() {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber, color: theme.colorScheme.error),
        title: const Text('Enable Biometric Lock?'),
        content: const Text(
          'This experimental method uses an Accessibility service to lock the '
          'screen so fingerprint/face unlock can keep working on some devices.\n\n'
          'Google Play Protect may warn about or block APKs that use an '
          'Accessibility service together with a screen overlay. This is a known '
          'trade-off, not a malfunction.\n\n'
          'The service stays privacy-minimal: it never reads screen content and '
          'only triggers the lock action.\n\n'
          'Continue only if you understand this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('I understand, continue'),
          ),
        ],
      ),
    );
  }

  List<Widget> _statusTiles() {
    return [
      _PermissionTile(
        title: 'Display over other apps',
        subtitle: 'Required for both lock methods so the button stays on top.',
        granted: _overlayGranted,
        actionLabel: 'Grant',
        onAction: LockBridge.openOverlaySettings,
      ),
      const SizedBox(height: 10),
      // Standard Lock → show Device Admin status; Biometric → show Accessibility.
      if (_settings.usesAccessibility)
        _PermissionTile(
          title: 'Accessibility service',
          subtitle: 'Privacy-minimal: it does not read screen content and only '
              'triggers the lock action.',
          granted: _accessibilityEnabled,
          actionLabel: 'Enable',
          onAction: LockBridge.openAccessibilitySettings,
        )
      else
        _PermissionTile(
          title: 'Device admin (lock screen)',
          subtitle: 'Used only to lock. May require PIN/password on unlock.',
          granted: _adminActive,
          actionLabel: 'Enable',
          onAction: LockBridge.requestAdmin,
        ),
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

/// A selectable lock-method option card showing a title and bullet description.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.title,
    required this.lines,
    required this.selected,
    required this.onTap,
    this.experimental = false,
  });

  final String title;
  final List<String> lines;
  final bool selected;
  final bool experimental;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        experimental ? theme.colorScheme.error : theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? accent.withValues(alpha: 0.10) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? accent : theme.dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? accent : theme.hintColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...lines.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text('•  $l',
                            style: theme.textTheme.bodySmall),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
