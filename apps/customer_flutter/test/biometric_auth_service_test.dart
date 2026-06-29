import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('biometric challenge parser accepts standard data payload', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'challenge_id': 'challenge-1',
        'challenge': 'payload-to-sign',
      },
    });

    expect(payload.challengeId, 'challenge-1');
    expect(payload.challenge, 'payload-to-sign');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts legacy result payload', () {
    final payload = BiometricChallengePayload.fromResponse({
      'result': {
        'challenge_id': 'challenge-2',
        'challenge': 'legacy-payload',
      },
    });

    expect(payload.challengeId, 'challenge-2');
    expect(payload.challenge, 'legacy-payload');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser rejects incomplete payloads', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {'challenge_id': 'challenge-3'},
    });

    expect(payload.isComplete, isFalse);
  });

  test('biometric pin assertion parser accepts multiple API wrappers', () {
    expect(
      biometricPinAssertionTokenFromResponse({
        'data': {'pin_assertion_token': 'data-token'},
      }),
      'data-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'result': {'pin_assertion_token': 'result-token'},
      }),
      'result-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'resource': {'pin_assertion_token': 'resource-token'},
      }),
      'resource-token',
    );
  });
}
