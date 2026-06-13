import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_tap_lock/main.dart';

void main() {
  const channel = MethodChannel('one_tap_lock/channel');
  final List<MethodCall> calls = [];

  // Simulates the native flavor: false = standard APK, true = advanced APK.
  bool accessibilitySupported = false;

  setUp(() {
    calls.clear();
    accessibilitySupported = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isAccessibilitySupported':
          return accessibilitySupported;
        case 'getSettings':
          // Mirror the native per-flavor default lock method.
          return <String, Object>{
            'lock_method':
                accessibilitySupported ? 'accessibility' : 'device_admin',
            'tap_mode': 'single',
            'edge': 'right',
            'size_dp': 46,
            'opacity': 60,
            'margin_dp': 6,
            'haptic': true,
          };
        case 'isOverlayGranted':
        case 'isAccessibilityEnabled':
        case 'isAdminActive':
        case 'isServiceRunning':
          return false;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('standard flavor: Device Admin default, no Biometric, no notice',
      (tester) async {
    accessibilitySupported = false; // standard APK
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    expect(find.text('Standard Lock'), findsOneWidget);
    expect(find.text('Biometric Lock (Experimental)'), findsNothing);
    expect(find.text('Accessibility service'), findsNothing);
    expect(find.text('Device admin (lock screen)'), findsOneWidget);
    expect(find.textContaining('Use Advanced only'), findsNothing);
  });

  testWidgets('advanced flavor: Biometric is the default and notice is shown',
      (tester) async {
    accessibilitySupported = true; // advanced APK
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    // Default lock method is Biometric/Accessibility.
    expect(find.text('Biometric Lock (Experimental)'), findsOneWidget);
    expect(find.text('Accessibility service'), findsOneWidget);
    // The advanced warning notice is present.
    expect(find.textContaining('Use Advanced only'), findsOneWidget);
    expect(
      find.textContaining('Google Play Protect may warn'),
      findsOneWidget,
    );
  });

  testWidgets('advanced flavor: re-selecting Biometric is gated by a warning',
      (tester) async {
    accessibilitySupported = true;
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    // Switch to Standard (no dialog), then back to Biometric (warning dialog).
    await tester.tap(find.text('Standard Lock'));
    await tester.pumpAndSettle();
    expect(find.text('Device admin (lock screen)'), findsOneWidget);

    await tester.tap(find.text('Biometric Lock (Experimental)'));
    await tester.pumpAndSettle();
    expect(find.text('Enable Biometric Lock?'), findsOneWidget);
    await tester.tap(find.text('I understand, continue'));
    await tester.pumpAndSettle();

    final saved = calls.where((c) => c.method == 'saveSettings').toList();
    expect(saved, isNotEmpty);
    expect((saved.last.arguments as Map)['lock_method'], 'accessibility');
  });
}
