import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/navigation/deep_link_listener.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const messagesChannel = MethodChannel('com.llfbandit.app_links/messages');
  const eventsChannelName = 'com.llfbandit.app_links/events';
  const codec = StandardMethodCodec();

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
