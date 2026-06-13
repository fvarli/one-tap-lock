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
    // Stub the native channel so HomePage's startup load/permission checks
    // resolve to safe defaults instead of throwing in the test environment.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isAccessibilitySupported':
          return accessibilitySupported;
        case 'getSettings':
          // Native default is Standard (Device Admin) lock.
          return <String, Object>{
            'lock_method': 'device_admin',
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

  testWidgets('standard flavor hides the Biometric Lock option entirely',
      (tester) async {
    accessibilitySupported = false; // standard APK
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    expect(find.text('Standard Lock'), findsOneWidget);
    // No experimental option and no accessibility status in the standard build.
    expect(find.text('Biometric Lock (Experimental)'), findsNothing);
    expect(find.text('Accessibility service'), findsNothing);
    expect(find.text('Device admin (lock screen)'), findsOneWidget);
  });

  testWidgets('advanced flavor shows Biometric Lock and gates it behind a warning',
      (tester) async {
    accessibilitySupported = true; // advanced APK
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    expect(find.text('Biometric Lock (Experimental)'), findsOneWidget);

    // Selecting it must show a warning dialog; cancelling changes nothing.
    await tester.tap(find.text('Biometric Lock (Experimental)'));
    await tester.pumpAndSettle();
    expect(find.text('Enable Biometric Lock?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'saveSettings'), isFalse);

    // Confirming persists the Accessibility method.
    await tester.tap(find.text('Biometric Lock (Experimental)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand, continue'));
    await tester.pumpAndSettle();

    final saved = calls.where((c) => c.method == 'saveSettings').toList();
    expect(saved, isNotEmpty);
    expect((saved.last.arguments as Map)['lock_method'], 'accessibility');
    expect(find.text('Accessibility service'), findsOneWidget);
  });
}
