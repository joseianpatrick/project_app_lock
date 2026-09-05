import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/platform/app_lock/method_channel_app_lock_gateway.dart';
import 'package:project_app_lock/platform/app_lock/system_app_lock_gateway.dart';

void main() {
  const channel = MethodChannel('com.focuslock/app_lock');
  final gateway = MethodChannelAppLockGateway(channel: channel);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('serializes the selected-only policy explicitly', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    await gateway.startLockSession(
      packageIds: const <String>['com.example.distraction'],
      endsAt: DateTime.utc(2026, 9, 5, 10),
      policy: ExternalAppLockPolicy.selectedOnly,
    );

    expect(received?.method, 'startLockSession');
    expect(
      received?.arguments,
      containsPair('externalAppPolicy', 'selected_only'),
    );
  });

  test('serializes the all-eligible policy explicitly', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    await gateway.startLockSession(
      packageIds: const <String>['com.example.distraction'],
      endsAt: DateTime.utc(2026, 9, 5, 10),
      policy: ExternalAppLockPolicy.allEligible,
    );

    expect(
      received?.arguments,
      containsPair('externalAppPolicy', 'all_eligible'),
    );
  });

  test('preserves typed platform errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'invalid_external_policy');
        });

    expect(
      () => gateway.startLockSession(
        packageIds: const <String>['com.example.distraction'],
        endsAt: DateTime.utc(2026, 9, 5, 10),
        policy: ExternalAppLockPolicy.allEligible,
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_external_policy',
        ),
      ),
    );
  });
}
