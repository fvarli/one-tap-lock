import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_tap_lock/main.dart';

void main() {
  const channel = MethodChannel('one_tap_lock/channel');
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    // Stub the native channel so HomePage's startup load/permission checks
    // resolve to safe defaults instead of throwing in the test environment.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
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

  testWidgets('defaults to Standard Lock with Device Admin status shown',
      (tester) async {
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    expect(find.text('One Tap Lock'), findsOneWidget);
    expect(find.text('Standard Lock'), findsOneWidget);
    expect(find.text('Biometric Lock (Experimental)'), findsOneWidget);
    // Standard is selected by default → Device Admin status tile is shown,
    // Accessibility status is hidden.
    expect(find.text('Device admin (lock screen)'), findsOneWidget);
    expect(find.text('Accessibility service'), findsNothing);
    expect(calls.any((c) => c.method == 'getSettings'), isTrue);
  });

  testWidgets('selecting Biometric Lock requires confirmation before switching',
      (tester) async {
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    // Tap the experimental option → a warning dialog must appear.
    await tester.tap(find.text('Biometric Lock (Experimental)'));
    await tester.pumpAndSettle();
    expect(find.text('Enable Biometric Lock?'), findsOneWidget);

    // Cancelling must NOT change the method.
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
    // Now Accessibility status tile is shown instead of Device Admin.
    expect(find.text('Accessibility service'), findsOneWidget);
  });
}
