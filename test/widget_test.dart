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
          return <String, Object>{
            'lock_method': 'accessibility',
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

  testWidgets('renders the home screen with default Accessibility method',
      (tester) async {
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    expect(find.text('One Tap Lock'), findsOneWidget);
    expect(find.text('Start floating button'), findsOneWidget);
    // Default method is Accessibility, so its status tile is shown.
    expect(find.text('Accessibility service'), findsOneWidget);
    // Settings were loaded from the native side on startup.
    expect(calls.any((c) => c.method == 'getSettings'), isTrue);
  });

  testWidgets('switching to Device Admin persists the setting',
      (tester) async {
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Device Admin'));
    await tester.pumpAndSettle();

    final saved = calls.where((c) => c.method == 'saveSettings').toList();
    expect(saved, isNotEmpty);
    expect((saved.last.arguments as Map)['lock_method'], 'device_admin');
  });
}
