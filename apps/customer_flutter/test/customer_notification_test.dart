import 'dart:async';

import 'package:customer_flutter/app/customer_routes.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/notifications/customer_push_installation_store.dart';
import 'package:customer_flutter/core/notifications/customer_push_lifecycle_monitor.dart';
import 'package:customer_flutter/core/notifications/customer_push_device_context.dart';
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
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(
          key: 'support_ticket',
          entityId: 'stic/01',
        ),
      ),
      '/support/tickets/stic%2F01',
    );
    expect(
      customerNotificationRoute(
        const CustomerNotificationAction(key: 'support'),
      ),
      '/support',
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

  test('push device context signature is stable across metadata key order', () {
    const first = CustomerPushDeviceContext(
      appVersion: '2.4.1+87',
      deviceName: 'Google Pixel 9',
      metadata: {'os_name': 'Android', 'os_version': '16'},
    );
    const reordered = CustomerPushDeviceContext(
      appVersion: '2.4.1+87',
      deviceName: 'Google Pixel 9',
      metadata: {'os_version': '16', 'os_name': 'Android'},
    );

    expect(first.registrationSignature, reordered.registrationSignature);
  });

  test('push device context stays inside the server privacy contract', () {
    final context = CustomerPushDeviceContext.normalized(
      appVersion: '  ${'v' * 80}  ',
      deviceName: ' ${'รุ่น' * 120} ',
      metadata: {
        'app_build_number': '9' * 80,
        'os_name': 'Android' * 20,
        'os_version': '16' * 80,
        'manufacturer': 'Maker' * 80,
        'device_model': 'Model' * 80,
        'device_machine': 'Machine' * 80,
        'os_sdk': 36,
        'is_physical_device': true,
        'identifier_for_vendor': 'must-not-leave-device',
      },
    );

    expect(context.appVersion.runes.length, 40);
    expect(context.deviceName.runes.length, 255);
    expect(context.metadata['app_build_number'].toString().runes.length, 40);
    expect(context.metadata['os_name'].toString().runes.length, 40);
    expect(context.metadata['os_version'].toString().runes.length, 80);
    expect(context.metadata['manufacturer'].toString().runes.length, 120);
    expect(context.metadata['device_model'].toString().runes.length, 160);
    expect(context.metadata['device_machine'].toString().runes.length, 160);
    expect(context.metadata['os_sdk'], 36);
    expect(context.metadata['is_physical_device'], isTrue);
    expect(context.metadata, isNot(contains('identifier_for_vendor')));
  });

  test(
    'mock FCM remote handlers parse foreground and tap messages safely',
    () async {
      final foregroundRemote = StreamController<RemoteMessage>.broadcast();
      final tapRemote = StreamController<RemoteMessage>.broadcast();
      final foreground = <CustomerPushMessage>[];
      final taps = <CustomerPushMessage>[];
      final banners = <CustomerPushMessage>[];
      addTearDown(foregroundRemote.close);
      addTearDown(tapRemote.close);

      final platform = CustomerPushPlatform.test(
        remoteForegroundMessages: foregroundRemote.stream,
        remoteNotificationTaps: tapRemote.stream,
        localNotificationsReady: true,
        showForegroundNotification: (message) async {
          banners.add(message);
          throw StateError('mock local banner unavailable');
        },
      );
      addTearDown(platform.dispose);
      final foregroundSubscription = platform.foregroundMessages.listen(
        foreground.add,
      );
      final tapSubscription = platform.notificationTaps.listen(taps.add);
      addTearDown(foregroundSubscription.cancel);
      addTearDown(tapSubscription.cancel);

      const message = RemoteMessage(
        data: {
          'notification_id': 'cnt_remote_1',
          'action_key': 'wallet',
          'action_entity_id': '',
        },
        notification: RemoteNotification(
          title: 'Wallet updated',
          body: 'Open your wallet.',
        ),
      );
      foregroundRemote.add(message);
      tapRemote.add(message);
      await Future<void>.delayed(Duration.zero);

      expect(foreground, hasLength(1));
      expect(foreground.single.notificationId, 'cnt_remote_1');
      expect(foreground.single.title, 'Wallet updated');
      expect(banners, hasLength(1));
      expect(taps, hasLength(1));
      expect(taps.single.actionKey, 'wallet');
    },
  );

  test(
    'background FCM handler contains missing native configuration',
    () async {
      await expectLater(
        customerFirebaseMessagingBackgroundHandler(
          const RemoteMessage(data: {'notification_id': 'cnt_background'}),
        ),
        completes,
      );
    },
  );

  test('push device context loader reads optional diagnostics once', () async {
    var reads = 0;
    final loader = CustomerPushDeviceContextLoader(
      load: () async {
        reads += 1;
        return const CustomerPushDeviceContext(appVersion: '2.4.1+87');
      },
    );

    final first = await loader.load();
    final second = await loader.load();

    expect(reads, 1);
    expect(identical(first, second), isTrue);
  });

  testWidgets(
    'native push lifecycle registers refreshes opens and cleans up logout token',
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
        var deletedTokens = 0;
        final platform = CustomerPushPlatform.test(
          foregroundMessages: foreground.stream,
          notificationTaps: taps.stream,
          tokenRefresh: tokenRefresh.stream,
          requestPermission: () async {
            permissionRequests += 1;
            return _authorizedNotificationSettings;
          },
          token: () async => 'fcm-token-initial-1234567890',
          deleteToken: () async {
            deletedTokens += 1;
          },
        );
        addTearDown(platform.dispose);

        final tokenStore = AuthTokenStore();
        final logoutGate = Completer<void>();
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
                  logoutGate: logoutGate,
                ),
                tokenStore: tokenStore,
                biometricAuth: BiometricAuthService(api),
              )
              ..isAuthenticated = true
              ..pinRequired = false
              ..pinSetupRequired = false;
        final repository = _PushNotificationRepository(api, failRevoke: true);
        final installationStore = _PushInstallationStore();
        final deviceContextLoader = CustomerPushDeviceContextLoader(
          load: () async => const CustomerPushDeviceContext(
            appVersion: '2.4.1+87',
            deviceName: 'Google Pixel 9',
            metadata: {
              'os_name': 'Android',
              'os_version': '16',
              'is_physical_device': true,
            },
          ),
        );
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
              customerPushDeviceContextLoaderProvider.overrideWithValue(
                deviceContextLoader,
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
        expect(repository.registeredInstallationIds, ['install_push_test_001']);
        expect(repository.registeredPlatforms, ['android']);
        expect(repository.registeredAppVersions, ['2.4.1+87']);
        expect(repository.registeredDeviceNames, ['Google Pixel 9']);
        expect(repository.registeredMetadata.single, {
          'os_name': 'Android',
          'os_version': '16',
          'is_physical_device': true,
        });

        tokenRefresh.add('fcm-token-refreshed-1234567890');
        await tester.pumpAndSettle();
        expect(repository.registeredTokens, [
          'fcm-token-initial-1234567890',
          'fcm-token-refreshed-1234567890',
        ]);
        expect(repository.registeredAppVersions, ['2.4.1+87', '2.4.1+87']);
        expect(repository.registeredDeviceNames, [
          'Google Pixel 9',
          'Google Pixel 9',
        ]);
        expect(repository.registeredMetadata, [
          {
            'os_name': 'Android',
            'os_version': '16',
            'is_physical_device': true,
          },
          {
            'os_name': 'Android',
            'os_version': '16',
            'is_physical_device': true,
          },
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

        final logout = auth.logout();
        await tester.pump();
        expect(repository.revokedInstallationIds, ['install_push_test_001']);
        expect(deletedTokens, 1);

        tokenRefresh.add('fcm-token-during-logout-1234567890');
        await tester.pump();
        expect(repository.registeredTokens, [
          'fcm-token-initial-1234567890',
          'fcm-token-refreshed-1234567890',
        ]);

        logoutGate.complete();
        await logout;
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'initial notification tap opens after auth unlock when push permission is denied',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var permissionRequests = 0;
        var tokenReads = 0;
        final platform = CustomerPushPlatform.test(
          initialTap: const CustomerPushMessage(
            notificationId: 'cnt_denied_initial',
            actionKey: 'wallet',
            actionEntityId: '',
            title: 'Wallet',
            body: 'Updated',
          ),
          requestPermission: () async {
            permissionRequests += 1;
            return _deniedNotificationSettings;
          },
          token: () async {
            tokenReads += 1;
            return 'token-must-not-register';
          },
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
                _PushInstallationStore(),
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
        expect(tokenReads, 0);
        expect(repository.registeredTokens, isEmpty);
        expect(repository.readNotificationIds, ['cnt_denied_initial']);
        expect(router.routeInformationProvider.value.uri.path, '/my-wallet');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'native push retries and refreshes registration when the app resumes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var permissionRequests = 0;
        var settingsReads = 0;
        var tokenReads = 0;
        var currentTime = DateTime.utc(2026, 7, 21);
        final platform = CustomerPushPlatform.test(
          requestPermission: () async {
            permissionRequests += 1;
            return _authorizedNotificationSettings;
          },
          notificationSettings: () async {
            settingsReads += 1;
            return _authorizedNotificationSettings;
          },
          token: () async {
            tokenReads += 1;
            if (tokenReads == 1) throw StateError('APNs token is not ready');
            return 'fcm-token-after-resume-1234567890';
          },
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
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, __) => const Text('home'))],
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
                _PushInstallationStore(),
              ),
              customerPushRegistrationClockProvider.overrideWithValue(
                () => currentTime,
              ),
              customerPushDeviceContextLoaderProvider.overrideWithValue(
                _emptyPushDeviceContextLoader(),
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
        expect(tokenReads, 1);
        expect(repository.registeredTokens, isEmpty);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CustomerPushLifecycleMonitor)),
        );
        expect(container.read(customerNotificationRealtimeTickProvider), 0);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(container.read(customerNotificationRealtimeTickProvider), 1);
        expect(settingsReads, 1);
        expect(tokenReads, 2);
        expect(repository.registeredTokens, [
          'fcm-token-after-resume-1234567890',
        ]);
        expect(repository.registeredInstallationIds, ['install_push_test_001']);
        expect(repository.registeredPlatforms, ['android']);

        currentTime = currentTime.add(const Duration(days: 31));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(container.read(customerNotificationRealtimeTickProvider), 2);
        expect(settingsReads, 2);
        expect(tokenReads, 3);
        expect(repository.registeredTokens, [
          'fcm-token-after-resume-1234567890',
          'fcm-token-after-resume-1234567890',
        ]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('token refresh failure is retried on resume without escaping', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final tokenRefresh = StreamController<String>.broadcast();
      addTearDown(tokenRefresh.close);
      var currentToken = 'fcm-token-before-refresh-1234567890';
      final platform = CustomerPushPlatform.test(
        tokenRefresh: tokenRefresh.stream,
        requestPermission: () async => _authorizedNotificationSettings,
        notificationSettings: () async => _authorizedNotificationSettings,
        token: () async => currentToken,
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
      final repository = _PushNotificationRepository(
        api,
        failRegistrationTokensOnce: {'fcm-token-after-refresh-1234567890'},
      );
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const Text('home'))],
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
              _PushInstallationStore(),
            ),
            customerPushDeviceContextLoaderProvider.overrideWithValue(
              _emptyPushDeviceContextLoader(),
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

      currentToken = 'fcm-token-after-refresh-1234567890';
      tokenRefresh.add(currentToken);
      await tester.pumpAndSettle();

      expect(repository.registrationAttempts, [
        'fcm-token-before-refresh-1234567890',
        'fcm-token-after-refresh-1234567890',
      ]);
      expect(repository.registeredTokens, [
        'fcm-token-before-refresh-1234567890',
      ]);
      expect(tester.takeException(), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.registrationAttempts, [
        'fcm-token-before-refresh-1234567890',
        'fcm-token-after-refresh-1234567890',
        'fcm-token-after-refresh-1234567890',
      ]);
      expect(repository.registeredTokens, [
        'fcm-token-before-refresh-1234567890',
        'fcm-token-after-refresh-1234567890',
      ]);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'logout waits for in-flight token refresh registration before revoking',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final tokenRefresh = StreamController<String>.broadcast();
        addTearDown(tokenRefresh.close);
        var deletedTokens = 0;
        final platform = CustomerPushPlatform.test(
          tokenRefresh: tokenRefresh.stream,
          requestPermission: () async => _authorizedNotificationSettings,
          notificationSettings: () async => _authorizedNotificationSettings,
          token: () async => 'fcm-token-before-logout-race-1234567890',
          deleteToken: () async {
            deletedTokens += 1;
          },
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
        final repository = _GatedPushNotificationRepository(api);
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, __) => const Text('home'))],
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
                _PushInstallationStore(),
              ),
              customerPushDeviceContextLoaderProvider.overrideWithValue(
                _emptyPushDeviceContextLoader(),
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
        expect(repository.lifecycleOperations, [
          'register:fcm-token-before-logout-race-1234567890',
        ]);

        final refreshStarted = Completer<void>();
        final refreshGate = Completer<void>();
        repository
          ..registrationStarted = refreshStarted
          ..registrationGate = refreshGate;
        tokenRefresh.add('fcm-token-during-logout-race-1234567890');
        for (
          var index = 0;
          index < 10 && !refreshStarted.isCompleted;
          index++
        ) {
          await tester.pump();
        }
        expect(refreshStarted.isCompleted, isTrue);

        final logout = auth.logout();
        await tester.pump();
        expect(repository.revokedInstallationIds, isEmpty);
        expect(deletedTokens, 0);

        refreshGate.complete();
        await tester.pumpAndSettle();
        await logout;

        expect(repository.lifecycleOperations, [
          'register:fcm-token-before-logout-race-1234567890',
          'register:fcm-token-during-logout-race-1234567890',
          'revoke:install_push_test_001',
        ]);
        expect(repository.revokedInstallationIds, ['install_push_test_001']);
        expect(deletedTokens, 1);
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

const _deniedNotificationSettings = NotificationSettings(
  alert: AppleNotificationSetting.disabled,
  announcement: AppleNotificationSetting.disabled,
  authorizationStatus: AuthorizationStatus.denied,
  badge: AppleNotificationSetting.disabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.disabled,
  notificationCenter: AppleNotificationSetting.disabled,
  showPreviews: AppleShowPreviewSetting.never,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.disabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);

CustomerPushDeviceContextLoader _emptyPushDeviceContextLoader() {
  return CustomerPushDeviceContextLoader(
    load: () async => const CustomerPushDeviceContext(),
  );
}

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
  _PushNotificationRepository(
    super.api, {
    this.failRevoke = false,
    Set<String> failRegistrationTokensOnce = const {},
  }) : failRegistrationTokensOnce = {...failRegistrationTokensOnce};

  final bool failRevoke;
  final Set<String> failRegistrationTokensOnce;

  final List<String> registeredTokens = [];
  final List<String> registrationAttempts = [];
  final List<String> registeredInstallationIds = [];
  final List<String> registeredPlatforms = [];
  final List<String> registeredAppVersions = [];
  final List<String> registeredDeviceNames = [];
  final List<Map<String, dynamic>> registeredMetadata = [];
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
    registrationAttempts.add(fcmToken);
    if (failRegistrationTokensOnce.remove(fcmToken)) {
      throw StateError('device registration offline');
    }
    registeredInstallationIds.add(installationId);
    registeredPlatforms.add(platform);
    registeredAppVersions.add(appVersion);
    registeredDeviceNames.add(deviceName);
    registeredMetadata.add(Map<String, dynamic>.from(metadata));
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
    if (failRevoke) throw StateError('offline revoke');
  }
}

class _GatedPushNotificationRepository extends _PushNotificationRepository {
  _GatedPushNotificationRepository(super.api);

  Completer<void>? registrationStarted;
  Completer<void>? registrationGate;
  final List<String> lifecycleOperations = [];

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
    final started = registrationStarted;
    if (started != null && !started.isCompleted) started.complete();
    await registrationGate?.future;
    await super.registerDevice(
      installationId: installationId,
      platform: platform,
      fcmToken: fcmToken,
      locale: locale,
      appVersion: appVersion,
      deviceName: deviceName,
      metadata: metadata,
    );
    lifecycleOperations.add('register:$fcmToken');
  }

  @override
  Future<void> revokeDevice(String installationId) async {
    await super.revokeDevice(installationId);
    lifecycleOperations.add('revoke:$installationId');
  }
}

class _PushAuthRepository extends AuthRepository {
  _PushAuthRepository({
    required super.api,
    required super.tokenStore,
    this.logoutGate,
  });

  final Completer<void>? logoutGate;

  @override
  Future<void> logout() async {
    await logoutGate?.future;
  }
}
