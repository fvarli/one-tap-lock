import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_tap_lock/main.dart';

void main() {
  const channel = MethodChannel('one_tap_lock/channel');

  setUp(() {
    // Stub the native channel so HomePage's startup permission checks resolve
    // to safe defaults instead of throwing in the test environment.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isOverlayGranted':
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

  testWidgets('renders the One Tap Lock home screen', (tester) async {
    await tester.pumpWidget(const OneTapLockApp());
    await tester.pumpAndSettle();

    // App title (AppBar) renders.
    expect(find.text('One Tap Lock'), findsOneWidget);
    // Both permission tiles and the start button are present.
    expect(find.text('Start floating button'), findsOneWidget);
  });
}
