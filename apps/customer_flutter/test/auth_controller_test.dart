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

  test('logout clears local auth state even when remote logout fails',
      () async {
    final tokenStore = AuthTokenStore();
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
    );
    final controller = AuthController(
      authRepository:
          _FailingLogoutRepository(api: api, tokenStore: tokenStore),
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    )
      ..isAuthenticated = true
      ..pinRequired = true
      ..pinSetupRequired = true
      ..isSecurityLocked = true;

    await controller.logout();

    expect(controller.isAuthenticated, isFalse);
    expect(controller.pinRequired, isFalse);
    expect(controller.pinSetupRequired, isFalse);
    expect(controller.isSecurityLocked, isFalse);
  });
}

class _FailingLogoutRepository extends AuthRepository {
  _FailingLogoutRepository({
    required super.api,
    required super.tokenStore,
  });

  @override
  Future<void> logout() async {
    throw StateError('remote logout failed');
  }
}
