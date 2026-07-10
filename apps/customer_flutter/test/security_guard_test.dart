import 'dart:async';
import 'dart:convert' as convert;

import 'package:customer_flutter/app/customer_app.dart';
import 'package:customer_flutter/app/router.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/security/screen_security_service.dart';
import 'package:customer_flutter/core/security/web_privacy_mode.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/monitoring/presentation/public_visit_monitor.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/pin/presentation/pin_screen.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:customer_flutter/shared/widgets/sensitive_screen_guard.dart';
import 'package:customer_flutter/shared/widgets/web_privacy_browser_activity_state.dart';
import 'package:customer_flutter/shared/widgets/web_privacy_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ScreenSecurityService sends localized overlay copy to native',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('customer_flutter/screen_security'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('customer_flutter/screen_security'),
        null,
      );
    });

    final service = ScreenSecurityService();
    await service.enable(
      route: '/tickets',
      overlayTitle: 'Screen capture is not allowed',
      overlayDescription: 'Sensitive information is hidden.',
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'enable');
    expect(calls.single.arguments, {
      'route': '/tickets',
      'overlay_title': 'Screen capture is not allowed',
      'overlay_description': 'Sensitive information is hidden.',
    });
  });

  testWidgets('ScreenSecurityService sends native policy to platform channel',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('customer_flutter/screen_security'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('customer_flutter/screen_security'),
        null,
      );
    });

    final service = ScreenSecurityService();
    await service.enable(
      route: '/my-wallet',
      androidFlagSecure: false,
      androidProtectRecentAppPreview: true,
      iosScreenshotPolicy: 'overlay_only',
      iosScreenCaptureOverlay: false,
      iosExitApp: true,
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'enable');
    expect(calls.single.arguments, {
      'route': '/my-wallet',
      'flag_secure': false,
      'protect_recent_app_preview': true,
      'ios_screenshot_policy': 'overlay_only',
      'ios_screen_capture_overlay': false,
      'ios_exit_app': true,
    });
  });

  testWidgets('ScreenSecurityService normalizes native event aliases',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'type': 'screenCaptureStarted',
          'path': '/my-wallet',
          'cause': 'recording',
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(1));
    expect(events.single.event, 'screen_capture_active');
    expect(events.single.route, '/my-wallet');
    expect(events.single.reason, 'recording');

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'event': 'screenCaptured',
          'url': 'https://shop.example.test/tickets?tab=current',
          'message': 'native_capture',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'event': 'recordingStopped',
          'location': 'https://shop.example.test/#/tickets?tab=current',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'name': 'screenshotTaken',
          'route': '/reward-claims',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'name': 'securityExitRequested',
          'screen': '/checkout',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'eventName': 'screenRecordingStarted',
          'routeName': '/activity-claims',
          'reasonName': 'ios_recorder',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'event_type': 'screenSecurityExit',
          'pageName': '/reward-claims/claim_1',
          'detail': 'native_policy',
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events.map((event) => event.event), [
      'screen_capture_active',
      'screen_capture_active',
      'screen_capture_ended',
      'screenshot_detected',
      'screen_security_exit_requested',
      'screen_capture_active',
      'screen_security_exit_requested',
    ]);
    expect(events[1].route, '/tickets');
    expect(events[1].reason, 'native_capture');
    expect(events[2].route, '/tickets');
    expect(events[3].route, '/reward-claims');
    expect(events[4].route, '/checkout');
    expect(events[5].route, '/activity-claims');
    expect(events[5].reason, 'ios_recorder');
    expect(events[6].route, '/reward-claims/claim_1');
    expect(events[6].reason, 'native_policy');
  });

  testWidgets(
      'ScreenSecurityService normalizes nested native event payloads and URL route queries',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'route': '/public-route',
          'payload': {
            'eventName': 'screenCaptureDetected',
            'url':
                'customer://screen-security?route=%2Fmy-wallet%3Ftab%3Dsummary',
            'reasonCode': 'nested_capture',
          },
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'screen_security_event': {
            'event_type': 'securityExitRequested',
            'location':
                'https://shop.example.test/security?screen=%2Fcheckout%2Fpending%3Forder_id%3Dord_1',
            'policyName': 'ios_exit_app',
          },
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'path': '/public-route',
          'eventPayload': {
            'event': 'screenCaptureStarted',
            'route': {
              'currentUrl':
                  'https://shop.example.test/activity-claims/claim_2?tab=summary',
            },
            'details': 'route_object',
          },
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('securityEvent', {
          'event': 'recordingStopped',
          'notification': {
            'userInfo': {
              'eventName': 'screenCaptured',
              'params': {
                'screenUrl': 'https://shop.example.test/tickets?tab=current',
              },
              'details': 'ios_user_info',
            },
          },
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'arguments': convert.jsonEncode({
            'eventAction': 'screenSecurityExit',
            'activeScreen':
                'https://shop.example.test/activity-claims/claim_5?tab=detail',
            'reasonText': 'android_arguments',
          }),
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(5));
    expect(events.first.event, 'screen_capture_active');
    expect(events.first.route, '/my-wallet');
    expect(events.first.reason, 'nested_capture');
    expect(events[1].event, 'screen_security_exit_requested');
    expect(events[1].route, '/checkout/pending');
    expect(events[1].reason, 'ios_exit_app');
    expect(events[2].event, 'screen_capture_active');
    expect(events[2].route, '/activity-claims/claim_2');
    expect(events[2].reason, 'route_object');
    expect(events[3].event, 'screen_capture_active');
    expect(events[3].route, '/tickets');
    expect(events[3].reason, 'ios_user_info');
    expect(events.last.event, 'screen_security_exit_requested');
    expect(events.last.route, '/activity-claims/claim_5');
    expect(events.last.reason, 'android_arguments');
  });

  testWidgets(
      'ScreenSecurityService normalizes JSON-string native event payloads and route aliases',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'route': '/public-route',
          'data': convert.jsonEncode({
            'eventAction': 'screenCaptureDetected',
            'routePath': convert.jsonEncode({
              'activeUrl': 'https://shop.example.test/my-wallet?tab=summary',
            }),
            'reasonText': 'json_string_payload',
          }),
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventBody': convert.jsonEncode({
            'nativeEvent': 'securityExitRequested',
            'urlString':
                'customer://screen-security?activeUrl=https%3A%2F%2Fshop.example.test%2Freward-claims%2Fclaim_9%3Ftab%3Dreceipt',
            'reason_text': 'exit_alias',
          }),
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventPayload': {
            'eventName': 'screenCaptureDetected',
            'targetUrl':
                'https://shop.example.test/purchase-history/ord_2?tab=receipt',
            'reasonText': 'target_url_alias',
          },
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'payload': {
            'event': 'screenCaptureStarted',
            'route': {
              'routerPath': '/tickets/ticket_7?tab=image',
            },
            'details': 'router_path_alias',
          },
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(4));
    expect(events.first.event, 'screen_capture_active');
    expect(events.first.route, '/my-wallet');
    expect(events.first.reason, 'json_string_payload');
    expect(events[1].event, 'screen_security_exit_requested');
    expect(events[1].route, '/reward-claims/claim_9');
    expect(events[1].reason, 'exit_alias');
    expect(events[2].event, 'screen_capture_active');
    expect(events[2].route, '/purchase-history/ord_2');
    expect(events[2].reason, 'target_url_alias');
    expect(events.last.event, 'screen_capture_active');
    expect(events.last.route, '/tickets/ticket_7');
    expect(events.last.reason, 'router_path_alias');
  });

  testWidgets(
      'ScreenSecurityService normalizes capture-state events and bridge route aliases',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventKey': 'screenCaptureChanged',
          'isCaptured': false,
          'fullPath': '/my-wallet?tab=summary',
          'trigger': 'native_state_changed',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventCode': 'screenCaptureChanged',
          'captureActive': true,
          'hash': '#/checkout/pending?order_id=ord_1',
          'source': 'android_capture_state',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'securityEventName': 'screenRecordingChanged',
          'screenRecordingActive': true,
          'query':
              'returnUrl=https%3A%2F%2Fshop.example.test%2Freward-claims%2Fclaim_12%3Ftab%3Dreceipt',
          'triggerName': 'browser_visibility',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'screenSecurityEventName': 'captureInactive',
          'redirectUrl':
              'customer://screen-security?route=/activity-claims/claim_7',
          'sourceName': 'ios_capture_state',
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(4));
    expect(events.first.event, 'screen_capture_ended');
    expect(events.first.route, '/my-wallet');
    expect(events.first.reason, 'native_state_changed');
    expect(events[1].event, 'screen_capture_active');
    expect(events[1].route, '/checkout/pending');
    expect(events[1].reason, 'android_capture_state');
    expect(events[2].event, 'screen_capture_active');
    expect(events[2].route, '/reward-claims/claim_12');
    expect(events[2].reason, 'browser_visibility');
    expect(events.last.event, 'screen_capture_ended');
    expect(events.last.route, '/activity-claims/claim_7');
    expect(events.last.reason, 'ios_capture_state');
  });

  testWidgets(
      'ScreenSecurityService merges grouped native route event and capture wrappers',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'event': 'screenCaptureDetected',
          'route': '/public-route',
          'routeInfo': {
            'navigationUrl': {
              'rawValue':
                  'customer://screen-security?viewUrl=https%3A%2F%2Fshop.example.test%2Fmy-wallet%3Ftab%3Dsummary',
            },
          },
          'screenInfo': {
            'state': {'label': 'screenCaptureChanged'},
          },
          'captureStateInfo': {
            'screenCaptureStatus': {'text': 'running'},
          },
          'recordingInfo': {
            'sourceName': {'text': 'grouped_capture_state'},
          },
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventBody': {
            'kind': {'text': 'mediaProjectionChanged'},
            'navigation': {
              'currentViewUrl':
                  'https://shop.example.test/activity-claims/claim_3?tab=receipt',
            },
            'projectionStateInfo': {
              'mediaProjectionStatus': {'rawValue': 'stopped'},
            },
            'captureInfo': {
              'message': {'label': 'grouped_projection_state'},
            },
          },
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(2));
    expect(events.first.event, 'screen_capture_active');
    expect(events.first.route, '/my-wallet');
    expect(events.first.reason, 'grouped_capture_state');
    expect(events.last.event, 'screen_capture_ended');
    expect(events.last.route, '/activity-claims/claim_3');
    expect(events.last.reason, 'grouped_projection_state');
  });

  testWidgets(
      'ScreenSecurityService normalizes iOS notification and Android projection aliases',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'name': 'UIScreenCapturedDidChangeNotification',
          'isCaptured': false,
          'route': '/my-wallet?tab=summary',
          'reason': 'ios_capture_notification',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventName': 'UIScreen.capturedDidChangeNotification',
          'screenCaptureState': 'capturing',
          'currentUrl':
              'https://shop.example.test/checkout/pending?order_id=ord_9',
          'reasonText': 'ios_capture_swift_notification',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'nativeEvent': 'UIApplicationUserDidTakeScreenshotNotification',
          'currentUrl': 'https://shop.example.test/tickets?tab=current',
          'reasonText': 'ios_screenshot_notification',
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventAction': 'mediaProjectionStopped',
          'path': '/reward-claims/claim_1?tab=receipt',
          'sourceName': 'android_media_projection',
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(4));
    expect(events.first.event, 'screen_capture_ended');
    expect(events.first.route, '/my-wallet');
    expect(events.first.reason, 'ios_capture_notification');
    expect(events[1].event, 'screen_capture_active');
    expect(events[1].route, '/checkout/pending');
    expect(events[1].reason, 'ios_capture_swift_notification');
    expect(events[2].event, 'screenshot_detected');
    expect(events[2].route, '/tickets');
    expect(events[2].reason, 'ios_screenshot_notification');
    expect(events.last.event, 'screen_capture_ended');
    expect(events.last.route, '/reward-claims/claim_1');
    expect(events.last.reason, 'android_media_projection');
  });

  testWidgets(
      'ScreenSecurityService unwraps object scalar native event payloads',
      (tester) async {
    final service = ScreenSecurityService();
    final events = <ScreenSecurityEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'event': {'value': 'screenCaptureChanged'},
          'screenCaptureActive': {'value': 'off'},
          'route': {
            'value':
                'customer://screen-security?route=%2Fmy-wallet%3Ftab%3Dsummary',
          },
          'reason': {'code': 'object_capture_state'},
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'payload': convert.jsonEncode({
            'eventAction': {'value': 'securityExitRequested'},
            'route': {
              'currentUrl': {
                'value':
                    'https://shop.example.test/checkout/pending?order_id=ord_4',
              },
            },
            'reasonText': {'value': 'object_json_wrapper'},
          }),
        }),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'customer_flutter/screen_security',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('securityEvent', {
          'eventPayload': {
            'nativeEvent': {'key': 'screenCaptured'},
            'targetRoute': {
              'path': {'value': '/tickets/ticket_8?tab=image'},
            },
            'details': {'value': 'object_route_map'},
          },
        }),
      ),
      (_) {},
    );
    await tester.pump();

    expect(events, hasLength(3));
    expect(events.first.event, 'screen_capture_ended');
    expect(events.first.route, '/my-wallet');
    expect(events.first.reason, 'object_capture_state');
    expect(events[1].event, 'screen_security_exit_requested');
    expect(events[1].route, '/checkout/pending');
    expect(events[1].reason, 'object_json_wrapper');
    expect(events.last.event, 'screen_capture_active');
    expect(events.last.route, '/tickets/ticket_8');
    expect(events.last.reason, 'object_route_map');
  });

  test('screen security route parser resolves fragment route aliases', () {
    expect(
      normalizeScreenSecurityRoute(
        'https://shop.example.test/#/callback?route=%2Fmy-wallet%3Ftab%3Dsummary',
      ),
      '/my-wallet',
    );
    expect(
      normalizeScreenSecurityRoute(
        'https://shop.example.test/#/native-security?screen=%2Fcheckout%2Fpending%3Forder_id%3Dord_1',
      ),
      '/checkout/pending',
    );
    expect(
      normalizeScreenSecurityRoute('#route=%2Freward-claims%2Fclaim_1'),
      '/reward-claims/claim_1',
    );
    expect(
      normalizeScreenSecurityRoute(
        'customer://screen-security?currentUrl=https%3A%2F%2Fshop.example.test%2Factivity-claims%2Fclaim_2%3Ftab%3Dsummary',
      ),
      '/activity-claims/claim_2',
    );
    expect(
      normalizeScreenSecurityRoute(
        '#href=https://shop.example.test/tickets?tab=current',
      ),
      '/tickets',
    );
    expect(
      normalizeScreenSecurityRoute(
        'customer://screen-security?screenUrl=https%3A%2F%2Fshop.example.test%2Fpurchase-history%2Ford_1%3Ftab%3Dreceipt',
      ),
      '/purchase-history/ord_1',
    );
    expect(
      normalizeScreenSecurityRoute('https://shop.example.test/#/tickets?tab=1'),
      '/tickets',
    );
    expect(
      normalizeScreenSecurityRoute(
        'https://shop.example.test/#!/my-wallet?tab=summary',
      ),
      '/my-wallet',
    );
    expect(
      normalizeScreenSecurityRoute(
        '#%2Fcheckout%2Fpending%3Forder_id%3Dord_2',
      ),
      '/checkout/pending',
    );
    expect(
      normalizeScreenSecurityRoute(
        'https%3A%2F%2Fshop.example.test%2Ftickets%3Ftab%3Dcurrent',
      ),
      '/tickets',
    );
    expect(
      normalizeScreenSecurityRoute(
        'customer://screen-security?targetUrl=https%3A%2F%2Fshop.example.test%2Freward-claims%2Fclaim_10%3Ftab%3Dreceipt',
      ),
      '/reward-claims/claim_10',
    );
    expect(
      normalizeScreenSecurityRoute(
        'customer://screen-security?routeUrl=https%3A%2F%2Fshop.example.test%2Factivity-claims%2Fclaim_11',
      ),
      '/activity-claims/claim_11',
    );
    expect(
      normalizeScreenSecurityRoute(
        'returnUrl=https%3A%2F%2Fshop.example.test%2Fmy-wallet%3Ftab%3Dsummary',
      ),
      '/my-wallet',
    );
    expect(
      normalizeScreenSecurityRoute(
        'customer://screen-security?redirectUrl=https%3A%2F%2Fshop.example.test%2Fcheckout%2Fpending%3Forder_id%3Dord_3',
      ),
      '/checkout/pending',
    );
    expect(
      normalizeScreenSecurityRoute(
        'hash=%23%2Freward-claims%2Fclaim_13%3Ftab%3Dreceipt',
      ),
      '/reward-claims/claim_13',
    );
    expect(
      normalizeScreenSecurityRoute(
        '#state=hidden&route=%2Fmy-wallet%3Ftab%3Dsummary',
      ),
      '/my-wallet',
    );
    expect(
      normalizeScreenSecurityRoute(
        'state=locked&targetUrl=https%3A%2F%2Fshop.example.test%2Freward-claims%2Fclaim_14%3Ftab%3Dreceipt',
      ),
      '/reward-claims/claim_14',
    );
    expect(
      normalizeScreenSecurityRoute(
        'https://shop.example.test/#state=hidden&screenUrl=https%3A%2F%2Fshop.example.test%2Fpurchase-history%2Ford_4%3Ftab%3Dreceipt',
      ),
      '/purchase-history/ord_4',
    );
  });

  testWidgets('SensitiveScreenGuard matches native full URL route events',
      (tester) async {
    final authController = _testAuthController()..pinRequired = false;
    final screenSecurity = _FakeScreenSecurityService();
    final audit = _FakeScreenSecurityAuditService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => authController),
          screenSecurityServiceProvider.overrideWithValue(screenSecurity),
          screenSecurityAuditServiceProvider.overrideWithValue(audit),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SensitiveScreenGuard(
            route: '/tickets',
            child: Text('Ticket detail'),
          ),
        ),
      ),
    );
    await tester.pump();

    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screen_capture_active',
        route: 'https://shop.example.test/tickets?tab=current',
        reason: 'ios_recording',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isTrue);
    expect(authController.isSecurityLocked, isTrue);
    expect(audit.recordedRoutes, ['/tickets']);

    authController
      ..pinRequired = false
      ..isSecurityLocked = false;
    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screenshot_detected',
        route: 'https://shop.example.test/my-wallet',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isFalse);
    expect(audit.recordedRoutes, ['/tickets']);
  });

  testWidgets(
      'SensitiveScreenGuard matches parent and pattern native route events',
      (tester) async {
    final authController = _testAuthController()..pinRequired = false;
    final screenSecurity = _FakeScreenSecurityService();
    final audit = _FakeScreenSecurityAuditService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => authController),
          screenSecurityServiceProvider.overrideWithValue(screenSecurity),
          screenSecurityAuditServiceProvider.overrideWithValue(audit),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SensitiveScreenGuard(
            route: '/reward-claims/claim_1',
            child: Text('Reward claim detail'),
          ),
        ),
      ),
    );
    await tester.pump();

    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screenshot_detected',
        route: '/reward-claims/',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isTrue);
    expect(audit.recordedRoutes, ['/reward-claims']);

    authController
      ..pinRequired = false
      ..isSecurityLocked = false;
    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screen_capture_active',
        route: '/reward-claims/:claimId',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isTrue);
    expect(audit.recordedRoutes, [
      '/reward-claims',
      '/reward-claims/:claimId',
    ]);

    authController
      ..pinRequired = false
      ..isSecurityLocked = false;
    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screen_capture_active',
        route: '/activity-claims',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isFalse);
    expect(audit.recordedRoutes, [
      '/reward-claims',
      '/reward-claims/:claimId',
    ]);
  });

  testWidgets(
      'CustomerApp enables native screen security only on sensitive routes',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('Root route'),
        ),
        GoRoute(
          path: '/my-wallet',
          builder: (context, state) => const Text('Wallet route'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('android'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'android': {'flag_secure': true},
                    'privacyOverlayTitle': 'Runtime privacy title',
                    'privacyOverlayDescription': 'Runtime privacy description',
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(router),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(SensitiveScreenGuard), findsOneWidget);
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .enabled,
      isFalse,
    );
    expect(find.text('Root route'), findsOneWidget);

    router.go('/my-wallet');
    await tester.pumpAndSettle();

    expect(find.text('Wallet route'), findsOneWidget);
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .androidFlagSecure,
      isTrue,
    );
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .privacyOverlayTitle,
      'Runtime privacy title',
    );
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .privacyOverlayDescription,
      'Runtime privacy description',
    );
  });

  testWidgets('SensitiveScreenGuard locks session on native capture events',
      (tester) async {
    final authController = _testAuthController()..pinRequired = false;
    final screenSecurity = _FakeScreenSecurityService();
    final audit = _FakeScreenSecurityAuditService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => authController),
          screenSecurityServiceProvider.overrideWithValue(screenSecurity),
          screenSecurityAuditServiceProvider.overrideWithValue(audit),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SensitiveScreenGuard(
            route: '/tickets',
            child: Text('Ticket detail'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(screenSecurity.enabledRoute, '/tickets');
    expect(authController.pinRequired, isFalse);

    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screenshot_detected',
        route: '/tickets',
        reason: 'screenshot',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isTrue);
    expect(authController.isSecurityLocked, isTrue);
    expect(audit.recordedRoutes, ['/tickets']);
    expect(audit.recordedEvents.single.event, 'screenshot_detected');
  });

  testWidgets('SensitiveScreenGuard can report overlay-only capture events',
      (tester) async {
    final authController = _testAuthController()..pinRequired = false;
    final screenSecurity = _FakeScreenSecurityService();
    final audit = _FakeScreenSecurityAuditService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => authController),
          screenSecurityServiceProvider.overrideWithValue(screenSecurity),
          screenSecurityAuditServiceProvider.overrideWithValue(audit),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SensitiveScreenGuard(
            route: '/my-wallet',
            lockOnCapture: false,
            child: Text('Wallet detail'),
          ),
        ),
      ),
    );
    await tester.pump();

    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screenshot_detected',
        route: '/my-wallet',
        reason: 'screenshot',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isFalse);
    expect(authController.isSecurityLocked, isFalse);
    expect(audit.recordedRoutes, ['/my-wallet']);
    expect(audit.recordedEvents.single.event, 'screenshot_detected');

    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screen_security_exit_requested',
        route: '/my-wallet',
        reason: 'screenshot',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isTrue);
    expect(authController.isSecurityLocked, isTrue);
    expect(audit.recordedRoutes, ['/my-wallet', '/my-wallet']);
    expect(audit.recordedEvents.last.event, 'screen_security_exit_requested');
  });

  testWidgets(
      'CustomerApp disables native screen security and leaves public web routes uncovered',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'android': {'flag_secure': true},
                    'ios': {'screen_capture_overlay': true},
                  },
                  'feature_flags': {'screen_security_native': true},
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Text('Root route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final guard = tester.widget<SensitiveScreenGuard>(
      find.byType(SensitiveScreenGuard),
    );
    expect(guard.enabled, isFalse);
    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isFalse);
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('CustomerApp lifecycle lock only applies on sensitive routes', (
    tester,
  ) async {
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    final authController = _testAuthController()
      ..isAuthenticated = true
      ..pinRequired = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('Root route'),
        ),
        GoRoute(
          path: '/my-wallet',
          builder: (context, state) => const Text('Wallet route'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authControllerProvider.overrideWith((_) => authController),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('android'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'android': {'flag_secure': true},
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(router),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();
    expect(find.text('Root route'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(authController.pinRequired, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    router.go('/my-wallet');
    await tester.pumpAndSettle();
    authController.pinRequired = false;
    expect(find.text('Wallet route'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(authController.pinRequired, isTrue);
  });

  testWidgets('CustomerApp enables web privacy guard without watermark',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'web': {'watermark_enabled': true},
                    'privacyOverlayTitle': 'Runtime web privacy',
                    'privacyOverlayDescription':
                        'Runtime web sensitive content is hidden.',
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              initialLocation: '/my-wallet',
              routes: [
                GoRoute(
                  path: '/my-wallet',
                  builder: (context, state) => const Text('Wallet route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final guard = tester.widget<SensitiveScreenGuard>(
      find.byType(SensitiveScreenGuard),
    );
    expect(guard.enabled, isFalse);
    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isTrue);
    expect(webGuard.mode, 'limited');
    expect(webGuard.watermarkEnabled, isFalse);
    expect(webGuard.privacyOverlayTitle, 'Runtime web privacy');
    expect(
      webGuard.privacyOverlayDescription,
      'Runtime web sensitive content is hidden.',
    );
    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets('CustomerApp honors iOS overlay-only capture policy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('ios'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'ios': {
                      'screenshot_policy': 'overlay_only',
                      'screen_capture_overlay': true,
                      'exit_app': false,
                    },
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              initialLocation: '/my-wallet',
              routes: [
                GoRoute(
                  path: '/my-wallet',
                  builder: (context, state) => const Text('Wallet route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final guard = tester.widget<SensitiveScreenGuard>(
      find.byType(SensitiveScreenGuard),
    );
    expect(guard.enabled, isTrue);
    expect(guard.iosScreenshotPolicy, 'overlay_only');
    expect(guard.iosScreenCaptureOverlay, isTrue);
    expect(guard.lockOnCapture, isFalse);
    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets('CustomerApp honors limited web privacy mode without watermark',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'web': {
                      'sensitive_screen_mode': 'limited',
                      'watermark_enabled': false,
                    },
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              initialLocation: '/my-wallet',
              routes: [
                GoRoute(
                  path: '/my-wallet',
                  builder: (context, state) => const Text('Wallet route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isTrue);
    expect(webGuard.mode, 'limited');
    expect(webGuard.watermarkEnabled, isFalse);
    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets(
      'WebPrivacyGuard covers content while browser lifecycle is hidden',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en', 'US'),
        supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
        localizationsDelegates: [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: WebPrivacyGuard(
          enabled: true,
          watermarkEnabled: false,
          privacyOverlayTitle: 'Partner privacy mode',
          privacyOverlayDescription: 'Partner sensitive content is hidden.',
          child: Text('Sensitive wallet'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sensitive wallet'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(find.text('Sensitive wallet'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    expect(find.text('Partner privacy mode'), findsOneWidget);
    expect(find.text('Partner sensitive content is hidden.'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
  });

  testWidgets('WebPrivacyGuard watermark-only mode renders no watermark cover',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en', 'US'),
        supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
        localizationsDelegates: [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: WebPrivacyGuard(
          enabled: true,
          mode: 'watermark-only',
          watermarkEnabled: false,
          privacyOverlayTitle: 'Partner watermark',
          privacyOverlayDescription: 'Lifecycle cover is disabled.',
          child: Text('Sensitive wallet'),
        ),
      ),
    );
    await tester.pump();

    expect(_privacyWatermarkFinder, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(find.text('Sensitive wallet'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    expect(find.text('Partner watermark'), findsNothing);
    expect(_privacyWatermarkFinder, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  test('web privacy browser activity covers pagehide, freeze, and print', () {
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        windowFocused: true,
      ),
      isFalse,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        windowFocused: true,
        pageHidden: true,
      ),
      isTrue,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        windowFocused: true,
        pageFrozen: true,
      ),
      isTrue,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        windowFocused: true,
        printActive: true,
      ),
      isTrue,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        windowFocused: false,
      ),
      isTrue,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        documentVisibilityState: 'prerender',
        windowFocused: true,
      ),
      isTrue,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        documentVisibilityState: 'hidden',
        windowFocused: true,
      ),
      isTrue,
    );
    expect(
      webPrivacyBrowserShouldCover(
        documentHidden: false,
        documentVisibilityState: '',
        windowFocused: true,
      ),
      isFalse,
    );
  });

  testWidgets('CustomerApp honors runtime sensitive route patterns',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/tenant-claims/claim_123',
      routes: [
        GoRoute(
          path: '/tenant-claims/:claimId',
          builder: (context, state) => const Text('Tenant claim route'),
        ),
        GoRoute(
          path: '/vip-secure',
          builder: (context, state) => const Text('VIP root route'),
        ),
        GoRoute(
          path: '/vip-secure/:section/:id',
          builder: (context, state) => const Text('VIP nested route'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('android'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'android': {'flag_secure': true},
                    'sensitive_routes': [
                      'https://partner.example.com/tenant-claims/:claimId?source=bo',
                      'customer://screen-security?route=%2Fvip-secure%2F*%3Fsource%3Dbo',
                    ],
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(router),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Tenant claim route'), findsOneWidget);
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .enabled,
      isTrue,
    );

    router.go('/vip-secure/report/2026');
    await tester.pumpAndSettle();

    expect(find.text('VIP nested route'), findsOneWidget);
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .enabled,
      isTrue,
    );

    router.go('/vip-secure');
    await tester.pumpAndSettle();

    expect(find.text('VIP root route'), findsOneWidget);
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .enabled,
      isFalse,
    );
  });

  test('web privacy cover decision preserves raw state across mode switches',
      () {
    expect(
      webPrivacyModeShouldShowCover(
        'limited',
        lifecycleShouldCover: true,
        browserShouldCover: false,
      ),
      isTrue,
    );
    expect(
      webPrivacyModeShouldShowCover(
        'watermark-only',
        lifecycleShouldCover: true,
        browserShouldCover: false,
      ),
      isFalse,
    );
    expect(
      webPrivacyModeShouldShowCover(
        'strict',
        lifecycleShouldCover: false,
        browserShouldCover: true,
      ),
      isTrue,
    );
  });

  testWidgets('CustomerApp can disable web privacy guard by tenant policy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'web': {
                      'sensitive_screen_mode': 'off',
                      'watermark_enabled': false,
                    },
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Text('Root route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isFalse);
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('CustomerApp honors bootstrap screen security feature flag',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'feature_flags': {'screen_security_native': false},
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Text('Root route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final guard = tester.widget<SensitiveScreenGuard>(
      find.byType(SensitiveScreenGuard),
    );
    expect(guard.enabled, isFalse);
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('PinScreen hides biometric unlock when tenant policy disables it',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => _testAuthController()),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'mobile': {
                  'feature_flags': {'native_biometric_unlock': false},
                },
              },
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Use Face ID / Biometric'), findsNothing);
    expect(find.text('Forgot PIN?'), findsOneWidget);
  });

  testWidgets('PinScreen hides native biometric unlock on web platform',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => _testAuthController()),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'mobile': {
                  'biometric': {
                    'enabled': true,
                    'platforms': {
                      'ios': ['face_id'],
                      'android': ['biometric_prompt'],
                    },
                  },
                  'feature_flags': {'native_biometric_unlock': true},
                },
              },
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Use Face ID / Biometric'), findsNothing);
    expect(find.text('Forgot PIN?'), findsOneWidget);
  });

  testWidgets('PinScreen switches to setup mode when customer has no PIN',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (_) => _testAuthController(pinSetupRequired: true),
          ),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'mobile': {
                  'biometric': {
                    'enabled': true,
                    'platforms': {
                      'ios': ['face_id'],
                      'android': ['biometric_prompt'],
                    },
                  },
                  'feature_flags': {'native_biometric_unlock': true},
                },
              },
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set 6-digit PIN'), findsOneWidget);
    expect(find.text('Use Face ID / Biometric'), findsNothing);
    expect(find.text('Forgot PIN?'), findsNothing);
  });

  testWidgets('AppShell leaves capture protection to the root guard',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {}),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(
            title: 'Secure',
            currentPath: '/tickets',
            sensitive: true,
            child: Text('Secure content'),
          ),
        ),
      ),
    );

    expect(find.byType(SensitiveScreenGuard), findsNothing);
    expect(find.text('Secure content'), findsOneWidget);
  });

  testWidgets('public AppShell pages are still renderable under root policy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {}),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(
            title: 'Public',
            currentPath: '/news',
            child: Text('Public content'),
          ),
        ),
      ),
    );

    expect(find.byType(SensitiveScreenGuard), findsNothing);
    expect(find.text('Public content'), findsOneWidget);
  });
}

class _NoopNewsRepository extends NewsRepository {
  _NoopNewsRepository()
      : super(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
            AuthTokenStore(),
            localeTag: 'th-TH',
          ),
          (value) => value,
        );

  @override
  Future<NewsItem?> modal() async => null;

  @override
  Future<List<NewsItem>> list({int limit = NewsRepository.defaultPageLimit}) {
    return Future.value(const []);
  }

  @override
  Future<List<NewsItem>> listAll({
    int limit = NewsRepository.defaultPageLimit,
    int maxPages = NewsRepository.maxAutoPages,
  }) {
    return Future.value(const []);
  }
}

class _NoopResultRepository extends ResultRepository {
  _NoopResultRepository()
      : super(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
            AuthTokenStore(),
            localeTag: 'th-TH',
          ),
        );

  @override
  Future<CurrentGame?> currentGame() async => null;

  @override
  Future<RewardResultGame?> latest({String? gameId, bool live = true}) async {
    return null;
  }

  @override
  Future<RewardResultBundle> current({String? gameId}) async {
    return const RewardResultBundle(
      currentGame: null,
      selectedResult: null,
      history: [],
    );
  }
}

final _privacyWatermarkFinder = find.byWidgetPredicate((widget) {
  if (widget is! CustomPaint) return false;
  return widget.painter.runtimeType.toString().contains('PrivacyWatermark');
});

AuthController _testAuthController({bool pinSetupRequired = false}) {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'en-US',
    ),
    tokenStore,
    localeTag: 'en-US',
  );

  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..pinRequired = true
    ..pinSetupRequired = pinSetupRequired;
}

class _FakeScreenSecurityService extends ScreenSecurityService {
  final StreamController<ScreenSecurityEvent> _controller =
      StreamController<ScreenSecurityEvent>.broadcast();
  String enabledRoute = '';
  String? overlayTitle;
  String? overlayDescription;
  bool disabled = false;

  @override
  Stream<ScreenSecurityEvent> get events => _controller.stream;

  @override
  Future<void> enable({
    required String route,
    String? overlayTitle,
    String? overlayDescription,
    bool? androidFlagSecure,
    bool? androidProtectRecentAppPreview,
    String? iosScreenshotPolicy,
    bool? iosScreenCaptureOverlay,
    bool? iosExitApp,
  }) async {
    enabledRoute = route;
    this.overlayTitle = overlayTitle;
    this.overlayDescription = overlayDescription;
    disabled = false;
  }

  @override
  Future<void> disable() async {
    disabled = true;
  }

  void emit(ScreenSecurityEvent event) => _controller.add(event);
}

class _FakeScreenSecurityAuditService extends ScreenSecurityAuditService {
  final recordedEvents = <ScreenSecurityEvent>[];
  final recordedRoutes = <String>[];

  @override
  Future<void> record({
    required ScreenSecurityEvent event,
    required String route,
  }) async {
    recordedEvents.add(event);
    recordedRoutes.add(route);
  }
}
