import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/profile/data/biometric_device_models.dart';
import 'package:customer_flutter/features/profile/data/biometric_device_repository.dart';
import 'package:customer_flutter/features/profile/presentation/biometric_devices_screen.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('biometric devices uses one shared fixed blue header', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customer-fixed-hero')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('customer-fixed-content-region')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('customer-fixed-hero'))).height,
      customerReferenceCompactHeroHeight,
    );
    expect(find.text('Face ID / Biometric'), findsOneWidget);
    expect(find.text('Use Face ID / Biometric instead of PIN'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('biometric devices load error uses API payload copy', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      deviceRepository: _BiometricDeviceRepository(
        loadError: _apiException(
          'ยังไม่สามารถโหลดอุปกรณ์ biometric ได้',
          path: '/customer/auth/biometric/devices',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ยังไม่สามารถโหลดอุปกรณ์ biometric ได้'), findsOneWidget);
    expect(find.text('Could not load biometric devices.'), findsNothing);
  });

  testWidgets('biometric devices load hides internal errors', (tester) async {
    await _pumpScreen(
      tester,
      deviceRepository: _BiometricDeviceRepository(
        loadError: StateError('internal biometric device failure'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Could not load biometric devices.'), findsOneWidget);
    expect(
      find.textContaining('internal biometric device failure'),
      findsNothing,
    );
  });

  testWidgets('biometric devices load follows backend maintenance redirect', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile/biometrics',
      routes: [
        GoRoute(
          path: '/profile/biometrics',
          builder: (_, __) => const BiometricDevicesScreen(),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Maintenance route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpScreen(
      tester,
      router: router,
      deviceRepository: _BiometricDeviceRepository(
        loadError: _apiException(
          'ร้านค้าปิดปรับปรุงชั่วคราว',
          path: '/customer/auth/biometric/devices',
          code: 'maintenance_active',
          statusCode: 503,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance route'), findsOneWidget);
  });

  testWidgets('biometric enable uses API payload error copy', (tester) async {
    await _pumpScreen(
      tester,
      biometricAuth: _BiometricAuthService(
        registerError: _apiException(
          'PIN ไม่ถูกต้อง กรุณาลองใหม่',
          path: '/customer/auth/biometric/devices',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enable biometric'));
    await tester.pumpAndSettle();
    await _enterBiometricPin(tester, '123456');

    expect(find.text('PIN ไม่ถูกต้อง กรุณาลองใหม่'), findsOneWidget);
    expect(
      find.text(
        'Could not enable biometric unlock. Please check your PIN or try again.',
      ),
      findsNothing,
    );
  });

  testWidgets('biometric enable hides internal errors', (tester) async {
    await _pumpScreen(
      tester,
      biometricAuth: _BiometricAuthService(
        registerError: StateError('internal register failure'),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enable biometric'));
    await tester.pumpAndSettle();
    await _enterBiometricPin(tester, '123456');

    expect(
      find.text(
        'Could not enable biometric unlock. Please check your PIN or try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('internal register failure'), findsNothing);
  });

  testWidgets('biometric enable sends localized biometric setup reason', (
    tester,
  ) async {
    final biometricAuth = _BiometricAuthService();
    await _pumpScreen(tester, biometricAuth: biometricAuth);

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enable biometric'));
    await tester.pumpAndSettle();
    await _enterBiometricPin(tester, '123456');

    expect(biometricAuth.registeredPins, ['123456']);
    expect(biometricAuth.registeredPlatforms, ['ios']);
    expect(biometricAuth.registeredDeviceNames, ['This iPhone / iPad']);
    expect(biometricAuth.localizedReasons, [
      'Authenticate to enable biometric unlock on this device',
    ]);
    expect(
      find.text('Biometric unlock is enabled for this device.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('biometric enable uses runtime biometric setup reason', (
    tester,
  ) async {
    final biometricAuth = _BiometricAuthService();
    await _pumpScreen(
      tester,
      biometricAuth: biometricAuth,
      bootstrap: _mobileBootstrapWithRuntimePrompt,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enable biometric'));
    await tester.pumpAndSettle();
    await _enterBiometricPin(tester, '123456');

    expect(biometricAuth.localizedReasons, ['Runtime setup biometric prompt']);
  });

  testWidgets('biometric revoke uses API payload error copy', (tester) async {
    await _pumpScreen(
      tester,
      deviceRepository: _BiometricDeviceRepository(
        devices: const [_activeDevice],
        revokeError: _apiException(
          'ไม่สามารถยกเลิกอุปกรณ์นี้ได้',
          path: '/customer/auth/biometric/devices/bio_1',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Revoke this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('ไม่สามารถยกเลิกอุปกรณ์นี้ได้'), findsOneWidget);
    expect(find.text('Could not revoke this device.'), findsNothing);
  });

  testWidgets('biometric revoke clears local key for the current device', (
    tester,
  ) async {
    final repository = _BiometricDeviceRepository(
      devices: const [_activeDevice],
    );
    final biometricAuth = _BiometricAuthService(localDeviceId: 'device_1');
    await _pumpScreen(
      tester,
      deviceRepository: repository,
      biometricAuth: biometricAuth,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Revoke this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(repository.revokedIds, ['bio_1']);
    expect(biometricAuth.clearedDeviceIds, ['device_1']);
    expect(find.text('Device revoked.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('biometric revoke keeps local key for another device', (
    tester,
  ) async {
    final biometricAuth = _BiometricAuthService(localDeviceId: 'device_local');
    await _pumpScreen(
      tester,
      deviceRepository: _BiometricDeviceRepository(
        devices: const [_activeDevice],
      ),
      biometricAuth: biometricAuth,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Revoke this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(biometricAuth.clearedDeviceIds, isEmpty);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  _BiometricDeviceRepository? deviceRepository,
  _BiometricAuthService? biometricAuth,
  MobileBootstrap? bootstrap,
  GoRouter? router,
}) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        biometricDeviceRepositoryProvider.overrideWithValue(
          deviceRepository ?? _BiometricDeviceRepository(),
        ),
        biometricAuthServiceProvider.overrideWithValue(
          biometricAuth ?? _BiometricAuthService(),
        ),
        customerPlatformKeyProvider.overrideWithValue('ios'),
        mobileBootstrapProvider.overrideWith(
          (_) async => bootstrap ?? _mobileBootstrap,
        ),
      ],
      child: router == null
          ? const MaterialApp(
              locale: Locale('en', 'US'),
              supportedLocales: supportedCustomerLocales,
              localizationsDelegates: [
                CustomerLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: BiometricDevicesScreen(),
            )
          : MaterialApp.router(
              locale: const Locale('en', 'US'),
              supportedLocales: supportedCustomerLocales,
              localizationsDelegates: const [
                CustomerLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: router,
            ),
    ),
  );
}

Future<void> _enterBiometricPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.widgetWithText(TextButton, digit));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

final _mobileBootstrap = MobileBootstrap.fromJson(const {
  'mobile': {
    'feature_flags': {'native_biometric_unlock': true},
    'biometric': {
      'enabled': true,
      'platforms': {
        'ios': ['local_auth'],
        'android': ['biometric_prompt'],
      },
    },
  },
});

final _mobileBootstrapWithRuntimePrompt = MobileBootstrap.fromJson(const {
  'mobile': {
    'feature_flags': {'native_biometric_unlock': true},
    'biometric': {
      'enabled': true,
      'biometricSetupReason': 'Runtime setup biometric prompt',
      'platforms': {
        'ios': ['local_auth'],
      },
    },
  },
});

const _activeDevice = BiometricDevice(
  id: 'bio_1',
  deviceId: 'device_1',
  platform: 'ios',
  deviceName: 'Supakit iPhone',
  algorithm: 'ES256',
  status: 'active',
  registeredAt: '2026-07-01T10:00:00Z',
  lastUsedAt: '',
  revokedAt: '',
);

class _BiometricDeviceRepository extends BiometricDeviceRepository {
  _BiometricDeviceRepository({
    this.devices = const [],
    this.loadError,
    this.revokeError,
  }) : super(_testApiClient());

  final List<BiometricDevice> devices;
  final Object? loadError;
  final Object? revokeError;
  final List<String> revokedIds = [];

  @override
  Future<List<BiometricDevice>> list() async {
    final error = loadError;
    if (error != null) throw error;
    return devices;
  }

  @override
  Future<void> revoke(String id) async {
    final error = revokeError;
    if (error != null) throw error;
    revokedIds.add(id);
  }
}

class _BiometricAuthService extends BiometricAuthService {
  _BiometricAuthService({this.registerError, this.localDeviceId})
    : super(_testApiClient());

  final Object? registerError;
  final String? localDeviceId;
  final List<String> registeredPins = [];
  final List<String> registeredPlatforms = [];
  final List<String?> registeredDeviceNames = [];
  final List<String> localizedReasons = [];
  final List<String> clearedDeviceIds = [];

  @override
  Future<bool> canUseBiometric() async {
    return true;
  }

  @override
  Future<void> registerDevice({
    required String pin,
    required String platform,
    required String localizedReason,
    String? deviceName,
    String? appVersion,
  }) async {
    registeredPins.add(pin);
    registeredPlatforms.add(platform);
    registeredDeviceNames.add(deviceName);
    localizedReasons.add(localizedReason);
    final error = registerError;
    if (error != null) throw error;
  }

  @override
  Future<String?> currentDeviceId() async => localDeviceId;

  @override
  Future<bool> clearLocalDeviceKey({String? deviceId}) async {
    if (localDeviceId == null || localDeviceId!.isEmpty) return false;
    if (deviceId != null && deviceId.isNotEmpty && deviceId != localDeviceId) {
      return false;
    }
    clearedDeviceIds.add(localDeviceId!);
    return true;
  }
}

DioException _apiException(
  String message, {
  required String path,
  String code = '',
  int statusCode = 422,
}) {
  final request = RequestOptions(path: path);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: statusCode,
      data: {if (code.isNotEmpty) 'code': code, 'message': message},
    ),
  );
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'en-US',
    ),
    AuthTokenStore(),
    localeTag: 'en-US',
  );
}
