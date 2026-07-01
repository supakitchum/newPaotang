import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/profile/data/line_notification_models.dart';
import 'package:customer_flutter/features/profile/data/line_notification_repository.dart';
import 'package:customer_flutter/features/profile/presentation/line_notifications_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LINE notifications load error uses API payload copy', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        loadError: _apiException(
          'ร้านค้ายังไม่ได้เปิดบริการแจ้งเตือนผ่าน LINE',
          path: '/customer/line-notifications',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('ร้านค้ายังไม่ได้เปิดบริการแจ้งเตือนผ่าน LINE'),
      findsOneWidget,
    );
    expect(find.text('Could not load LINE settings.'), findsNothing);
  });

  testWidgets('LINE notifications load hides internal errors', (tester) async {
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        loadError: StateError('internal line settings failed'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Could not load LINE settings.'), findsOneWidget);
    expect(find.textContaining('internal line settings failed'), findsNothing);
  });

  testWidgets('LINE connect uses API payload error copy', (tester) async {
    await _pumpScreen(
      tester,
      authRepository: _LineAuthRepository(
        socialLoginUrlError: _apiException(
          'กรุณาเชื่อมต่อ LINE OA กับร้านค้าก่อน',
          path: '/customer/auth/social/line/login',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Connect LINE'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณาเชื่อมต่อ LINE OA กับร้านค้าก่อน'), findsOneWidget);
    expect(
      find.text('Could not connect LINE. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('LINE connect hides internal errors', (tester) async {
    await _pumpScreen(
      tester,
      authRepository: _LineAuthRepository(
        socialLoginUrlError: StateError('internal line connect failed'),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Connect LINE'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not connect LINE. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal line connect failed'), findsNothing);
  });

  testWidgets('LINE notification toggle uses API payload error copy', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        settings: _connectedSettings,
        updateError: _apiException(
          'ไม่สามารถเปิดแจ้งเตือน LINE ในขณะนี้',
          path: '/customer/line-notifications',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('ไม่สามารถเปิดแจ้งเตือน LINE ในขณะนี้'), findsOneWidget);
    expect(find.text('Could not save notification settings.'), findsNothing);
  });

  testWidgets('LINE disconnect uses API payload error copy', (tester) async {
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        settings: _connectedSettings,
        disconnectError: _apiException(
          'ไม่สามารถยกเลิก LINE ที่กำลังใช้งานอยู่',
          path: '/customer/line-notifications',
        ),
      ),
    );

    await tester.pumpAndSettle();
    final disconnectButton = find.widgetWithText(TextButton, 'Disconnect');
    await tester.ensureVisible(disconnectButton);
    await tester.tap(disconnectButton);
    await tester.pumpAndSettle();

    expect(
      find.text('ไม่สามารถยกเลิก LINE ที่กำลังใช้งานอยู่'),
      findsOneWidget,
    );
    expect(find.text('Could not disconnect LINE.'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  _LineNotificationRepository? lineRepository,
  _LineAuthRepository? authRepository,
}) {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        lineNotificationRepositoryProvider.overrideWithValue(
          lineRepository ?? _LineNotificationRepository(),
        ),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? _LineAuthRepository(),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en', 'US'),
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LineNotificationsScreen(),
      ),
    ),
  );
}

const _defaultSettings = LineNotificationSettings(
  lineAvailable: true,
  botBasicId: '@demo',
  botDisplayName: 'Demo LINE',
  addFriendUrl: '',
  liffId: 'demo-liff',
);

const _connectedSettings = LineNotificationSettings(
  lineAvailable: true,
  botBasicId: '@demo',
  botDisplayName: 'Demo LINE',
  addFriendUrl: '',
  liffId: 'demo-liff',
  identity: LineIdentity(
    id: 'line_identity_1',
    displayName: 'Ada Line',
    pictureUrl: '',
    friendFlag: true,
    notificationEnabled: false,
  ),
);

class _LineNotificationRepository extends LineNotificationRepository {
  _LineNotificationRepository({
    this.settings = _defaultSettings,
    this.loadError,
    this.updateError,
    this.disconnectError,
  }) : super(_testApiClient());

  final LineNotificationSettings settings;
  final Object? loadError;
  final Object? updateError;
  final Object? disconnectError;

  @override
  Future<LineNotificationSettings> load() async {
    final error = loadError;
    if (error != null) throw error;
    return settings;
  }

  @override
  Future<LineNotificationSettings> updateNotificationEnabled(
    bool enabled,
  ) async {
    final error = updateError;
    if (error != null) throw error;
    return settings;
  }

  @override
  Future<LineNotificationSettings> disconnect() async {
    final error = disconnectError;
    if (error != null) throw error;
    return settings;
  }
}

class _LineAuthRepository extends AuthRepository {
  _LineAuthRepository({this.socialLoginUrlError})
      : super(api: _testApiClient(), tokenStore: AuthTokenStore());

  final Object? socialLoginUrlError;

  @override
  Future<String> socialLoginUrl(String provider, {String purpose = 'login'}) {
    final error = socialLoginUrlError;
    if (error != null) throw error;
    return Future.value('https://line.example.com/oauth');
  }
}

DioException _apiException(String message, {required String path}) {
  final request = RequestOptions(path: path);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: {'message': message},
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
