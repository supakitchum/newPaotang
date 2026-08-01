import 'dart:convert';
import 'dart:io';

import 'package:customer_flutter/core/security/screen_security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native screen-security bridge preserves app-wide policy', (
    tester,
  ) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final service = ScreenSecurityService();
    const screenSecurityChannel = MethodChannel(
      'customer_flutter/screen_security',
    );
    const visualAcceptance = bool.fromEnvironment(
      'NATIVE_SECURITY_VISUAL_ACCEPTANCE',
    );
    const visualPublicSeconds = int.fromEnvironment(
      'NATIVE_SECURITY_VISUAL_PUBLIC_SECONDS',
      defaultValue: 15,
    );
    const visualProtectedSeconds = int.fromEnvironment(
      'NATIVE_SECURITY_VISUAL_PROTECTED_SECONDS',
      defaultValue: 60,
    );

    if (visualAcceptance) {
      await service.disable();
      await tester.pumpWidget(
        const _SecurityVisualProbe(
          title: 'APP-WIDE PROTECTION BASELINE',
          subtitle: 'This synthetic screen must stay protected.',
          backgroundColor: Color(0xFFFFD10B),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        final baselineState = _stringMap(
          await screenSecurityChannel.invokeMethod<Object?>('getSecurityState'),
        );
        expect(baselineState['appWideProtection'], isTrue);
        expect(baselineState['screenSecurityActive'], isTrue);
        expect(baselineState['windowFlagSecure'], isTrue);
        expect(baselineState['recentAppPreviewProtected'], isTrue);
      }
      stdout.writeln('NATIVE_SECURITY_APP_WIDE_BASELINE_READY');
      await Future<void>.delayed(Duration(seconds: visualPublicSeconds));
    }

    await service.enable(
      route: '/my-wallet',
      overlayTitle: 'Protected content',
      overlayDescription: 'Unlock to continue',
      androidFlagSecure: true,
      androidProtectRecentAppPreview: true,
      iosScreenshotPolicy: 'lock_and_blank',
      iosScreenCaptureOverlay: true,
    );
    if (Platform.isAndroid) {
      final enabledState = _stringMap(
        await screenSecurityChannel.invokeMethod<Object?>('getSecurityState'),
      );
      final sdkInt = enabledState['sdkInt'] as int? ?? 0;
      final activityStarted = enabledState['activityStarted'] == true;
      expect(enabledState['screenSecurityActive'], isTrue);
      expect(enabledState['activeRoute'], '/my-wallet');
      expect(enabledState['flagSecureConfigured'], isTrue);
      expect(enabledState['protectRecentAppPreviewConfigured'], isTrue);
      expect(enabledState['windowFlagSecure'], isTrue);
      expect(enabledState['recentAppPreviewProtected'], isTrue);
      expect(enabledState['captureTerminationScheduled'], isFalse);
      expect(
        enabledState['screenCaptureCallbackRegistered'],
        activityStarted && sdkInt >= 34,
      );
      expect(
        enabledState['screenRecordingCallbackRegistered'],
        activityStarted && sdkInt >= 35,
      );
      expect(enabledState['screenRecordingDetectionSupported'], sdkInt >= 35);
    }
    if (visualAcceptance) {
      await tester.pumpWidget(
        const _SecurityVisualProbe(
          title: 'PROTECTED CONTENT',
          subtitle: 'Screenshots, recordings, and Recents must hide this.',
          backgroundColor: Color(0xFFED1556),
        ),
      );
      await tester.pumpAndSettle();
      stdout.writeln('NATIVE_SECURITY_PROTECTED_READY');
      await Future<void>.delayed(Duration(seconds: visualProtectedSeconds));
      if (Platform.isAndroid) {
        final resumedState = _stringMap(
          await screenSecurityChannel.invokeMethod<Object?>('getSecurityState'),
        );
        expect(resumedState['activityStarted'], isTrue);
        expect(resumedState['screenSecurityActive'], isTrue);
        expect(resumedState['activeRoute'], '/my-wallet');
        expect(resumedState['windowFlagSecure'], isTrue);
        expect(resumedState['recentAppPreviewProtected'], isTrue);
      }
    }
    const holdSeconds = int.fromEnvironment('NATIVE_SECURITY_HOLD_SECONDS');
    if (holdSeconds > 0) {
      stdout.writeln('NATIVE_SCREEN_POLICY_READY:/my-wallet');
      await Future<void>.delayed(Duration(seconds: holdSeconds));
      if (Platform.isAndroid) {
        final resumedState = _stringMap(
          await screenSecurityChannel.invokeMethod<Object?>('getSecurityState'),
        );
        final sdkInt = resumedState['sdkInt'] as int? ?? 0;
        expect(resumedState['activityStarted'], isTrue);
        expect(resumedState['screenSecurityActive'], isTrue);
        expect(resumedState['activeRoute'], '/my-wallet');
        expect(resumedState['windowFlagSecure'], isTrue);
        expect(resumedState['recentAppPreviewProtected'], isTrue);
        expect(resumedState['screenCaptureCallbackRegistered'], sdkInt >= 34);
        expect(resumedState['screenRecordingCallbackRegistered'], sdkInt >= 35);
      }
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
    if (Platform.isAndroid) {
      final disabledState = _stringMap(
        await screenSecurityChannel.invokeMethod<Object?>('getSecurityState'),
      );
      final sdkInt = disabledState['sdkInt'] as int? ?? 0;
      final activityStarted = disabledState['activityStarted'] == true;
      expect(disabledState['appWideProtection'], isTrue);
      expect(disabledState['screenSecurityActive'], isTrue);
      expect(disabledState['activeRoute'], isNotEmpty);
      expect(disabledState['windowFlagSecure'], isTrue);
      expect(disabledState['recentAppPreviewProtected'], isTrue);
      expect(
        disabledState['screenCaptureCallbackRegistered'],
        activityStarted && sdkInt >= 34,
      );
      expect(
        disabledState['screenRecordingCallbackRegistered'],
        activityStarted && sdkInt >= 35,
      );
    }

    await service.enable(
      route: '/checkout',
      androidFlagSecure: true,
      androidProtectRecentAppPreview: true,
      iosScreenshotPolicy: 'lock_and_blank',
      iosScreenCaptureOverlay: true,
    );
    if (Platform.isAndroid) {
      final reenabledState = _stringMap(
        await screenSecurityChannel.invokeMethod<Object?>('getSecurityState'),
      );
      final sdkInt = reenabledState['sdkInt'] as int? ?? 0;
      final activityStarted = reenabledState['activityStarted'] == true;
      expect(reenabledState['screenSecurityActive'], isTrue);
      expect(reenabledState['activeRoute'], '/checkout');
      expect(reenabledState['windowFlagSecure'], isTrue);
      expect(reenabledState['recentAppPreviewProtected'], isTrue);
      expect(
        reenabledState['screenCaptureCallbackRegistered'],
        activityStarted && sdkInt >= 34,
      );
      expect(
        reenabledState['screenRecordingCallbackRegistered'],
        activityStarted && sdkInt >= 35,
      );
    }
    await service.disable();
  });

  testWidgets(
    'native biometric key signs and clears a challenge',
    (tester) async {
      const screenOnly = bool.fromEnvironment('NATIVE_SECURITY_SCREEN_ONLY');
      if ((!Platform.isIOS && !Platform.isAndroid) || screenOnly) return;

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

      const cancellationHoldSeconds = int.fromEnvironment(
        'NATIVE_BIOMETRIC_CANCEL_HOLD_SECONDS',
      );
      debugPrint(
        'NATIVE_BIOMETRIC_CANCEL_PROMPT_READY:'
        '${Platform.isIOS ? 'ios' : 'android'}',
      );
      if (cancellationHoldSeconds > 0) {
        await Future<void>.delayed(Duration(seconds: cancellationHoldSeconds));
      }
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

class _SecurityVisualProbe extends StatelessWidget {
  const _SecurityVisualProbe({
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
  });

  final String title;
  final String subtitle;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: const Color(0xFF087FF0),
                child: const Text(
                  'SIAMBLEND ANDROID SECURITY TEST',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF172033),
                        width: 6,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF172033),
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF3D4656),
                              fontSize: 18,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Row(
                            children: [
                              Expanded(
                                child: _SecurityColorBlock(
                                  color: Color(0xFF087FF0),
                                ),
                              ),
                              Expanded(
                                child: _SecurityColorBlock(
                                  color: Color(0xFFFFD10B),
                                ),
                              ),
                              Expanded(
                                child: _SecurityColorBlock(
                                  color: Color(0xFFED1556),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'TEST DATA ONLY - NO CUSTOMER INFORMATION',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF087FF0),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityColorBlock extends StatelessWidget {
  const _SecurityColorBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color, child: const SizedBox(height: 72));
  }
}
