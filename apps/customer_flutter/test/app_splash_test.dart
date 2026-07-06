import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/shared/widgets/app_splash.dart';
import 'package:customer_flutter/shared/widgets/customer_loading_indicator.dart';
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

    expect(find.byType(CustomerLoadingMark), findsOneWidget);
    expect(find.text('Demo Shop'), findsOneWidget);
    expect(find.text('Ready content'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerLoadingMark), findsNothing);
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

    expect(find.byType(CustomerLoadingMark), findsNothing);
    expect(find.text('Ready content'), findsOneWidget);
  });

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
              'siteConfig': {
                'displayName': longPartnerName,
                'locale': 'th-TH',
              },
              'brandConfig': {
                'logoUrl': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
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
