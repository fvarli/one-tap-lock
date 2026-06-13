/// Immutable snapshot of the user-configurable settings. Mirrors the keys
/// persisted natively by `LockPrefs` on the Android side.
class LockSettings {
  static const String methodAccessibility = 'accessibility';
  static const String methodDeviceAdmin = 'device_admin';

  final String lockMethod; // accessibility | device_admin
  final String tapMode; // single | double
  final String edge; // left | right
  final int sizeDp; // 36..60
  final int opacity; // 20..80 (percent)
  final int marginDp; // 0..12
  final bool haptic;

  const LockSettings({
    required this.lockMethod,
    required this.tapMode,
    required this.edge,
    required this.sizeDp,
    required this.opacity,
    required this.marginDp,
    required this.haptic,
  });

  /// Default to Standard (Device Admin) lock; Accessibility is opt-in.
  static const LockSettings defaults = LockSettings(
    lockMethod: methodDeviceAdmin,
    tapMode: 'single',
    edge: 'right',
    sizeDp: 46,
    opacity: 60,
    marginDp: 6,
    haptic: true,
  );

  bool get usesAccessibility => lockMethod == methodAccessibility;

  factory LockSettings.fromMap(Map<dynamic, dynamic> map) {
    int clampInt(Object? v, int lo, int hi, int fallback) {
      final n = v is num ? v.toInt() : fallback;
      return n.clamp(lo, hi);
    }

    return LockSettings(
      lockMethod: map['lock_method'] == methodAccessibility
          ? methodAccessibility
          : methodDeviceAdmin,
      tapMode: map['tap_mode'] == 'double' ? 'double' : 'single',
      edge: map['edge'] == 'left' ? 'left' : 'right',
      sizeDp: clampInt(map['size_dp'], 36, 60, 46),
      opacity: clampInt(map['opacity'], 20, 80, 60),
      marginDp: clampInt(map['margin_dp'], 0, 12, 6),
      haptic: map['haptic'] is bool ? map['haptic'] as bool : true,
    );
  }

  Map<String, dynamic> toMap() => {
        'lock_method': lockMethod,
        'tap_mode': tapMode,
        'edge': edge,
        'size_dp': sizeDp,
        'opacity': opacity,
        'margin_dp': marginDp,
        'haptic': haptic,
      };

  LockSettings copyWith({
    String? lockMethod,
    String? tapMode,
    String? edge,
    int? sizeDp,
    int? opacity,
    int? marginDp,
    bool? haptic,
  }) {
    return LockSettings(
      lockMethod: lockMethod ?? this.lockMethod,
      tapMode: tapMode ?? this.tapMode,
      edge: edge ?? this.edge,
      sizeDp: sizeDp ?? this.sizeDp,
      opacity: opacity ?? this.opacity,
      marginDp: marginDp ?? this.marginDp,
      haptic: haptic ?? this.haptic,
    );
  }
}
