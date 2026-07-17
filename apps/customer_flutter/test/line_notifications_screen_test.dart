import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/profile/data/line_notification_models.dart';
import 'package:customer_flutter/features/profile/data/line_notification_repository.dart';
import 'package:customer_flutter/features/profile/presentation/line_notifications_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('LINE settings accept wrapped camelCase production payloads', () {
    final settings = LineNotificationSettings.fromJson({
      'data': {
        'resource': {
          'lineNotificationSettings': {
            'lineAvailable': 'active',
            'lineOa': {
              'basicId': '@wrapped',
              'displayName': 'Wrapped LINE OA',
              'addFriendUrl': {'href': 'https://line.me/R/ti/p/@wrapped'},
            },
            'lineLiff': {'liffId': 'wrapped-liff'},
            'lineIdentity': {
              'lineUserId': 'U-wrapped',
              'displayName': 'Wrapped Customer',
              'pictureUrl': 'https://cdn.example.test/line.png',
              'friendStatus': 'added',
              'notificationStatus': 'enabled',
            },
          },
        },
      },
    });

    expect(settings.lineAvailable, isTrue);
    expect(settings.botBasicId, '@wrapped');
    expect(settings.botDisplayName, 'Wrapped LINE OA');
    expect(settings.addFriendUrl, 'https://line.me/R/ti/p/@wrapped');
    expect(settings.liffId, 'wrapped-liff');
    expect(settings.identity?.id, 'U-wrapped');
    expect(settings.identity?.displayName, 'Wrapped Customer');
    expect(settings.identity?.friendFlag, isTrue);
    expect(settings.identity?.notificationEnabled, isTrue);
  });

  testWidgets('LINE screen uses a title-only header and bottom action footer', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();

    final headerRect = tester.getRect(
      find.byKey(const ValueKey('customer-fixed-hero')),
    );
    final footerRect = tester.getRect(
      find.byKey(const ValueKey('line-action-footer')),
    );

    expect(headerRect.height, 150);
    expect(footerRect.bottom, 1200);
    expect(find.text('LINE notifications'), findsOneWidget);
    expect(find.text('Get every transaction update'), findsNothing);
    expect(find.text('Connect LINE'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('My Tickets'), findsNothing);
    expect(find.text('More'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LINE actions fill the footer and status stays top right', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        settings: const LineNotificationSettings(
          lineAvailable: true,
          botBasicId: '@demo',
          botDisplayName: 'Demo LINE',
          addFriendUrl: 'https://line.me/R/ti/p/@demo',
          liffId: 'demo-liff',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footerRect = tester.getRect(
      find.byKey(const ValueKey('line-action-footer')),
    );
    final connectRect = tester.getRect(
      find.byKey(const ValueKey('line-connect-action')),
    );
    final addFriendRect = tester.getRect(
      find.byKey(const ValueKey('line-add-friend-action')),
    );
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('line-account-card')),
    );
    final badgeRect = tester.getRect(
      find.byKey(const ValueKey('line-connection-badge')),
    );

    expect(connectRect.left, moreOrLessEquals(footerRect.left + 16));
    expect(connectRect.right, moreOrLessEquals(footerRect.right - 16));
    expect(addFriendRect.left, moreOrLessEquals(connectRect.left));
    expect(addFriendRect.right, moreOrLessEquals(connectRect.right));
    expect(badgeRect.right, moreOrLessEquals(cardRect.right - 18));
    expect(badgeRect.top, moreOrLessEquals(cardRect.top + 18));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LINE direct route hides connect actions when unavailable', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        settings: const LineNotificationSettings(
          lineAvailable: false,
          botBasicId: '',
          botDisplayName: '',
          addFriendUrl: '',
          liffId: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This store has not enabled LINE OA yet'),
      findsOneWidget,
    );
    expect(find.text('Connect LINE'), findsNothing);
    expect(find.byKey(const ValueKey('line-action-footer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    final authRepository = _LineAuthRepository(
      socialLoginUrlError: _apiException(
        'กรุณาเชื่อมต่อ LINE OA กับร้านค้าก่อน',
        path: '/customer/auth/social/line/login',
      ),
    );
    await _pumpScreen(
      tester,
      authRepository: authRepository,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect LINE'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณาเชื่อมต่อ LINE OA กับร้านค้าก่อน'), findsOneWidget);
    expect(authRepository.lastProvider, 'line');
    expect(authRepository.lastPurpose, 'login');
    expect(authRepository.lastRedirect, '/profile/line-notifications');
    expect(authRepository.lastCallbackUsesAuth, isTrue);
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
    await tester.tap(find.text('Connect LINE'));
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
    await tester.tap(find.byKey(const Key('line_notification_switch')));
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
    final disconnectButton = find.text('Disconnect');
    await tester.ensureVisible(disconnectButton);
    await tester.tap(disconnectButton);
    await tester.pumpAndSettle();

    expect(
      find.text('ไม่สามารถยกเลิก LINE ที่กำลังใช้งานอยู่'),
      findsOneWidget,
    );
    expect(find.text('Could not disconnect LINE.'), findsNothing);
  });

  testWidgets('LINE add-friend action shows an inline launch failure', (
    tester,
  ) async {
    final launcher = _LineLinkLauncher(opened: false);
    await _pumpScreen(
      tester,
      lineRepository: _LineNotificationRepository(
        settings: const LineNotificationSettings(
          lineAvailable: true,
          botBasicId: '@demo',
          botDisplayName: 'Demo LINE',
          addFriendUrl: 'https://line.me/R/ti/p/@demo',
          liffId: 'demo-liff',
        ),
      ),
      linkLauncher: launcher,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('line-add-friend-action')));
    await tester.pumpAndSettle();

    expect(launcher.lastUri?.toString(), 'https://line.me/R/ti/p/@demo');
    expect(launcher.preferSameWindowInLine, isTrue);
    expect(find.text('Connection URL was not found.'), findsOneWidget);
  });

  testWidgets('LINE settings load follows backend maintenance redirect', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile/line-notifications',
      routes: [
        GoRoute(
          path: '/profile/line-notifications',
          builder: (_, __) => const LineNotificationsScreen(),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('Maintenance route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {}),
          ),
          lineNotificationRepositoryProvider.overrideWithValue(
            _LineNotificationRepository(
              loadError: _apiException(
                'ร้านค้าปิดปรับปรุงชั่วคราว',
                path: '/customer/line-notifications',
                code: 'maintenance_active',
                statusCode: 503,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en', 'US'),
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance route'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  _LineNotificationRepository? lineRepository,
  _LineAuthRepository? authRepository,
  CustomerLinkLauncher? linkLauncher,
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
        if (linkLauncher != null)
          customerLinkLauncherProvider.overrideWithValue(linkLauncher),
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
  String? lastProvider;
  String? lastPurpose;
  String? lastRedirect;
  bool? lastCallbackUsesAuth;

  @override
  Future<String> socialLoginUrl(
    String provider, {
    String purpose = 'login',
    String? redirect,
    bool callbackUsesAuth = false,
  }) {
    lastProvider = provider;
    lastPurpose = purpose;
    lastRedirect = redirect;
    lastCallbackUsesAuth = callbackUsesAuth;
    final error = socialLoginUrlError;
    if (error != null) throw error;
    return Future.value('https://line.example.com/oauth');
  }
}

class _LineLinkLauncher extends CustomerLinkLauncher {
  _LineLinkLauncher({required this.opened});

  final bool opened;
  Uri? lastUri;
  bool preferSameWindowInLine = false;

  @override
  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
    lastUri = uri;
    this.preferSameWindowInLine = preferSameWindowInLine;
    return opened;
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
      data: {
        if (code.isNotEmpty) 'code': code,
        'message': message,
      },
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
