import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_models.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_repository.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:customer_flutter/features/activities/presentation/activity_detail_screen.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('activityDetailBackPath follows Nuxt detail return rules', () {
    expect(
      activityDetailBackPath(from: '', gameId: ''),
      '/activities',
    );
    expect(
      activityDetailBackPath(from: 'history', gameId: ''),
      '/activities/history',
    );
    expect(
      activityDetailBackPath(from: 'history', gameId: 'game_prev'),
      '/activities/history?game_id=game_prev',
    );
    expect(
      activityDetailBackPath(from: 'history', gameId: 'game prev/1'),
      '/activities/history?game_id=game+prev%2F1',
    );
  });

  testWidgets('ActivityDetailScreen hides awards before result announcement', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: false);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.awardsAllCount, 0);
    expect(find.text('กิจกรรมทายเลข 2 ตัว'), findsOneWidget);
    expect(find.text('00-99 · เหลือ 97 จาก 100 เลข'), findsOneWidget);
    expect(find.text('เลขสีแดงถูกเลือกแล้ว'), findsOneWidget);
    expect(find.text('พร้อมรับเงินรางวัล'), findsNothing);
    expect(find.text('รับเงิน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityDetailScreen shows claimable awards after announcement',
      (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.awardsAllCount, 1);
    expect(find.text('ผลกิจกรรม'), findsOneWidget);
    expect(find.text('พร้อมรับเงินรางวัล'), findsOneWidget);
    expect(find.text('รับเงิน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityDetailScreen cashback panel uses runtime result time', (
    tester,
  ) async {
    final repository = _CashbackActivityRepository();

    await _pumpDetail(
      tester,
      repository,
      initialLocation: '/activities/cashback-5',
    );
    await tester.pumpAndSettle();

    final expectedTime = '${formatLocalizedDateTime(
      _cashbackResultAt,
      'th-TH',
    )} น.';

    expect(repository.detailCount, 1);
    expect(find.textContaining(expectedTime), findsWidgets);
    expect(
      find.text('ระบบจะสรุปสิทธิ์อีกครั้งเวลา $expectedTime'),
      findsOneWidget,
    );
    expect(find.text('17:00 น. ของวันที่ออกผล'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityDetailScreen refreshes awards on claim realtime tick', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.detailCount, 1);
    expect(repository.awardsAllCount, 1);
    expect(find.text('พร้อมรับเงินรางวัล'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ActivityDetailScreen)),
      listen: false,
    );
    container.read(activityClaimRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.detailCount, 2);
    expect(repository.awardsAllCount, 2);
    expect(find.text('พร้อมรับเงินรางวัล'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityDetailScreen confirms lucky number with Nuxt modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeActivityRepository(resultAnnounced: false);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    await _tapLuckyNumber(tester, '04');
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันเลขนำโชค'), findsOneWidget);
    expect(find.text('ต้องการเลือกเลขนี้ใช่ไหม?'), findsOneWidget);
    expect(find.text('04'), findsWidgets);
    expect(
      find.text(
        'ระบบจะใช้ 1 สิทธิ์ของคุณสำหรับ เลขท้าย 2 ตัว และไม่สามารถเลือกเลขนี้ซ้ำได้',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'ยกเลิก'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ยืนยันเลือกเลข'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันเลือกเลข'));
    await tester.pumpAndSettle();

    expect(repository.createEntryCount, 1);
    expect(repository.createdActivityIds, ['act_lucky']);
    expect(repository.createdPredictionTypes, ['last2']);
    expect(repository.createdSelectedNumbers, ['04']);
    expect(find.text('ส่งเลขสำเร็จ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityDetailScreen back returns to current activities', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: false);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Activities route'), findsOneWidget);
  });

  testWidgets('ActivityDetailScreen back preserves history game context', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: false);

    await _pumpDetail(
      tester,
      repository,
      initialLocation: '/activities/lucky-board?from=history&game_id=game_prev',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('History route: game_prev'), findsOneWidget);
  });

  testWidgets('ActivityDetailScreen uses Nuxt detail loading copy', (
    tester,
  ) async {
    await _pumpDetail(tester, _PendingActivityRepository());
    await tester.pump();

    expect(find.text('กำลังโหลดรายละเอียดกิจกรรม...'), findsOneWidget);
    expect(find.text('กำลังโหลดข้อมูล...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('ActivityDetailScreen uses Nuxt detail error copy', (
    tester,
  ) async {
    await _pumpDetail(tester, _ErrorActivityRepository());
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายละเอียดกิจกรรมไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ไม่พบกิจกรรม'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('ActivityDetailScreen detail error uses API copy when available',
      (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      _ErrorActivityRepository(
        error: _apiException('ระบบกิจกรรมปิดปรับปรุง'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ระบบกิจกรรมปิดปรับปรุง'), findsOneWidget);
    expect(find.text('โหลดรายละเอียดกิจกรรมไม่สำเร็จ'), findsNothing);
    expect(find.text('ไม่พบกิจกรรม'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('ActivityDetailScreen shows Nuxt missing state with CTA', (
    tester,
  ) async {
    await _pumpDetail(tester, _MissingActivityRepository());
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบกิจกรรม'), findsOneWidget);
    expect(
      find.text('กิจกรรมนี้อาจถูกปิดใช้งานหรือหมดช่วงแสดงผลแล้ว'),
      findsOneWidget,
    );
    expect(find.text('กลับหน้ากิจกรรม'), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    await tester.tap(find.text('กลับหน้ากิจกรรม'));
    await tester.pumpAndSettle();

    expect(find.text('Activities route'), findsOneWidget);
  });

  testWidgets('ActivityDetailScreen entry error uses API copy when available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeActivityRepository(
      resultAnnounced: false,
      entryError: _apiException('เลขนี้ถูกเลือกแล้ว'),
    );

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    await _tapLuckyNumber(tester, '04');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันเลือกเลข'));
    await tester.pumpAndSettle();

    expect(repository.createEntryCount, 1);
    expect(find.text('เลขนี้ถูกเลือกแล้ว'), findsOneWidget);
    expect(
      find.text('ส่งเลขไม่สำเร็จ กรุณาตรวจสอบสิทธิ์แล้วลองใหม่'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Activity claim bank setup returns to the current activity detail path', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);

    await _pumpDetail(
      tester,
      repository,
      profileRepository: _MissingRewardBankProfileRepository(),
    );
    await tester.pumpAndSettle();

    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'รับเงิน'),
    );
    claimButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('รับเงินกิจกรรม'), findsOneWidget);
    expect(find.text('รับเงินรางวัลกิจกรรม'), findsOneWidget);
    expect(find.text('ยอดที่รับได้'), findsOneWidget);
    expect(find.text('2,000.00 บาท'), findsWidgets);
    expect(
      find.ancestor(
        of: find.text('ยอดที่รับได้'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    expect(find.text('โอนเข้าบัญชีธนาคาร'), findsOneWidget);
    expect(find.text('ยังไม่ได้ตั้งค่าบัญชีรับเงิน'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ยกเลิก'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ถัดไป'), findsOneWidget);

    await tester.tap(find.text('ตั้งค่าบัญชีรับเงิน'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '/profile/reward-bank?redirect=%2Factivities%2Flucky-board',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity claim sheet loading uses Nuxt payout panel', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);

    await _pumpDetail(
      tester,
      repository,
      profileRepository: _PendingRewardBankProfileRepository(),
    );
    await tester.pumpAndSettle();

    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'รับเงิน'),
    );
    claimButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('รับเงินกิจกรรม'), findsOneWidget);
    expect(find.text('รับเงินรางวัลกิจกรรม'), findsOneWidget);
    expect(find.text('กำลังโหลดข้อมูลรับเงิน...'), findsOneWidget);
    expect(
      find.byKey(const Key('activity-claim-profile-loading')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Activity claim sheet bank payout matches Nuxt labels and payload', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);
    final claimRepository = _CaptureActivityClaimRepository();

    await _pumpDetail(
      tester,
      repository,
      profileRepository: _CompleteRewardBankProfileRepository(),
      activityClaimRepository: claimRepository,
    );
    await tester.pumpAndSettle();

    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'รับเงิน'),
    );
    claimButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('รับเงินกิจกรรม'), findsOneWidget);
    expect(find.text('G Wallet x 123'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('ยอดที่รับได้'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    expect(find.text('บัญชีกสิกรไทย x 7890'), findsOneWidget);
    expect(
      find.text('รับเงินเข้าบัญชีรับเงินรางวัลที่บันทึกไว้'),
      findsOneWidget,
    );
    expect(find.text('ธนาคารกสิกรไทย'), findsNothing);

    await tester.tap(find.text('บัญชีกสิกรไทย x 7890'));
    await tester.pumpAndSettle();

    expect(find.text('ธนาคารกสิกรไทย'), findsOneWidget);
    expect(find.text('Demo Customer · ******7890'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('ใส่รหัส PIN 6 หลัก'), findsOneWidget);
    expect(find.text('กรอกแล้ว 0/6 หลัก'), findsOneWidget);

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(claimRepository.createCalls, 1);
    expect(claimRepository.createdAwardIds, ['award_1']);
    expect(claimRepository.createdMethods, [
      ActivityClaimPayoutMethod.bankTransfer,
    ]);
    expect(claimRepository.createdPins, ['123456']);
    expect(claimRepository.createdAssertionTokens, ['']);
    expect(claimRepository.createdBankAccounts.single?.toJson(), {
      'bank_name': 'ธนาคารกสิกรไทย',
      'account_name': 'Demo Customer',
      'account_number': '1234567890',
    });
    expect(find.text('Activity claim detail route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity claim sheet submits biometric assertion token', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);
    final claimRepository = _CaptureActivityClaimRepository();
    final biometric = _FakeBiometricAuthService('assertion_activity_1');

    await _pumpDetail(
      tester,
      repository,
      profileRepository: _CompleteRewardBankProfileRepository(),
      activityClaimRepository: claimRepository,
      biometricAuth: biometric,
      platformKey: 'ios',
      biometricEnabled: true,
    );
    await tester.pumpAndSettle();

    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'รับเงิน'),
    );
    claimButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('รับเงินกิจกรรม'), findsOneWidget);
    expect(find.text('ยอดที่รับได้'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ถัดไป'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('ใส่รหัส PIN 6 หลัก'), findsOneWidget);
    expect(find.text('เพื่อรับเงินรางวัลกิจกรรม'), findsOneWidget);
    expect(find.text('กรอกแล้ว 0/6 หลัก'), findsOneWidget);
    expect(find.text('รับเงินรางวัลกิจกรรม'), findsNothing);
    expect(find.text('ใช้ Face ID / Biometric'), findsOneWidget);

    await tester.tap(find.text('ใช้ Face ID / Biometric'));
    await tester.pumpAndSettle();

    expect(biometric.calls, 1);
    expect(biometric.purposes, ['activity_claim']);
    expect(claimRepository.createCalls, 1);
    expect(claimRepository.createdAwardIds, ['award_1']);
    expect(claimRepository.createdMethods, [
      ActivityClaimPayoutMethod.walletCredit,
    ]);
    expect(claimRepository.createdPins, ['']);
    expect(claimRepository.createdAssertionTokens, ['assertion_activity_1']);
    expect(find.text('Activity claim detail route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity claim PIN setup error uses Nuxt copy', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);
    final claimRepository = _CaptureActivityClaimRepository(
      createError: _apiException('', code: 'pin_setup_required'),
    );

    await _pumpDetail(
      tester,
      repository,
      profileRepository: _CompleteRewardBankProfileRepository(),
      activityClaimRepository: claimRepository,
    );
    await tester.pumpAndSettle();

    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'รับเงิน'),
    );
    claimButton.onPressed!();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'ถัดไป'));
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(claimRepository.createCalls, 1);
    expect(find.text('กรุณาตั้งค่า PIN ก่อนทำรายการ'), findsOneWidget);
    expect(find.text('กรอกแล้ว 0/6 หลัก'), findsOneWidget);
    expect(find.text('Activity claim detail route'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  ActivityRepository repository, {
  ProfileSettingsRepository? profileRepository,
  ActivityClaimRepository? activityClaimRepository,
  BiometricAuthService? biometricAuth,
  String? platformKey,
  bool biometricEnabled = false,
  String initialLocation = '/activities/lucky-board',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/activities',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Activities route')),
        ),
      ),
      GoRoute(
        path: '/activities/history',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'History route: ${state.uri.queryParameters['game_id'] ?? ''}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/activities/:slug',
        builder: (context, state) => ActivityDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
          backPath: activityDetailBackPath(
            from: state.uri.queryParameters['from'] ?? '',
            gameId: state.uri.queryParameters['game_id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Tickets')),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profile')),
        ),
      ),
      GoRoute(
        path: '/profile/reward-bank',
        builder: (context, state) => Scaffold(
          body: Center(child: Text(state.uri.toString())),
        ),
      ),
      GoRoute(
        path: '/activity-claims/:claimId',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Activity claim detail route')),
        ),
      ),
    ],
  );

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
        authControllerProvider.overrideWith((_) => _authenticatedController()),
        activityRepositoryProvider.overrideWithValue(repository),
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson({
            'site': {'display_name': 'Customer', 'locale': 'th-TH'},
            'mobile': {
              'lottery_product_label': 'L6',
              if (biometricEnabled) ...{
                'biometric': {
                  'enabled': true,
                  'platforms': {
                    'ios': ['face_id'],
                  },
                },
                'feature_flags': {'native_biometric_unlock': true},
              },
            },
          }),
        ),
        if (platformKey != null)
          customerPlatformKeyProvider.overrideWithValue(platformKey),
        if (activityClaimRepository != null)
          activityClaimRepositoryProvider.overrideWithValue(
            activityClaimRepository,
          ),
        if (biometricAuth != null)
          biometricAuthServiceProvider.overrideWithValue(biometricAuth),
        if (profileRepository != null)
          profileSettingsRepositoryProvider.overrideWithValue(
            profileRepository,
          ),
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
      ),
    ),
  );
}

Future<void> _tapLuckyNumber(WidgetTester tester, String number) async {
  final finder = find.text(number);
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

class _PendingActivityRepository extends ActivityRepository {
  _PendingActivityRepository() : super(_testApiClient(), (value) => value);

  final completer = Completer<ActivityItem>();

  @override
  Future<ActivityItem> detail(String slug, {bool authenticated = false}) {
    return completer.future;
  }
}

class _ErrorActivityRepository extends ActivityRepository {
  _ErrorActivityRepository({Object? error})
      : error = error ?? Exception('activity detail failed'),
        super(_testApiClient(), (value) => value);

  final Object error;

  @override
  Future<ActivityItem> detail(String slug, {bool authenticated = false}) async {
    throw error;
  }
}

class _MissingActivityRepository extends ActivityRepository {
  _MissingActivityRepository() : super(_testApiClient(), (value) => value);

  @override
  Future<ActivityItem> detail(String slug, {bool authenticated = false}) async {
    return const ActivityItem(
      id: '',
      name: '',
      slug: '',
      type: '',
      imageUrl: '',
      conditionText: '',
      remainingNumbers: 0,
      hasRight: false,
      estimatedCashbackAmount: 0,
      rights: ActivityRights(
        earnedCount: 0,
        usedCount: 0,
        remainingCount: 0,
        ticketCount: 0,
        availableTicketCount: 0,
        consumedTicketCount: 0,
        qualifyingOrderCount: 0,
        eligibilityRule: '',
        thresholdTickets: 0,
        entryDeadlineAt: null,
        entryClosed: false,
      ),
      entries: [],
      numberBoard: ActivityNumberBoard(
        predictionType: '',
        digits: 2,
        totalCount: 0,
        reservedCount: 0,
        remainingCount: 0,
        reservedNumbers: {},
      ),
      resultSummary: null,
    );
  }
}

class _MissingRewardBankProfileRepository extends ProfileSettingsRepository {
  _MissingRewardBankProfileRepository() : super(_testApiClient());

  @override
  Future<CustomerProfileSettings> load() async {
    return const CustomerProfileSettings(
      id: 'customer_1',
      name: 'Demo Customer',
      customerNo: 'C-001',
      phone: '0800000000',
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
    );
  }
}

class _PendingRewardBankProfileRepository extends ProfileSettingsRepository {
  _PendingRewardBankProfileRepository() : super(_testApiClient());

  final completer = Completer<CustomerProfileSettings>();

  @override
  Future<CustomerProfileSettings> load() {
    return completer.future;
  }
}

class _CompleteRewardBankProfileRepository extends ProfileSettingsRepository {
  _CompleteRewardBankProfileRepository() : super(_testApiClient());

  @override
  Future<CustomerProfileSettings> load() async {
    return const CustomerProfileSettings(
      id: 'customer_1',
      name: 'Demo Customer',
      customerNo: 'C-001',
      phone: '0800000000',
      walletId: 'wallet_123',
      bankAccount: RewardBankAccount(
        bankName: 'ธนาคารกสิกรไทย',
        accountName: 'Demo Customer',
        accountNumber: '1234567890',
      ),
      autoReward: AutoRewardSetting(
        enabled: false,
        payoutMethod: '',
        type: '',
      ),
    );
  }
}

class _CaptureActivityClaimRepository extends ActivityClaimRepository {
  _CaptureActivityClaimRepository({this.createError}) : super(_testApiClient());

  final Object? createError;

  int createCalls = 0;
  final createdAwardIds = <String>[];
  final createdMethods = <ActivityClaimPayoutMethod>[];
  final createdPins = <String>[];
  final createdAssertionTokens = <String>[];
  final createdBankAccounts = <RewardBankAccount?>[];

  @override
  Future<ActivityClaimItem> create({
    required String awardId,
    required ActivityClaimPayoutMethod payoutMethod,
    String? pin,
    String? pinAssertionToken,
    RewardBankAccount? bankAccount,
    String note = '',
  }) async {
    createCalls++;
    createdAwardIds.add(awardId);
    createdMethods.add(payoutMethod);
    createdPins.add(pin ?? '');
    createdAssertionTokens.add(pinAssertionToken ?? '');
    createdBankAccounts.add(bankAccount);

    final error = createError;
    if (error != null) throw error;

    return ActivityClaimItem.fromJson({
      'id': 'activity_claim_biometric',
      'reference': 'ACL-BIO-001',
      'status': 'submitted',
      'payout_method': payoutMethod.apiValue,
      'claim_amount': {'amount': 200000, 'currency': 'THB'},
      'award': {
        'id': awardId,
        'activity_name': 'กิจกรรมทายเลข 2 ตัว',
        'type': 'lucky_board',
        'prediction_type': 'last2',
        'amount': {'amount': 200000, 'currency': 'THB'},
      },
    });
  }
}

class _FakeBiometricAuthService extends BiometricAuthService {
  _FakeBiometricAuthService(this.assertionToken) : super(_testApiClient());

  final String assertionToken;
  int calls = 0;
  final purposes = <String>[];

  @override
  Future<String?> requestPinAssertion({
    String purpose = 'pin_unlock',
    required String localizedReason,
  }) async {
    calls++;
    purposes.add(purpose);
    return assertionToken;
  }
}

class _FakeActivityRepository extends ActivityRepository {
  _FakeActivityRepository({required this.resultAnnounced, this.entryError})
      : super(_testApiClient(), (value) => value);

  final bool resultAnnounced;
  final Object? entryError;
  int detailCount = 0;
  int awardsAllCount = 0;
  int createEntryCount = 0;
  final createdActivityIds = <String>[];
  final createdPredictionTypes = <String>[];
  final createdSelectedNumbers = <String>[];

  @override
  Future<ActivityItem> detail(String slug, {bool authenticated = false}) async {
    detailCount++;
    return _activityFixture(resultAnnounced: resultAnnounced);
  }

  @override
  Future<List<ActivityAwardItem>> awardsAll({
    int limit = ActivityRepository.defaultAwardPageLimit,
    int maxPages = ActivityRepository.maxAwardAutoPages,
    String? status,
  }) async {
    awardsAllCount++;
    return const [
      ActivityAwardItem(
        id: 'award_1',
        activityId: 'act_lucky',
        activityName: 'กิจกรรมทายเลข 2 ตัว',
        type: 'lucky_board',
        predictionType: 'last2',
        amount: 2000,
        status: 'claimable',
        claimId: '',
        calculatedAt: null,
      ),
    ];
  }

  @override
  Future<ActivityEntry> createEntry({
    required String activityId,
    required String predictionType,
    required String selectedNumber,
  }) async {
    createEntryCount++;
    createdActivityIds.add(activityId);
    createdPredictionTypes.add(predictionType);
    createdSelectedNumbers.add(selectedNumber);
    final error = entryError;
    if (error != null) throw error;
    return ActivityEntry(
      id: 'entry_created_$createEntryCount',
      predictionType: predictionType,
      selectedNumber: selectedNumber,
      status: 'submitted',
      createdAt: null,
    );
  }
}

class _CashbackActivityRepository extends ActivityRepository {
  _CashbackActivityRepository() : super(_testApiClient(), (value) => value);

  int detailCount = 0;
  int awardsAllCount = 0;

  @override
  Future<ActivityItem> detail(String slug, {bool authenticated = false}) async {
    detailCount++;
    return _cashbackActivityFixture();
  }

  @override
  Future<List<ActivityAwardItem>> awardsAll({
    int limit = ActivityRepository.defaultAwardPageLimit,
    int maxPages = ActivityRepository.maxAwardAutoPages,
    String? status,
  }) async {
    awardsAllCount++;
    return const [];
  }
}

ActivityItem _activityFixture({required bool resultAnnounced}) {
  return ActivityItem(
    id: 'act_lucky',
    name: 'กิจกรรมทายเลข 2 ตัว',
    slug: 'lucky-board',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 97,
    hasRight: true,
    estimatedCashbackAmount: 0,
    rights: const ActivityRights(
      earnedCount: 2,
      usedCount: 1,
      remainingCount: 1,
      ticketCount: 20,
      availableTicketCount: 10,
      consumedTicketCount: 10,
      qualifyingOrderCount: 0,
      eligibilityRule: 'cumulative_tickets',
      thresholdTickets: 10,
      entryDeadlineAt: null,
      entryClosed: false,
    ),
    entries: const [
      ActivityEntry(
        id: 'entry_1',
        predictionType: 'last2',
        selectedNumber: '24',
        status: 'submitted',
        createdAt: null,
      ),
    ],
    numberBoard: const ActivityNumberBoard(
      predictionType: 'last2',
      digits: 2,
      totalCount: 100,
      reservedCount: 3,
      remainingCount: 97,
      reservedNumbers: {'01', '02', '03'},
    ),
    resultSummary: resultAnnounced
        ? const ActivityResultSummary(
            status: 'announced',
            predictionType: 'last2',
            winningNumber: '24',
            winningNumbers: ['24'],
            winnerCount: 1,
            awardTotal: 2000,
            customerStatus: 'won',
            customerWinningNumbers: ['24'],
            customerAwardAmount: 2000,
          )
        : null,
  );
}

const _cashbackResultAt = '2026-07-30T18:15:00+07:00';

ActivityItem _cashbackActivityFixture() {
  return const ActivityItem(
    id: 'act_cashback',
    name: 'คืนเงิน 5%',
    slug: 'cashback-5',
    type: 'cashback',
    imageUrl: '',
    conditionText: '',
    remainingNumbers: 0,
    hasRight: true,
    estimatedCashbackAmount: 50,
    resultAt: _cashbackResultAt,
    rights: ActivityRights(
      earnedCount: 0,
      usedCount: 0,
      remainingCount: 0,
      ticketCount: 12,
      availableTicketCount: 12,
      consumedTicketCount: 0,
      qualifyingOrderCount: 1,
      eligibilityRule: 'purchase_amount',
      thresholdTickets: 0,
      entryDeadlineAt: null,
      entryClosed: false,
    ),
    config: ActivityConfig(
      predictionType: '',
      eligibilityRule: 'purchase_amount',
      thresholdTickets: 0,
      cashbackType: 'percent',
      cashbackPercentBps: 500,
      fixedAmount: 0,
      minimumType: 'amount',
      minTicketCount: 0,
      minPurchaseAmount: 500,
    ),
    cashbackProgress: ActivityCashbackProgress(
      ticketCount: 12,
      purchaseAmount: 1200,
      minimumType: 'amount',
      minTicketCount: 0,
      minPurchaseAmount: 500,
      isEligible: true,
      estimatedAmount: 60,
      potentialAmount: 60,
    ),
  );
}

DioException _apiException(String message, {String code = ''}) {
  final requestOptions = RequestOptions(path: '/customer/activities/act_lucky');
  final data = <String, dynamic>{
    if (message.isNotEmpty) 'message': message,
    if (code.isNotEmpty)
      'error': {
        'code': code,
        if (message.isNotEmpty) 'message': message,
      },
  };
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 422,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}

AuthController _authenticatedController() {
  final tokenStore = AuthTokenStore();
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = false;
}

ApiClient _testApiClient([AuthTokenStore? tokenStore]) {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
