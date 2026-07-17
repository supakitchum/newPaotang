import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_locale_controller.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('verifyPin keeps restored sessions authenticated and clears PIN gate',
      () async {
    final tokenStore = _MemoryTokenStore()
      ..accessToken = 'restored-access'
      ..refreshToken = 'restored-refresh'
      ..customerId = 'cus_1';
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
    );
    final repository = _PinVerifyRepository(api: api, tokenStore: tokenStore);
    final controller = AuthController(
      authRepository: repository,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    )
      ..isAuthenticated = false
      ..pinRequired = true
      ..pinSetupRequired = true
      ..isSecurityLocked = true;

    await controller.verifyPin('123456');

    expect(repository.lastPin, '123456');
    expect(controller.isAuthenticated, isTrue);
    expect(controller.pinRequired, isFalse);
    expect(controller.pinSetupRequired, isFalse);
    expect(controller.isSecurityLocked, isFalse);
  });

  test('refresh token alone keeps startup session behind the PIN gate', () {
    final tokenStore = _MemoryTokenStore()
      ..refreshToken = 'stored-refresh'
      ..customerId = 'cus_refresh_only';
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
    );
    final controller = AuthController(
      authRepository: AuthRepository(api: api, tokenStore: tokenStore),
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );

    expect(controller.isAuthenticated, isTrue);
    expect(controller.pinRequired, isTrue);
  });

  test('startup restores refresh-only session and profile PIN state', () async {
    final tokenStore = _MemoryTokenStore()
      ..refreshToken = 'stored-refresh'
      ..customerId = 'cus_refresh_only';
    final api = _testApi(tokenStore);
    final repository = _SessionRestoreRepository(
      api: api,
      tokenStore: tokenStore,
      refreshedSession: const CustomerSession(
        accessToken: 'rotated-access',
        refreshToken: 'rotated-refresh',
        pinRequired: false,
        pinSetupRequired: false,
        customerId: 'cus_refresh_only',
        preferredLocale: 'en-US',
      ),
      identity: const CustomerAuthIdentity(
        customerId: 'cus_refresh_only',
        hasPin: true,
        pinRequired: false,
        pinSetupRequired: false,
        preferredLocale: 'en-US',
      ),
    );
    final controller = AuthController(
      authRepository: repository,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );

    await controller.restoreSession();

    expect(repository.refreshCalls, 1);
    expect(repository.identityCalls, 1);
    expect(tokenStore.accessToken, 'rotated-access');
    expect(tokenStore.refreshToken, 'rotated-refresh');
    expect(controller.isAuthenticated, isTrue);
    expect(controller.pinRequired, isTrue);
    expect(controller.pinSetupRequired, isFalse);
    expect(controller.preferredLocale, 'en-US');
  });

  test('startup profile marks customers without PIN for setup', () async {
    final tokenStore = _MemoryTokenStore()
      ..accessToken = 'stored-access'
      ..refreshToken = 'stored-refresh';
    final api = _testApi(tokenStore);
    final repository = _SessionRestoreRepository(
      api: api,
      tokenStore: tokenStore,
      identity: const CustomerAuthIdentity(
        customerId: 'cus_no_pin',
        hasPin: false,
        pinRequired: true,
        pinSetupRequired: true,
        preferredLocale: 'th-TH',
      ),
    );
    final controller = AuthController(
      authRepository: repository,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );

    await controller.restoreSession();

    expect(repository.refreshCalls, 0);
    expect(repository.identityCalls, 1);
    expect(controller.isAuthenticated, isTrue);
    expect(controller.pinRequired, isTrue);
    expect(controller.pinSetupRequired, isTrue);
  });

  test('startup preserves refreshable session on temporary refresh failure',
      () async {
    final tokenStore = _MemoryTokenStore()
      ..refreshToken = 'stored-refresh'
      ..customerId = 'cus_transient';
    final api = _testApi(tokenStore);
    final repository = _SessionRestoreRepository(
      api: api,
      tokenStore: tokenStore,
      refreshError: DioException(
        requestOptions: RequestOptions(path: '/customer/auth/refresh'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/customer/auth/refresh'),
          statusCode: 503,
          data: const {'message': 'temporarily unavailable'},
        ),
      ),
    );
    final controller = AuthController(
      authRepository: repository,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );

    await controller.restoreSession();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.pinRequired, isTrue);
    expect(tokenStore.refreshToken, 'stored-refresh');
    expect(repository.clearCalls, 0);
  });

  test('startup preserves access session on temporary profile failure',
      () async {
    final tokenStore = _MemoryTokenStore()
      ..accessToken = 'stored-access'
      ..refreshToken = 'stored-refresh'
      ..customerId = 'cus_transient_profile';
    final api = _testApi(tokenStore);
    final request = RequestOptions(path: '/customer/profile');
    final repository = _SessionRestoreRepository(
      api: api,
      tokenStore: tokenStore,
      identityError: DioException(
        requestOptions: request,
        response: Response<Map<String, dynamic>>(
          requestOptions: request,
          statusCode: 503,
          data: const {'message': 'temporarily unavailable'},
        ),
      ),
    );
    final controller = AuthController(
      authRepository: repository,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );

    await controller.restoreSession();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.pinRequired, isTrue);
    expect(tokenStore.accessToken, 'stored-access');
    expect(tokenStore.refreshToken, 'stored-refresh');
    expect(repository.clearCalls, 0);
  });

  test('startup clears a definitively rejected refresh session', () async {
    final tokenStore = _MemoryTokenStore()
      ..refreshToken = 'rejected-refresh'
      ..customerId = 'cus_rejected';
    final api = _testApi(tokenStore);
    final request = RequestOptions(path: '/customer/auth/refresh');
    final repository = _SessionRestoreRepository(
      api: api,
      tokenStore: tokenStore,
      refreshError: DioException(
        requestOptions: request,
        response: Response<Map<String, dynamic>>(
          requestOptions: request,
          statusCode: 401,
          data: const {
            'error': {'code': 'authentication_required'},
          },
        ),
      ),
    );
    final controller = AuthController(
      authRepository: repository,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    );

    await controller.restoreSession();

    expect(controller.isAuthenticated, isFalse);
    expect(controller.pinRequired, isFalse);
    expect(tokenStore.refreshToken, isNull);
    expect(repository.clearCalls, 1);
  });

  test('locale changes keep ApiClient and AuthController instances stable', () {
    final tokenStore = _MemoryTokenStore()
      ..accessToken = 'stored-access'
      ..refreshToken = 'stored-refresh';
    final container = ProviderContainer(
      overrides: [
        authTokenStoreProvider.overrideWithValue(tokenStore),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    final controller = container.read(authControllerProvider);
    container.read(customerLocaleProvider.notifier).state =
        const Locale('en', 'US');

    expect(container.read(apiClientProvider), same(api));
    expect(container.read(authControllerProvider), same(controller));
    expect(api.currentLocaleTag, 'en-US');
    expect(controller.pinRequired, isTrue);
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

class _PinVerifyRepository extends AuthRepository {
  _PinVerifyRepository({
    required super.api,
    required super.tokenStore,
  });

  String lastPin = '';

  @override
  Future<PinStatus> verifyPin(String pin) async {
    lastPin = pin;
    return const PinStatus(
      hasPin: true,
      pinVerified: true,
      pinRequired: false,
      pinSetupRequired: false,
    );
  }
}

class _SessionRestoreRepository extends AuthRepository {
  _SessionRestoreRepository({
    required super.api,
    required super.tokenStore,
    this.refreshedSession,
    this.identity = const CustomerAuthIdentity(
      customerId: 'cus_default',
      hasPin: true,
      pinRequired: true,
      pinSetupRequired: false,
      preferredLocale: '',
    ),
    this.refreshError,
    this.identityError,
  }) : _tokenStore = tokenStore;

  final AuthTokenStore _tokenStore;
  final CustomerSession? refreshedSession;
  final CustomerAuthIdentity identity;
  final Object? refreshError;
  final Object? identityError;
  int refreshCalls = 0;
  int identityCalls = 0;
  int clearCalls = 0;

  @override
  Future<CustomerSession> refresh() async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
    final session = refreshedSession!;
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      customerId: session.customerId,
    );
    return session;
  }

  @override
  Future<CustomerAuthIdentity> currentIdentity() async {
    identityCalls++;
    final error = identityError;
    if (error != null) throw error;
    return identity;
  }

  @override
  Future<void> clearLocalSession() async {
    clearCalls++;
    await _tokenStore.clear();
  }
}

class _MemoryTokenStore extends AuthTokenStore {
  @override
  String? accessToken;

  @override
  String? refreshToken;

  @override
  String? customerId;

  @override
  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.customerId = customerId;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    customerId = null;
  }
}

ApiClient _testApi(AuthTokenStore tokenStore) {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore,
    localeTag: 'th-TH',
  );
}
