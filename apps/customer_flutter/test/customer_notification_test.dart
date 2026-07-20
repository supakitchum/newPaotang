import 'dart:async';

import 'package:customer_flutter/app/customer_routes.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/notifications/customer_push_installation_store.dart';
import 'package:customer_flutter/core/notifications/customer_push_lifecycle_monitor.dart';
import 'package:customer_flutter/core/notifications/customer_push_platform.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/features/notifications/data/customer_notification_repository.dart';
import 'package:customer_flutter/features/notifications/data/customer_notification_models.dart';
import 'package:customer_flutter/features/notifications/presentation/customer_notification_navigation.dart';
import 'package:customer_flutter/features/notifications/presentation/customer_notification_realtime_monitor.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('notification page parses authoritative read and cursor state', () {
    final page = CustomerNotificationPage.fromJson({
      'data': [
        {
          'id': 'cnt_01',
          'category': 'topup',
          'event_key': 'topup.approved',
          'title': 'เติมเงินสำเร็จ',
          'body': 'ยอดเงินเข้ากระเป๋าแล้ว',
          'icon_key': 'topup',
          'action': {'key': 'topup', 'entity_id': 'top_01'},
          'subject': {'type': 'topup', 'id': 'top_01'},
          'is_read': false,
          'created_at': '2026-07-21T10:00:00+07:00',
        },
      ],
      'meta': {'next_cursor': 'cnr_01', 'has_more': true, 'unread_count': 7},
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'cnt_01');
    expect(page.items.single.isRead, isFalse);
    expect(page.items.single.action.entityId, 'top_01');
    expect(page.nextCursor, 'cnr_01');
    expect(page.hasMore, isTrue);
    expect(page.unreadCount, 7);
  });

  test('notification action map only produces allowlisted in-app routes', () {
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(key: 'ticket', entityId: 'tic 01'),
      ),
      '/tickets/view?id=tic+01',
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(key: 'news', entityId: 'tenant-news'),
      ),
      '/news/tenant-news',
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(
          key: 'https://evil.invalid',
          entityId: 'https://evil.invalid',
        ),
      ),
      isNull,
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(
          key: 'checkout_pending',
          entityId: 'ord 01',
        ),
      ),
      '/checkout/pending?order_id=ord+01',
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(key: 'order', entityId: 'ord/02'),
      ),
      '/purchase-history/ord%2F02',
    );
    expect(isSensitiveCustomerPath('/notifications'), isTrue);
  });

  test(
    'native push payload accepts server keys and rejects no route itself',
    () {
      final message = CustomerPushMessage.fromMap({
        'notification_id': 'cnt_push_1',
        'action_key': 'reward_claim',
        'action_entity_id': 'rcl_push_1',
        'title': 'Reward approved',
        'body': 'Open your claim.',
      });

      expect(message.notificationId, 'cnt_push_1');
      expect(message.actionKey, 'reward_claim');
      expect(message.actionEntityId, 'rcl_push_1');
      expect(message.title, 'Reward approved');
      expect(message.body, 'Open your claim.');
      expect(
        customerNotificationRoute(
          CustomerNotificationAction(
            key: message.actionKey,
            entityId: message.actionEntityId,
          ),
        ),
        '/reward-claims/rcl_push_1',
      );
    },
  );

  test('notification realtime events trigger server refetch behavior', () {
    expect(
      shouldRefreshNotificationsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'customer.notification.created',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.notifications',
          payload: {'notification_id': 'cnt_1', 'unread_count': 1},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshNotificationsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'wallet.updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.wallet',
          payload: {},
        ),
      ),
      isFalse,
    );
  });

  testWidgets(
    'native push lifecycle registers refreshes opens and revokes one installation',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final foreground = StreamController<CustomerPushMessage>.broadcast();
        final taps = StreamController<CustomerPushMessage>.broadcast();
        final tokenRefresh = StreamController<String>.broadcast();
        addTearDown(foreground.close);
        addTearDown(taps.close);
        addTearDown(tokenRefresh.close);

        var permissionRequests = 0;
        final platform = CustomerPushPlatform.test(
          foregroundMessages: foreground.stream,
          notificationTaps: taps.stream,
          tokenRefresh: tokenRefresh.stream,
          requestPermission: () async {
            permissionRequests += 1;
            return _authorizedNotificationSettings;
          },
          token: () async => 'fcm-token-initial-1234567890',
        );
        addTearDown(platform.dispose);

        final tokenStore = AuthTokenStore();
        final api = ApiClient(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          tokenStore,
          localeTag: 'th-TH',
        );
        final auth =
            AuthController(
                authRepository: _PushAuthRepository(
                  api: api,
                  tokenStore: tokenStore,
                ),
                tokenStore: tokenStore,
                biometricAuth: BiometricAuthService(api),
              )
              ..isAuthenticated = true
              ..pinRequired = false
              ..pinSetupRequired = false;
        final repository = _PushNotificationRepository(api);
        final installationStore = _PushInstallationStore();
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('home')),
            GoRoute(
              path: '/notifications',
              builder: (_, __) => const Text('notifications'),
            ),
            GoRoute(
              path: '/my-wallet',
              builder: (_, __) => const Text('wallet'),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(
                  apiBaseUrl: 'https://partner.example.test/api/v1',
                  defaultLocale: 'th-TH',
                ),
              ),
              authControllerProvider.overrideWith((_) => auth),
              customerPushPlatformProvider.overrideWithValue(platform),
              customerPushInstallationStoreProvider.overrideWithValue(
                installationStore,
              ),
              customerNotificationRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => CustomerPushLifecycleMonitor(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(permissionRequests, 1);
        expect(installationStore.markedPermissionRequested, isTrue);
        expect(repository.registeredTokens, ['fcm-token-initial-1234567890']);

        tokenRefresh.add('fcm-token-refreshed-1234567890');
        await tester.pumpAndSettle();
        expect(repository.registeredTokens, [
          'fcm-token-initial-1234567890',
          'fcm-token-refreshed-1234567890',
        ]);

        foreground.add(
          const CustomerPushMessage(
            notificationId: 'cnt_foreground',
            actionKey: 'home',
            actionEntityId: '',
            title: 'Updated',
            body: 'Inbox refreshed',
          ),
        );
        await tester.pump();

        taps.add(
          const CustomerPushMessage(
            notificationId: 'cnt_wallet',
            actionKey: 'wallet',
            actionEntityId: '',
            title: 'Wallet updated',
            body: 'Open wallet',
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.readNotificationIds, ['cnt_wallet']);
        expect(router.routeInformationProvider.value.uri.path, '/my-wallet');

        await auth.logout();
        await tester.pumpAndSettle();
        expect(repository.revokedInstallationIds, ['install_push_test_001']);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

const _authorizedNotificationSettings = NotificationSettings(
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.disabled,
  authorizationStatus: AuthorizationStatus.authorized,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);

class _PushInstallationStore extends CustomerPushInstallationStore {
  _PushInstallationStore() : super(storageScope: 'push-test');

  bool markedPermissionRequested = false;

  @override
  Future<String> installationId() async => 'install_push_test_001';

  @override
  Future<bool> permissionRequested() async => markedPermissionRequested;

  @override
  Future<void> markPermissionRequested() async {
    markedPermissionRequested = true;
  }
}

class _PushNotificationRepository extends CustomerNotificationRepository {
  _PushNotificationRepository(super.api);

  final List<String> registeredTokens = [];
  final List<String> readNotificationIds = [];
  final List<String> revokedInstallationIds = [];

  @override
  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String fcmToken,
    required String locale,
    String appVersion = '',
    String deviceName = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    expect(installationId, 'install_push_test_001');
    expect(platform, 'android');
    registeredTokens.add(fcmToken);
  }

  @override
  Future<CustomerNotificationItem> markRead(String notificationId) async {
    readNotificationIds.add(notificationId);
    return CustomerNotificationItem.fromJson({
      'id': notificationId,
      'title': 'Read',
      'body': '',
      'is_read': true,
      'action': const {'key': 'wallet'},
    });
  }

  @override
  Future<void> revokeDevice(String installationId) async {
    revokedInstallationIds.add(installationId);
  }
}

class _PushAuthRepository extends AuthRepository {
  _PushAuthRepository({required super.api, required super.tokenStore});

  @override
  Future<void> logout() async {}
}
