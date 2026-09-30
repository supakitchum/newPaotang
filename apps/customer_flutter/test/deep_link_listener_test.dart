import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/navigation/deep_link_listener.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const messagesChannel = MethodChannel('com.llfbandit.app_links/messages');
  const eventsChannelName = 'com.llfbandit.app_links/events';
  const codec = StandardMethodCodec();

  for (final link in [
    'https://siamblend.com/register?ref=ABC123',
    'https://siamblend.com/?ref=ABC123',
    'siamblend://register?ref=ABC123',
  ]) {
    testWidgets('native referral survives auth redirect: $link', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(messagesChannel, (call) async {
        return call.method == 'getInitialLink' ? link : null;
      });
      messenger.setMockMessageHandler(
        eventsChannelName,
        (_) async => codec.encodeSuccessEnvelope(null),
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(messagesChannel, null);
        messenger.setMockMessageHandler(eventsChannelName, null);
      });

      final repository = _ReferralRepository();
      final store = AffiliateReferralStore();
      final router = GoRouter(
        redirect: (context, state) =>
            state.uri.queryParameters['ref'] != null ? '/login' : null,
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('Home')),
          GoRoute(
            path: '/register',
            builder: (_, __) => const Text('Register'),
          ),
          GoRoute(path: '/login', builder: (_, __) => const Text('Login')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://siamblend.com/api/v1',
                defaultLocale: 'th-TH',
                tenantHost: 'siamblend.com',
              ),
            ),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(const {}),
            ),
            affiliateReferralRepositoryProvider.overrideWithValue(repository),
            affiliateReferralStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                CustomerDeepLinkListener(router: router, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      expect(await store.read('siamblend.com'), 'ABC123');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerDeepLinkListener)),
      );
      await container
          .read(affiliateReferralServiceProvider)
          .applyStored(registered: true);
      expect(repository.appliedCode, 'ABC123');
      expect(repository.registered, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'verified Google callback navigates when listener is in MaterialApp builder',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(messagesChannel, (call) async {
        if (call.method == 'getInitialLink') {
          return 'https://siamblend.com/social/google/callback'
              '?code=test-code&state=test-state';
        }
        return null;
      });
      messenger.setMockMessageHandler(eventsChannelName, (message) async {
        final call = codec.decodeMethodCall(message);
        if (call.method == 'listen' || call.method == 'cancel') {
          return codec.encodeSuccessEnvelope(null);
        }
        return codec.encodeErrorEnvelope(
          code: 'unsupported',
          message: 'Unsupported event-channel method: ${call.method}',
        );
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(messagesChannel, null);
        messenger.setMockMessageHandler(eventsChannelName, null);
      });

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('Home')),
          GoRoute(
            path: '/social/:provider/callback',
            builder: (context, state) => Text(
              '${state.pathParameters['provider']} callback:'
              '${state.uri.queryParameters['code']}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://siamblend.com/api/v1',
                defaultLocale: 'th-TH',
                tenantHost: 'siamblend.com',
              ),
            ),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(const {}),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => CustomerDeepLinkListener(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('google callback:test-code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ReferralRepository extends AffiliateReferralRepository {
  _ReferralRepository()
    : super(
        ApiClient(
          const AppConfig(
            apiBaseUrl: 'https://siamblend.com/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        ),
      );

  String appliedCode = '';
  bool registered = false;

  @override
  Future<void> trackClick({
    required String refCode,
    required String visitorId,
    required String landingUrl,
  }) async {}

  @override
  Future<void> apply({
    required String refCode,
    required String visitorId,
    bool registered = false,
  }) async {
    appliedCode = refCode;
    this.registered = registered;
  }
}
