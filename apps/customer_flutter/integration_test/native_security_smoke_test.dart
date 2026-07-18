import 'dart:convert';
import 'dart:io';

import 'package:customer_flutter/core/security/screen_security_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native screen-security bridge preserves route policy', (
    tester,
  ) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final service = ScreenSecurityService();

    await service.enable(
      route: '/my-wallet',
      overlayTitle: 'Protected content',
      overlayDescription: 'Unlock to continue',
      androidFlagSecure: true,
      androidProtectRecentAppPreview: true,
      iosScreenshotPolicy: 'lock_and_blank',
      iosScreenCaptureOverlay: true,
    );
    const holdSeconds = int.fromEnvironment('NATIVE_SECURITY_HOLD_SECONDS');
    if (holdSeconds > 0) {
      stdout.writeln('NATIVE_SCREEN_POLICY_READY:/my-wallet');
      await Future<void>.delayed(Duration(seconds: holdSeconds));
    }
    final eventFuture = service.events.first.timeout(
      const Duration(seconds: 10),
    );
    await service.reportSecurityEvent(
      event: 'screen_capture_active',
      route: '/my-wallet',
      reason: 'native_integration_smoke',
    );

    final event = await eventFuture;
    expect(event.event, 'screen_capture_active');
    expect(event.route, '/my-wallet');
    expect(event.reason, 'native_integration_smoke');

    await service.disable();
  });

  testWidgets(
    'native biometric key signs and clears a challenge',
    (tester) async {
      if (!Platform.isIOS && !Platform.isAndroid) return;

      const keyChannel = MethodChannel('customer_flutter/biometric_keys');
      final localAuth = LocalAuthentication();
      addTearDown(() async {
        try {
          await keyChannel.invokeMethod<bool>('deleteKeyPair');
        } on PlatformException {
          // The assertion below reports the useful native failure first.
        }
      });

      expect(await localAuth.isDeviceSupported(), isTrue);
      expect(await localAuth.canCheckBiometrics, isTrue);
      expect(await localAuth.getAvailableBiometrics(), isNotEmpty);

      await keyChannel.invokeMethod<bool>('deleteKeyPair');
      final created = _stringMap(
        await keyChannel.invokeMethod<Object?>('createKeyPair', {
          'platform': Platform.isIOS ? 'ios' : 'android',
          'deviceName': 'native-security-integration-smoke',
        }),
      );
      final deviceId = created['deviceId']?.toString().trim() ?? '';
      final publicKey = created['publicKeyPem']?.toString().trim() ?? '';
      expect(deviceId, isNotEmpty);
      expect(publicKey, startsWith('-----BEGIN PUBLIC KEY-----'));
      expect(created['algorithm'], 'ES256');
      expect(
        await keyChannel.invokeMethod<String>('existingDeviceId'),
        deviceId,
      );

      if (Platform.isAndroid) {
        stdout.writeln('NATIVE_BIOMETRIC_PROMPT_READY:android');
        final authenticated = await localAuth.authenticate(
          localizedReason: 'Confirm the native security integration test',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        expect(authenticated, isTrue);
      } else {
        stdout.writeln('NATIVE_BIOMETRIC_PROMPT_READY:ios');
      }

      final challenge =
          'native-security-${DateTime.now().microsecondsSinceEpoch}';
      final signed = _stringMap(
        await keyChannel.invokeMethod<Object?>('signChallenge', {
          'challenge': challenge,
          'purpose': 'native_security_integration_smoke',
          'localizedReason': 'Confirm the native security integration test',
          'localized_reason': 'Confirm the native security integration test',
        }),
      );
      final signature = signed['signature']?.toString().trim() ?? '';
      expect(signature, isNotEmpty);
      expect(signed['signedPayload'], challenge);
      expect(signed['algorithm'], 'ES256');
      expect(signed['deviceId'], deviceId);
      final signatureBytes = base64Decode(signature);
      expect(signatureBytes, isNotEmpty);
      expect(signatureBytes.first, 0x30);

      expect(await keyChannel.invokeMethod<bool>('deleteKeyPair'), isTrue);
      expect(await keyChannel.invokeMethod<String>('existingDeviceId'), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'Android biometric key clears after enrollment changes',
    (tester) async {
      const holdSeconds = int.fromEnvironment(
        'NATIVE_BIOMETRIC_ENROLLMENT_CHANGE_HOLD_SECONDS',
      );
      if (!Platform.isAndroid || holdSeconds <= 0) return;

      const keyChannel = MethodChannel('customer_flutter/biometric_keys');
      addTearDown(() async {
        try {
          await keyChannel.invokeMethod<bool>('deleteKeyPair');
        } on PlatformException {
          // The invalidation assertion below reports the useful failure first.
        }
      });

      await keyChannel.invokeMethod<bool>('deleteKeyPair');
      final created = _stringMap(
        await keyChannel.invokeMethod<Object?>('createKeyPair', {
          'platform': 'android',
          'deviceName': 'native-enrollment-change-smoke',
        }),
      );
      final deviceId = created['deviceId']?.toString().trim() ?? '';
      expect(deviceId, isNotEmpty);
      expect(
        await keyChannel.invokeMethod<String>('existingDeviceId'),
        deviceId,
      );

      stdout.writeln('NATIVE_BIOMETRIC_ENROLLMENT_CHANGE_READY:android');
      await Future<void>.delayed(Duration(seconds: holdSeconds));

      stdout.writeln('NATIVE_BIOMETRIC_PROMPT_READY:android-enrollment-change');
      final authenticated = await LocalAuthentication().authenticate(
        localizedReason: 'Confirm enrollment-change handling',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      expect(authenticated, isTrue);

      try {
        await keyChannel.invokeMethod<Object?>('signChallenge', {
          'challenge': 'android-enrollment-change-smoke',
          'purpose': 'native_security_integration_smoke',
        });
        fail('The enrollment-bound Android key unexpectedly remained usable.');
      } on PlatformException catch (error) {
        expect(error.code, 'biometric_key_invalidated', reason: error.message);
      }
      expect(await keyChannel.invokeMethod<String>('existingDeviceId'), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'native biometric cancellation preserves the registered key',
    (tester) async {
      const enabled = bool.fromEnvironment('NATIVE_BIOMETRIC_CANCEL_SMOKE');
      if ((!Platform.isIOS && !Platform.isAndroid) || !enabled) return;

      const keyChannel = MethodChannel('customer_flutter/biometric_keys');
      final localAuth = LocalAuthentication();
      addTearDown(() async {
        try {
          await keyChannel.invokeMethod<bool>('deleteKeyPair');
        } on PlatformException {
          // The cancellation assertion below reports the useful failure first.
        }
      });

      await keyChannel.invokeMethod<bool>('deleteKeyPair');
      final created = _stringMap(
        await keyChannel.invokeMethod<Object?>('createKeyPair', {
          'platform': Platform.isIOS ? 'ios' : 'android',
          'deviceName': 'native-cancellation-smoke',
        }),
      );
      final deviceId = created['deviceId']?.toString().trim() ?? '';
      expect(deviceId, isNotEmpty);

      stdout.writeln(
        'NATIVE_BIOMETRIC_CANCEL_PROMPT_READY:${Platform.isIOS ? 'ios' : 'android'}',
      );
      if (Platform.isAndroid) {
        final authenticated = await localAuth.authenticate(
          localizedReason: 'Cancel the native security integration test',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        expect(authenticated, isFalse);
      } else {
        try {
          await keyChannel.invokeMethod<Object?>('signChallenge', {
            'challenge': 'ios-biometric-cancellation-smoke',
            'purpose': 'native_security_integration_smoke',
            'localizedReason': 'Cancel the native security integration test',
          });
          fail('The cancelled iOS biometric operation unexpectedly signed.');
        } on PlatformException catch (error) {
          expect(error.code, 'biometric_cancelled', reason: error.message);
        }
      }

      expect(
        await keyChannel.invokeMethod<String>('existingDeviceId'),
        deviceId,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}
