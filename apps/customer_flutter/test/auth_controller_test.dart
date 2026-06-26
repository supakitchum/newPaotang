import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthController newController() {
    final tokenStore = AuthTokenStore();
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
    );
    return AuthController(
      authRepository: AuthRepository(api: api, tokenStore: tokenStore),
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );
  }

  test('app lifecycle lock requires PIN only for authenticated sessions', () {
    final guest = newController();

    guest.lockForAppLifecycle();

    expect(guest.pinRequired, isFalse);

    final customer = newController()
      ..isAuthenticated = true
      ..pinRequired = false;

    customer.lockForAppLifecycle();

    expect(customer.pinRequired, isTrue);
  });

  test('app lifecycle lock leaves already locked sessions unchanged', () {
    final customer = newController()
      ..isAuthenticated = true
      ..pinRequired = true;

    customer.lockForAppLifecycle();

    expect(customer.pinRequired, isTrue);
    expect(customer.isSecurityLocked, isFalse);
  });
}
