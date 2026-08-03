import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/profile/data/line_notification_models.dart';
import 'package:customer_flutter/features/profile/data/line_notification_repository.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:customer_flutter/features/profile/presentation/profile_screen.dart';
import 'package:customer_flutter/shared/widgets/app_alert.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('profile uses a compact fixed header and scrollable menu sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(399, 849);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {}),
          ),
          customerProfileSettingsProvider.overrideWith(
            (_) async => const CustomerProfileSettings(
              id: 'customer_1',
              name: 'คุณกิจ ชุ่มจันทร์จิรา',
              customerNo: 'PCHQKEJHH63TY',
              phone: '0812345678',
              bankAccount: RewardBankAccount(
                bankName: '',
                accountName: '',
                accountNumber: '',
              ),
              autoReward: AutoRewardSetting(
                enabled: false,
                payoutMethod: '',
                type: '',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerFinder = find.byKey(const ValueKey('profile-fixed-header'));
    final sheetFinder = find.byKey(const ValueKey('profile-content-sheet'));
    final initialHeaderRect = tester.getRect(headerFinder);
    final initialSheetTop = tester.getTopLeft(sheetFinder).dy;

    expect(initialHeaderRect.height, 150);
    expect(initialSheetTop, 150);

    await tester.drag(
      find.byKey(const ValueKey('profile-content-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(headerFinder), initialHeaderRect);
    expect(find.text('คุณกิจ ชุ่มจันทร์จิรา'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-affiliate-tier-gold')),
      findsNothing,
    );
    expect(find.text('Gold'), findsNothing);
    expect(tester.getTopLeft(sheetFinder).dy, lessThan(initialSheetTop));

    final aboutTitle = find.text('เกี่ยวกับแอปฯ');
    final languageItem = find.text('ภาษาในการใช้งาน');
    await tester.ensureVisible(aboutTitle);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(languageItem).dy,
      greaterThan(tester.getTopLeft(aboutTitle).dy),
    );

    final logoutFinder = find.byKey(const ValueKey('profile-logout-button'));
    await tester.ensureVisible(logoutFinder);
    await tester.pumpAndSettle();
    final logoutButton = tester.widget<FilledButton>(logoutFinder);
    final logoutContext = tester.element(logoutFinder);
    expect(
      logoutButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      Theme.of(logoutContext).colorScheme.error,
    );
    expect(
      logoutButton.style?.textStyle?.resolve(<WidgetState>{})?.fontWeight,
      FontWeight.w700,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile blocks LINE menu when the store is not configured', (
    tester,
  ) async {
    final router = _profileRouter();
    addTearDown(router.dispose);

    await _pumpProfileRouter(
      tester,
      router: router,
      lineSettings: const LineNotificationSettings(
        lineAvailable: false,
        botBasicId: '',
        botDisplayName: '',
        addFriendUrl: '',
        liffId: '',
      ),
    );
    await tester.pumpAndSettle();

    final lineMenu = find.text('แจ้งเตือนผ่าน LINE');
    await tester.ensureVisible(lineMenu);
    await tester.pumpAndSettle();
    await tester.tap(lineMenu);
    await tester.pumpAndSettle();

    expect(find.text('ร้านค้านี้ยังไม่ได้เปิดใช้งาน LINE OA'), findsOneWidget);
    expect(find.text('LINE settings route'), findsNothing);
    expect(find.text('ตกลง'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile opens LINE menu after runtime availability passes', (
    tester,
  ) async {
    final router = _profileRouter();
    addTearDown(router.dispose);

    await _pumpProfileRouter(
      tester,
      router: router,
      lineSettings: const LineNotificationSettings(
        lineAvailable: true,
        botBasicId: '@demo',
        botDisplayName: 'Demo LINE',
        addFriendUrl: '',
        liffId: 'demo-liff',
      ),
    );
    await tester.pumpAndSettle();

    final lineMenu = find.text('แจ้งเตือนผ่าน LINE');
    await tester.ensureVisible(lineMenu);
    await tester.pumpAndSettle();
    await tester.tap(lineMenu);
    await tester.pumpAndSettle();

    expect(find.text('LINE settings route'), findsOneWidget);
    expect(find.text('ร้านค้านี้ยังไม่ได้เปิดใช้งาน LINE OA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile opens Help Center independently of agent availability', (
    tester,
  ) async {
    final router = _profileRouter();
    addTearDown(router.dispose);

    await _pumpProfileRouter(
      tester,
      router: router,
      bootstrapJson: const {
        'featureFlags': {'customer_support': false},
      },
    );
    await tester.pumpAndSettle();

    final supportMenu = find.text('ศูนย์ช่วยเหลือ');
    await tester.ensureVisible(supportMenu);
    await tester.pumpAndSettle();
    expect(supportMenu, findsOneWidget);

    await tester.tap(supportMenu);
    await tester.pumpAndSettle();

    expect(find.text('Support route'), findsOneWidget);
    expect(find.text('ศูนย์ช่วยเหลือยังไม่เปิดให้บริการ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile LINE gate follows backend maintenance redirect', (
    tester,
  ) async {
    final router = _profileRouter();
    addTearDown(router.dispose);

    await _pumpProfileRouter(
      tester,
      router: router,
      lineError: _apiException(
        'ร้านค้าปิดปรับปรุงชั่วคราว',
        path: '/customer/line-notifications',
        code: 'maintenance_active',
        statusCode: 503,
      ),
    );
    await tester.pumpAndSettle();

    final lineMenu = find.text('แจ้งเตือนผ่าน LINE');
    await tester.ensureVisible(lineMenu);
    await tester.pumpAndSettle();
    await tester.tap(lineMenu);
    await tester.pumpAndSettle();

    expect(find.text('Maintenance route'), findsOneWidget);
  });

  testWidgets('profile load follows backend maintenance redirect', (
    tester,
  ) async {
    final router = _profileRouter();
    addTearDown(router.dispose);

    await _pumpProfileRouter(
      tester,
      router: router,
      profileError: _apiException(
        'ร้านค้าปิดปรับปรุงชั่วคราว',
        path: '/customer/profile',
        code: 'maintenance_active',
        statusCode: 503,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance route'), findsOneWidget);
  });
}

GoRouter _profileRouter() {
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/line-notifications',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('LINE settings route'))),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Support route'))),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Maintenance route'))),
      ),
    ],
  );
}

Future<void> _pumpProfileRouter(
  WidgetTester tester, {
  required GoRouter router,
  Map<String, dynamic> bootstrapJson = const {},
  LineNotificationSettings lineSettings = const LineNotificationSettings(
    lineAvailable: true,
    botBasicId: '@demo',
    botDisplayName: 'Demo LINE',
    addFriendUrl: '',
    liffId: 'demo-liff',
  ),
  Object? lineError,
  Object? profileError,
}) {
  tester.view.physicalSize = const Size(399, 849);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(bootstrapJson),
        ),
        customerProfileSettingsProvider.overrideWith((_) async {
          if (profileError != null) throw profileError;
          return _profileSettings;
        }),
        lineNotificationSettingsProvider.overrideWith((_) async {
          if (lineError != null) throw lineError;
          return lineSettings;
        }),
      ],
      child: MaterialApp.router(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) =>
            AppAlertHost(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
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

const _profileSettings = CustomerProfileSettings(
  id: 'customer_1',
  name: 'คุณกิจ ชุ่มจันทร์จิรา',
  customerNo: 'PCHQKEJHH63TY',
  phone: '0812345678',
  bankAccount: RewardBankAccount(
    bankName: '',
    accountName: '',
    accountNumber: '',
  ),
  autoReward: AutoRewardSetting(enabled: false, payoutMethod: '', type: ''),
);
