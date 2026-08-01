import 'dart:async';

import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/navigation/customer_deep_link.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/auth/presentation/line_auth_screens.dart';
import 'package:customer_flutter/features/auth/presentation/login_screen.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'login renders every enabled store-compliant social provider from runtime config',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson({
                'mobile': {
                  'auth_providers': [
                    {'provider': 'line_oauth', 'enabled': true},
                    {'provider': 'google_oauth2', 'enabled': true},
                    {'provider': 'apple_login', 'enabled': true},
                    {'provider': 'facebook_oauth', 'enabled': true},
                    {'provider': 'discord', 'enabled': true},
                    {'provider': 'gmail', 'enabled': false},
                  ],
                },
              }),
            ),
          ],
          child: const _LoginTestApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Continue with LINE'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple ID'), findsOneWidget);
      expect(find.text('Continue with Facebook'), findsOneWidget);
      expect(find.text('Continue with discord'), findsNothing);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    },
  );

  testWidgets(
    'login social launch shows provider loading without changing password submit copy',
    (tester) async {
      final socialLoginUrl = Completer<String>();
      final repository = _SocialAuthRepository(
        callbackResult: _emptyCallback('line'),
        socialLoginUrlFuture: socialLoginUrl.future,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            customerLinkLauncherProvider.overrideWithValue(
              const _SuccessfulLinkLauncher(),
            ),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson({
                'mobile': {
                  'auth_providers': [
                    {'provider': 'line', 'label': 'LINE', 'enabled': true},
                    {'provider': 'google', 'label': 'Google', 'enabled': true},
                  ],
                },
              }),
            ),
          ],
          child: const _LoginTestApp(),
        ),
      );

      await tester.pumpAndSettle();
      final lineButton = find.widgetWithText(
        OutlinedButton,
        'Continue with LINE',
      );
      await tester.ensureVisible(lineButton);
      await tester.pumpAndSettle();

      await tester.tap(lineButton);
      await tester.pump();

      expect(find.text('Connecting to LINE'), findsOneWidget);
      expect(find.text('Signing in'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(repository.lastSocialLoginProvider, 'line');

      socialLoginUrl.complete('https://social.example.com/oauth');
      await tester.pumpAndSettle();

      expect(find.text('Continue with LINE'), findsOneWidget);
    },
  );

  testWidgets('login social launch shows API payload errors like Nuxt', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('line'),
      socialLoginUrlError: _apiException(
        'ร้านค้ายังไม่ได้ตั้งค่า LINE Login',
        path: '/customer/auth/social/line/login',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'label': 'LINE', 'enabled': true},
                ],
              },
            }),
          ),
        ],
        child: const _LoginTestApp(),
      ),
    );

    await tester.pumpAndSettle();
    final lineButton = find.widgetWithText(
      OutlinedButton,
      'Continue with LINE',
    );
    await tester.ensureVisible(lineButton);
    await tester.pumpAndSettle();
    await tester.tap(lineButton);
    await tester.pumpAndSettle();

    expect(find.text('ร้านค้ายังไม่ได้ตั้งค่า LINE Login'), findsOneWidget);
    expect(find.text('Could not sign in with this provider'), findsNothing);
  });

  testWidgets('login social launch hides internal errors', (tester) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('line'),
      socialLoginUrlError: StateError('internal social launch failed'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'label': 'LINE', 'enabled': true},
                ],
              },
            }),
          ),
        ],
        child: const _LoginTestApp(),
      ),
    );

    await tester.pumpAndSettle();
    final lineButton = find.widgetWithText(
      OutlinedButton,
      'Continue with LINE',
    );
    await tester.ensureVisible(lineButton);
    await tester.pumpAndSettle();
    await tester.tap(lineButton);
    await tester.pumpAndSettle();

    expect(find.text('Could not sign in with this provider'), findsOneWidget);
    expect(find.textContaining('internal social launch failed'), findsNothing);
  });

  testWidgets(
    'generic social callback routes unlinked Google users to phone link',
    (tester) async {
      final repository = _SocialAuthRepository(
        callbackResult: const SocialCallbackResult(
          provider: 'google',
          code: 0,
          lineLinkRequired: true,
          linkToken: 'google-link-token',
          displayName: 'Ada Google',
          pictureUrl: '',
          passwordResetReady: false,
          passwordResetToken: '',
          orderId: '',
          message: '',
          redirectPath: '/reward-claims',
        ),
      );

      final router = _router(
        initialLocation: '/social/google/callback?code=abc&state=oauth_state',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            affiliateReferralServiceProvider.overrideWithValue(
              _NoopAffiliateReferralService(),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );

      await _pumpCallbackWork(tester);

      expect(repository.lastCallbackProvider, 'google');
      expect(repository.lastCallbackQuery?['code'], 'abc');
      expect(repository.lastCallbackQuery?['state'], 'oauth_state');
      expect(
        find.text('link:google:google-link-token:Ada Google'),
        findsOneWidget,
      );
      expect(
        router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['redirect'],
        '/reward-claims',
      );
    },
  );

  testWidgets(
    'generic social callback applies Apple session and enters PIN flow',
    (tester) async {
      final repository = _SocialAuthRepository(
        callbackResult: const SocialCallbackResult(
          provider: 'apple',
          code: 0,
          lineLinkRequired: false,
          linkToken: '',
          displayName: '',
          pictureUrl: '',
          passwordResetReady: false,
          passwordResetToken: '',
          orderId: '',
          message: '',
          redirectPath: '/checkout',
          session: CustomerSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            pinRequired: true,
            pinSetupRequired: false,
            customerId: 'cus_apple',
          ),
        ),
      );
      final affiliate = _NoopAffiliateReferralService();

      final router = _router(
        initialLocation: '/social/apple/callback?code=abc&state=oauth_state',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            affiliateReferralServiceProvider.overrideWithValue(affiliate),
          ],
          child: _TestApp(router: router),
        ),
      );

      await _pumpCallbackWork(tester);

      expect(repository.lastCallbackProvider, 'apple');
      expect(affiliate.applied, isTrue);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/pin');
      expect(
        router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['redirect'],
        '/checkout',
      );
      expect(find.text('pin-flow'), findsOneWidget);
    },
  );

  testWidgets('generic social callback resumes pending payment order', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: const SocialCallbackResult(
        provider: 'line',
        code: 0,
        lineLinkRequired: false,
        linkToken: '',
        displayName: '',
        pictureUrl: '',
        passwordResetReady: false,
        passwordResetToken: '',
        orderId: 'ord_social_1',
        message: '',
        session: CustomerSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          pinRequired: false,
          pinSetupRequired: false,
          customerId: 'cus_line',
        ),
      ),
    );
    final affiliate = _NoopAffiliateReferralService();

    final router = _router(
      initialLocation: '/social/line/callback?code=abc&state=oauth_state',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(affiliate),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(repository.lastCallbackProvider, 'line');
    expect(affiliate.applied, isTrue);
    expect(uri.path, '/checkout/pending');
    expect(uri.queryParameters['order_id'], 'ord_social_1');
    expect(find.text('pending:ord_social_1'), findsOneWidget);
  });

  testWidgets(
    'generic social callback requires OAuth state and uses runtime provider copy',
    (tester) async {
      final repository = _SocialAuthRepository(
        callbackResult: _emptyCallback('google'),
      );

      final router = _router(
        initialLocation:
            '/social/google/callback?code=abc&redirect=%2Fcheckout',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson({
                'mobile': {
                  'auth_providers': [
                    {
                      'provider': 'google',
                      'label': 'Google Workspace',
                      'enabled': true,
                      'buttonBackgroundColor': '#4285F4',
                    },
                  ],
                },
              }),
            ),
            affiliateReferralServiceProvider.overrideWithValue(
              _NoopAffiliateReferralService(),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );

      await _pumpCallbackWork(tester);

      expect(repository.lastCallbackProvider, isNull);
      expect(
        find.text(
          'No verification data from Google Workspace. Please try connecting again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Google Workspace Login'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Back to sign in'),
        findsNothing,
      );
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/social/google/callback',
      );
    },
  );

  testWidgets(
    'generic social callback never falls back to LINE for another provider',
    (tester) async {
      final repository = _SocialAuthRepository(
        callbackResult: _emptyCallback('discord'),
      );
      final router = _router(initialLocation: '/social/discord/callback');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(const {
                'mobile': {'auth_providers': []},
              }),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'No verification data from discord. Please try connecting again.',
        ),
        findsOneWidget,
      );
      expect(find.text('discord Login'), findsOneWidget);
      expect(find.textContaining('LINE'), findsNothing);
    },
  );

  testWidgets('generic social callback normalizes code and state aliases', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
    );

    final router = _router(
      initialLocation:
          '/social/google/callback?authorizationCode=abc&callbackState=oauth_state',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(repository.lastCallbackProvider, 'google');
    expect(repository.lastCallbackQuery?['code'], 'abc');
    expect(repository.lastCallbackQuery?['state'], 'oauth_state');
    expect(repository.lastCallbackQuery?['authorizationCode'], 'abc');
    expect(repository.lastCallbackQuery?['callbackState'], 'oauth_state');
  });

  testWidgets('generic social callback accepts OAuth values from URL fragment', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
    );

    final router = _router(
      initialLocation:
          '/social/google/callback#authorizationCode=fragment-code&callbackState=fragment-state',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(repository.lastCallbackProvider, 'google');
    expect(repository.lastCallbackQuery?['code'], 'fragment-code');
    expect(repository.lastCallbackQuery?['state'], 'fragment-state');
    expect(repository.lastCallbackQuery?['authorizationCode'], 'fragment-code');
    expect(repository.lastCallbackQuery?['callbackState'], 'fragment-state');
  });

  testWidgets('generic social callback accepts JSON-string wrapper aliases', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
    );
    final payload = Uri.encodeComponent(
      '{"authorizationCode":"wrapped-code","callbackState":"wrapped-state"}',
    );

    final router = _router(
      initialLocation: '/social/google/callback?payload=$payload',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(repository.lastCallbackProvider, 'google');
    expect(repository.lastCallbackQuery?['code'], 'wrapped-code');
    expect(repository.lastCallbackQuery?['state'], 'wrapped-state');
    expect(repository.lastCallbackQuery?['payload'], contains('wrapped-code'));
  });

  testWidgets(
    'generic social callback preserves wrapped redirect for phone linking',
    (tester) async {
      final repository = _SocialAuthRepository(
        callbackResult: const SocialCallbackResult(
          provider: 'google',
          code: 0,
          lineLinkRequired: true,
          linkToken: 'wrapped-link-token',
          displayName: 'Wrapped User',
          pictureUrl: '',
          passwordResetReady: false,
          passwordResetToken: '',
          orderId: '',
          message: '',
        ),
      );
      final payload = Uri.encodeComponent(
        '{"authorizationCode":"wrapped-code",'
        '"callbackState":"wrapped-state",'
        '"redirect":"/affiliate"}',
      );

      final router = _router(
        initialLocation: '/social/google/callback?payload=$payload',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            affiliateReferralServiceProvider.overrideWithValue(
              _NoopAffiliateReferralService(),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );

      await _pumpCallbackWork(tester);

      final uri = router.routerDelegate.currentConfiguration.uri;
      expect(uri.path, '/social/google/link-phone');
      expect(uri.queryParameters['redirect'], '/affiliate');
      expect(uri.queryParameters['token'], 'wrapped-link-token');
    },
  );

  testWidgets(
    'generic social callback preserves wrapped redirect after login',
    (tester) async {
      final repository = _SocialAuthRepository(
        callbackResult: const SocialCallbackResult(
          provider: 'google',
          code: 0,
          lineLinkRequired: false,
          linkToken: '',
          displayName: '',
          pictureUrl: '',
          passwordResetReady: false,
          passwordResetToken: '',
          orderId: '',
          message: '',
          session: CustomerSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            pinRequired: false,
            pinSetupRequired: false,
            customerId: 'cus_wrapped',
          ),
        ),
      );
      final payload = Uri.encodeComponent(
        '{"authorizationCode":"wrapped-code",'
        '"callbackState":"wrapped-state",'
        '"redirect":"/affiliate"}',
      );

      final router = _router(
        initialLocation: '/social/google/callback?payload=$payload',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            affiliateReferralServiceProvider.overrideWithValue(
              _NoopAffiliateReferralService(),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );

      await _pumpCallbackWork(tester);

      expect(router.routerDelegate.currentConfiguration.uri.path, '/affiliate');
    },
  );

  testWidgets('generic social callback accepts metadata OAuth wrapper aliases', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
    );
    final metadata = Uri.encodeComponent(
      '{"oauth":{"providerCode":"metadata-code","providerState":"metadata-state"}}',
    );

    final router = _router(
      initialLocation: '/social/google/callback?metadata=$metadata',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(repository.lastCallbackProvider, 'google');
    expect(repository.lastCallbackQuery?['code'], 'metadata-code');
    expect(repository.lastCallbackQuery?['state'], 'metadata-state');
    expect(repository.lastCallbackQuery?['oauth'], contains('providerCode'));
  });

  testWidgets('generic social callback shows API payload errors like Nuxt', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
      callbackError: _apiException(
        'บัญชี Google นี้ถูกระงับชั่วคราว',
        path: '/customer/auth/social/google/callback',
      ),
    );

    final router = _router(
      initialLocation: '/social/google/callback?code=abc&state=oauth_state',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(find.text('บัญชี Google นี้ถูกระงับชั่วคราว'), findsOneWidget);
    expect(
      find.text('Could not connect to sign in with Google.'),
      findsNothing,
    );
  });

  testWidgets('generic social callback hides internal errors', (tester) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
      callbackError: StateError('internal callback failed'),
    );

    final router = _router(
      initialLocation: '/social/google/callback?code=abc&state=oauth_state',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(
      find.text('Could not connect to sign in with Google.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal callback failed'), findsNothing);
  });

  testWidgets(
    'social callback PIN errors restore the saved OAuth return path',
    (tester) async {
      final tokenStore = _SocialCallbackTokenStore('/affiliate');
      final repository = _SocialAuthRepository(
        callbackResult: _emptyCallback('google'),
        callbackError: const {
          'error': {
            'code': 'pin_required',
            'message': 'Please confirm your PIN.',
          },
        },
      );

      final router = _router(
        initialLocation: '/social/google/callback?code=abc&state=oauth_state',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authTokenStoreProvider.overrideWithValue(tokenStore),
            authRepositoryProvider.overrideWithValue(repository),
            affiliateReferralServiceProvider.overrideWithValue(
              _NoopAffiliateReferralService(),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );

      await _pumpCallbackWork(tester);

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/pin?redirect=%2Faffiliate',
      );
      expect(find.text('pin-flow'), findsOneWidget);
    },
  );

  testWidgets('generic social link-phone submits Google provider and signs in', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: const SocialCallbackResult(
        provider: 'google',
        code: 0,
        lineLinkRequired: false,
        linkToken: '',
        displayName: '',
        pictureUrl: '',
        passwordResetReady: false,
        passwordResetToken: '',
        orderId: '',
        message: '',
      ),
      linkSession: const CustomerSession(
        accessToken: 'linked-access-token',
        refreshToken: 'linked-refresh-token',
        pinRequired: true,
        pinSetupRequired: false,
        customerId: 'cus_google_linked',
      ),
    );
    final affiliate = _NoopAffiliateReferralService();

    final router = _router(
      initialLocation:
          '/social/google/link-phone?token=google-link-token&name=Ada%20Google&redirect=%2Fcheckout',
      useRealLinkPhoneScreen: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(affiliate),
        ],
        child: _TestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.text(
        'If this phone already has an account, we will check the existing password and link this Google account immediately.',
      ),
      findsOneWidget,
    );
    await _completeSocialOnboarding(tester);

    expect(repository.lastLinkProvider, 'google');
    expect(repository.lastLinkToken, 'google-link-token');
    expect(repository.lastLinkPhone, '0812345678');
    expect(repository.lastLinkFirstName, 'Ada');
    expect(repository.lastLinkLastName, 'Lovelace');
    expect(repository.lastLinkPassword, 'secret1234');
    expect(repository.lastLinkOtpVerificationToken, 'otp-social-verified');
    expect(repository.lastLinkAcceptedTerms, isTrue);
    expect(repository.lastLinkRedirect, '/checkout');
    expect(affiliate.applied, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/pin');
    expect(
      router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['redirect'],
      '/checkout',
    );
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('social link-phone redirects missing token back to login', (
    tester,
  ) async {
    final router = _router(
      initialLocation: '/social/line/link-phone?redirect=%2Fcheckout',
      useRealLinkPhoneScreen: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    expect(
      router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['redirect'],
      '/checkout',
    );
    expect(find.text('login:/checkout'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('social link-phone accepts handoff data from URL fragment', (
    tester,
  ) async {
    final router = _router(
      initialLocation:
          '/social/google/link-phone#token=fragment-link-token&name=Ada%20Fragment&redirect=%2Fcheckout',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(_testConfig)],
        child: _TestApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('link:google:fragment-link-token:Ada Fragment'),
      findsOneWidget,
    );
  });

  testWidgets('social link-phone sends affiliate redirects through global PIN', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('line'),
      linkSession: const CustomerSession(
        accessToken: 'linked-access-token',
        refreshToken: 'linked-refresh-token',
        pinRequired: true,
        pinSetupRequired: false,
        customerId: 'cus_line_linked',
      ),
    );
    final affiliate = _NoopAffiliateReferralService();

    final router = _router(
      initialLocation:
          '/social/line/link-phone?token=line-link-token&name=Ada%20Line&redirect=%2Faffiliate',
      useRealLinkPhoneScreen: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(affiliate),
        ],
        child: _TestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();
    await _completeSocialOnboarding(tester);

    expect(repository.lastLinkRedirect, '/affiliate');
    expect(affiliate.applied, isTrue);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/pin?redirect=%2Faffiliate',
    );
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('social link-phone shows API payload errors like Nuxt', (
    tester,
  ) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
      linkError: _apiException(
        'เบอร์โทรศัพท์นี้ถูกผูกกับบัญชีอื่น',
        path: '/customer/auth/social/google/link-phone',
      ),
    );

    final router = _router(
      initialLocation:
          '/social/google/link-phone?token=google-link-token&name=Ada%20Google',
      useRealLinkPhoneScreen: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();
    await _completeSocialOnboarding(tester);

    expect(repository.lastLinkPhone, '0812345678');
    expect(find.text('เบอร์โทรศัพท์นี้ถูกผูกกับบัญชีอื่น'), findsOneWidget);
    expect(find.text('Could not link Google account.'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      contains('/social/google/link-phone'),
    );
  });

  testWidgets('social link-phone hides internal errors', (tester) async {
    final repository = _SocialAuthRepository(
      callbackResult: _emptyCallback('google'),
      linkError: StateError('internal link failed'),
    );

    final router = _router(
      initialLocation:
          '/social/google/link-phone?token=google-link-token&name=Ada%20Google',
      useRealLinkPhoneScreen: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();
    await _completeSocialOnboarding(tester);

    expect(find.text('Could not link Google account.'), findsOneWidget);
    expect(find.textContaining('internal link failed'), findsNothing);
  });

  testWidgets(
    'social link-phone keeps content usable on narrow mobile screens',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _SocialAuthRepository(
        callbackResult: const SocialCallbackResult(
          provider: 'line',
          code: 0,
          lineLinkRequired: false,
          linkToken: '',
          displayName: '',
          pictureUrl: '',
          passwordResetReady: false,
          passwordResetToken: '',
          orderId: '',
          message: '',
        ),
      );
      final router = _router(
        initialLocation: Uri(
          path: '/social/line/link-phone',
          queryParameters: {
            'token': 'line-link-token',
            'name': 'สมาชิกชื่อยาวมากสำหรับทดสอบการตัดคำในหน้าผูกบัญชีไลน์',
          },
        ).toString(),
        useRealLinkPhoneScreen: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            authRepositoryProvider.overrideWithValue(repository),
            affiliateReferralServiceProvider.overrideWithValue(
              _NoopAffiliateReferralService(),
            ),
          ],
          child: _TestApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LINE account'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _completeSocialOnboarding(WidgetTester tester) async {
  expect(find.byType(TextField), findsOneWidget);
  await tester.enterText(find.byType(TextField), '0812345678');
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  expect(find.byType(TextField), findsOneWidget);
  await tester.enterText(find.byType(TextField), '123456');
  await tester.pumpAndSettle();

  expect(find.byType(TextField), findsNWidgets(4));
  await tester.enterText(find.byType(TextField).at(0), 'Ada');
  await tester.enterText(find.byType(TextField).at(1), 'Lovelace');
  await tester.enterText(find.byType(TextField).at(2), 'secret1234');
  await tester.enterText(find.byType(TextField).at(3), 'secret1234');
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

class _LoginTestApp extends StatelessWidget {
  const _LoginTestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en', 'US'),
      supportedLocales: supportedCustomerLocales,
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginScreen(),
    );
  }
}

Future<void> _pumpCallbackWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

GoRouter _router({
  required String initialLocation,
  bool useRealLinkPhoneScreen = false,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/social/:provider/callback',
        builder: (context, state) => LineCallbackScreen(
          provider: state.pathParameters['provider'] ?? 'line',
          query: customerAuthRouteParameters(state.uri),
        ),
      ),
      GoRoute(
        path: '/social/:provider/link-phone',
        builder: (context, state) {
          final query = customerAuthRouteParameters(state.uri);
          return useRealLinkPhoneScreen
              ? LineLinkPhoneScreen(
                  provider: state.pathParameters['provider'] ?? 'line',
                  linkToken: query['token'] ?? '',
                  displayName: query['name'] ?? '',
                  pictureUrl: query['picture_url'] ?? '',
                  redirect: query['redirect'] ?? '/',
                )
              : Text(
                  [
                    'link',
                    state.pathParameters['provider'] ?? '',
                    query['token'] ?? '',
                    query['name'] ?? '',
                  ].join(':'),
                  textDirection: TextDirection.ltr,
                );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => Text(
          'login:${state.uri.queryParameters['redirect'] ?? ''}',
          textDirection: TextDirection.ltr,
        ),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) =>
            const Text('pin-flow', textDirection: TextDirection.ltr),
      ),
      GoRoute(
        path: '/checkout/pending',
        builder: (context, state) => Text(
          'pending:${state.uri.queryParameters['order_id'] ?? ''}',
          textDirection: TextDirection.ltr,
        ),
      ),
      GoRoute(
        path: '/affiliate',
        builder: (context, state) =>
            const Text('affiliate-flow', textDirection: TextDirection.ltr),
      ),
    ],
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      locale: const Locale('en', 'US'),
      supportedLocales: supportedCustomerLocales,
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.com/api/v1',
  defaultLocale: 'en-US',
);

class _SocialAuthRepository extends AuthRepository {
  _SocialAuthRepository({
    required this.callbackResult,
    this.socialLoginUrlError,
    this.socialLoginUrlFuture,
    this.callbackError,
    this.linkError,
    this.linkSession = const CustomerSession(
      accessToken: 'linked-access',
      refreshToken: 'linked-refresh',
      pinRequired: false,
      pinSetupRequired: false,
      customerId: 'cus_linked',
    ),
  }) : super(
         api: ApiClient(
           const AppConfig(
             apiBaseUrl: 'https://partner.example.com/api/v1',
             defaultLocale: 'en-US',
           ),
           AuthTokenStore(),
           localeTag: 'en-US',
         ),
         tokenStore: AuthTokenStore(),
       );

  final SocialCallbackResult callbackResult;
  final Object? socialLoginUrlError;
  final Future<String>? socialLoginUrlFuture;
  final Object? callbackError;
  final Object? linkError;
  final CustomerSession linkSession;
  String? lastCallbackProvider;
  String? lastSocialLoginProvider;
  Map<String, dynamic>? lastCallbackQuery;
  String? lastLinkProvider;
  String? lastLinkToken;
  String? lastLinkPhone;
  String? lastLinkFirstName;
  String? lastLinkLastName;
  String? lastLinkPassword;
  String? lastLinkPasswordConfirmation;
  String? lastLinkOtpVerificationToken;
  bool? lastLinkAcceptedTerms;
  String? lastLinkRedirect;
  String? lastOtpRequestPhone;
  String? lastOtpRequestPurpose;
  String? lastOtpVerifyPhone;
  String? lastOtpVerifyPurpose;
  String? lastOtp;

  @override
  Future<String> socialLoginUrl(
    String provider, {
    String purpose = 'login',
    String? redirect,
    bool callbackUsesAuth = false,
  }) {
    lastSocialLoginProvider = provider;
    final error = socialLoginUrlError;
    if (error != null) throw error;
    final future = socialLoginUrlFuture;
    if (future != null) return future;
    return Future.value('https://social.example.com/oauth');
  }

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    lastOtpRequestPhone = phone;
    lastOtpRequestPurpose = purpose;
    return const OtpRequestResult(
      phoneMasked: '08xxxxx678',
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String otp,
  }) async {
    lastOtpVerifyPhone = phone;
    lastOtpVerifyPurpose = purpose;
    lastOtp = otp;
    return const OtpVerifyResult(verificationToken: 'otp-social-verified');
  }

  @override
  Future<SocialCallbackResult> socialCallback({
    required String provider,
    required Map<String, dynamic> query,
    bool? auth,
  }) async {
    lastCallbackProvider = provider;
    lastCallbackQuery = query;
    final error = callbackError;
    if (error != null) throw error;
    return callbackResult;
  }

  @override
  Future<CustomerSession> socialLinkPhone({
    required String provider,
    required String linkToken,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirmation,
    required String otpVerificationToken,
    required bool acceptedTerms,
    String? redirect,
  }) async {
    lastLinkProvider = provider;
    lastLinkToken = linkToken;
    lastLinkPhone = phone;
    lastLinkFirstName = firstName;
    lastLinkLastName = lastName;
    lastLinkPassword = password;
    lastLinkPasswordConfirmation = passwordConfirmation;
    lastLinkOtpVerificationToken = otpVerificationToken;
    lastLinkAcceptedTerms = acceptedTerms;
    lastLinkRedirect = redirect;
    final error = linkError;
    if (error != null) throw error;
    return linkSession;
  }
}

class _SocialCallbackTokenStore extends AuthTokenStore {
  _SocialCallbackTokenStore(this.redirect);

  final String redirect;

  @override
  Future<SocialCallbackContext?> readSocialCallbackContext(String state) async {
    return SocialCallbackContext(state: state, auth: false, redirect: redirect);
  }
}

class _SuccessfulLinkLauncher extends CustomerLinkLauncher {
  const _SuccessfulLinkLauncher();

  @override
  Future<bool> openSocialLogin(String provider, Uri uri) async {
    return true;
  }
}

SocialCallbackResult _emptyCallback(String provider) {
  return SocialCallbackResult(
    provider: provider,
    code: 0,
    lineLinkRequired: false,
    linkToken: '',
    displayName: '',
    pictureUrl: '',
    passwordResetReady: false,
    passwordResetToken: '',
    orderId: '',
    message: '',
  );
}

DioException _apiException(String message, {required String path}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}

class _NoopAffiliateReferralService extends AffiliateReferralService {
  _NoopAffiliateReferralService()
    : super(
        config: const AppConfig(
          apiBaseUrl: 'https://partner.example.com/api/v1',
          defaultLocale: 'en-US',
        ),
        repository: AffiliateReferralRepository(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'en-US',
            ),
            AuthTokenStore(),
            localeTag: 'en-US',
          ),
        ),
        store: AffiliateReferralStore(),
        visitIdStore: PublicVisitIdStore(idFactory: (_) => 'visitor'),
      );

  bool applied = false;

  @override
  Future<void> applyStored({bool registered = false}) async {
    applied = true;
  }
}
