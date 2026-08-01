import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/shared/widgets/app_splash.dart';
import 'package:customer_flutter/shared/widgets/flexible_image.dart';
import 'package:customer_flutter/shared/widgets/tenant_brand_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSplashHost keeps splash for minimum duration then hides', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSplashMinimumDurationProvider.overrideWithValue(
            const Duration(milliseconds: 120),
          ),
          appSplashFadeDurationProvider.overrideWithValue(Duration.zero),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'display_name': 'Demo Shop', 'locale': 'th-TH'},
            }),
          ),
        ],
        child: const _SplashHarness(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('app-splash-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-splash-loader')), findsOneWidget);
    final artwork = tester.widget<Image>(
      find.byKey(const ValueKey('app-splash-background')),
    );
    expect((artwork.image as AssetImage).assetName, appSplashBackgroundAsset);
    expect(find.text('Ready content'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-splash-background')), findsNothing);
    expect(find.text('Ready content'), findsOneWidget);
  });

  testWidgets('AppSplashHost hides even when bootstrap fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSplashMinimumDurationProvider.overrideWithValue(Duration.zero),
          appSplashFadeDurationProvider.overrideWithValue(Duration.zero),
          mobileBootstrapProvider.overrideWith(
            (_) async => throw StateError('bootstrap failed'),
          ),
        ],
        child: const _SplashHarness(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-splash-background')), findsNothing);
    expect(find.text('Ready content'), findsOneWidget);
  });

  testWidgets('AppSplashHost waits for auth session startup', (tester) async {
    final authStartup = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSplashMinimumDurationProvider.overrideWithValue(Duration.zero),
          appSplashFadeDurationProvider.overrideWithValue(Duration.zero),
          authSessionStartupProvider.overrideWith((_) => authStartup.future),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'site': {'display_name': 'Demo Shop', 'locale': 'th-TH'},
            }),
          ),
        ],
        child: const _SplashHarness(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const ValueKey('app-splash-background')), findsOneWidget);

    authStartup.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const ValueKey('app-splash-background')), findsNothing);
    expect(find.text('Ready content'), findsOneWidget);
  });

  testWidgets('AppSplashHost keeps its artwork surface while theme changes', (
    tester,
  ) async {
    final bootstrap = Completer<MobileBootstrap>();
    final theme = ValueNotifier<Color>(const Color(0xFF087FF0));
    addTearDown(theme.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSplashMinimumDurationProvider.overrideWithValue(
            const Duration(seconds: 5),
          ),
          mobileBootstrapProvider.overrideWith((_) => bootstrap.future),
        ],
        child: ValueListenableBuilder<Color>(
          valueListenable: theme,
          builder: (_, primary, __) => _SplashThemeHarness(primary: primary),
        ),
      ),
    );
    await tester.pump();

    Material splashSurface() => tester.widget<Material>(
      find.byKey(const ValueKey('app-splash-surface')),
    );
    expect(splashSurface().color, const Color(0xFF0B96DC));

    theme.value = const Color(0xFF16A085);
    await tester.pump();
    expect(splashSurface().color, const Color(0xFF0B96DC));
    expect(find.byKey(const ValueKey('app-splash-background')), findsOneWidget);
  });

  testWidgets(
    'AppSplashHost adapts artwork fit for portrait and wide screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSplashMinimumDurationProvider.overrideWithValue(
              const Duration(seconds: 5),
            ),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(const {
                'site': {'display_name': 'Demo Shop', 'locale': 'th-TH'},
              }),
            ),
          ],
          child: const _SplashHarness(),
        ),
      );
      await tester.pump();

      Image artwork() => tester.widget<Image>(
        find.byKey(const ValueKey('app-splash-background')),
      );
      expect(artwork().fit, BoxFit.cover);

      tester.view.physicalSize = const Size(1280, 720);
      await tester.pump();

      expect(artwork().fit, BoxFit.contain);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TenantBrandHeader resolves relative partner logo URLs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'display_name': 'Demo Shop', 'locale': 'th-TH'},
              'brand': {'logo_url': '/storage/tenant/logo.webp'},
            }),
          ),
        ],
        child: const _BrandHeaderHarness(),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<FlexibleImage>(find.byType(FlexibleImage));
    expect(
      image.source,
      'https://partner.example.com/storage/tenant/logo.webp',
    );
  });

  testWidgets('TenantBrandHeader keeps long partner names and logos bounded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longPartnerName =
        'บริษัทตัวอย่างพาร์ทเนอร์ชื่อยาวมาก International Lottery Rewards';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'siteConfig': {'displayName': longPartnerName, 'locale': 'th-TH'},
              'brandConfig': {
                'logoUrl':
                    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
                    'CAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              },
            }),
          ),
        ],
        child: const _BrandHeaderHarness(),
      ),
    );
    await tester.pumpAndSettle();

    final logo = tester.widget<FlexibleImage>(find.byType(FlexibleImage));
    expect(logo.fit, BoxFit.contain);
    expect(
      tester.getRect(find.byType(FlexibleImage)).width,
      lessThanOrEqualTo(72),
    );

    final label = tester.widget<Text>(find.text(longPartnerName));
    expect(label.maxLines, 2);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.textAlign, TextAlign.center);
    expect(
      tester.widget<TenantBrandHeader>(find.byType(TenantBrandHeader)).maxWidth,
      280,
    );
    expect(
      tester.getRect(find.text(longPartnerName)).width,
      lessThanOrEqualTo(280),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TenantBrandLogo uses runtime identity without partner fallback',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson({
                'site': {
                  'display_name': 'Runtime Lucky Shop',
                  'support_phone': '02-000-0000',
                  'locale': 'th-TH',
                },
              }),
            ),
          ],
          child: const _BrandLogoHarness(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Runtime Lucky Shop'), findsOneWidget);
      expect(find.text('02-000-0000'), findsOneWidget);
      expect(find.text('GLO'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SplashHarness extends StatelessWidget {
  const _SplashHarness();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('th', 'TH'),
      supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AppSplashHost(
        child: Scaffold(body: Center(child: Text('Ready content'))),
      ),
    );
  }
}

class _SplashThemeHarness extends StatelessWidget {
  const _SplashThemeHarness({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
        ).copyWith(primary: primary),
      ),
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const AppSplashHost(
        child: Scaffold(body: Center(child: Text('Ready content'))),
      ),
    );
  }
}

class _BrandHeaderHarness extends StatelessWidget {
  const _BrandHeaderHarness();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('th', 'TH'),
      supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: TenantBrandHeader())),
    );
  }
}

class _BrandLogoHarness extends StatelessWidget {
  const _BrandLogoHarness();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF087FF0),
        body: Center(child: TenantBrandLogo()),
      ),
    );
  }
}
