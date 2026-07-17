import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/news/presentation/news_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('short news detail starts below the compact fixed header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(399, 849);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpNewsDetail(
      tester,
      const NewsItem(
        id: 'short-news',
        title: 'ข่าวประชาสัมพันธ์แบบสั้น',
        summary: 'รายละเอียดข่าวแบบสั้น',
        body: 'เนื้อหาข่าว',
        slug: 'short-news',
        url: '',
        coverUrl: '',
        publishedAt: '2026-07-14T10:58:00+07:00',
      ),
    );

    final sheetTop = tester
        .getTopLeft(find.byKey(const ValueKey('news-content-sheet')))
        .dy;
    final articleTop = tester
        .getTopLeft(find.byKey(const ValueKey('news-detail-article')))
        .dy;

    expect(sheetTop, closeTo(150, 1));
    expect(articleTop, closeTo(sheetTop + 24, 1));
    expect(find.byKey(const ValueKey('news-detail-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news detail media fills the mobile article band', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpNewsDetail(
      tester,
      const NewsItem(
        id: 'cover-news',
        title: 'ข่าวพร้อมภาพปก',
        summary: 'ภาพต้องเต็มแนวบทความ',
        body: 'เนื้อหาข่าว',
        slug: 'cover-news',
        url: '',
        coverUrl: 'https://example.com/news-cover.webp',
        publishedAt: '2026-07-14T10:58:00+07:00',
      ),
    );

    final articleSize = tester.getSize(
      find.byKey(const ValueKey('news-detail-article')),
    );
    final articleTop = tester
        .getTopLeft(find.byKey(const ValueKey('news-detail-article')))
        .dy;
    final mediaSize = tester.getSize(
      find.byKey(const ValueKey('news-detail-media')),
    );

    expect(mediaSize.width, closeTo(articleSize.width, 1));
    expect(mediaSize.width, closeTo(390, 1));
    expect(mediaSize.width / mediaSize.height, closeTo(16 / 9, 0.02));
    final titleTop = tester.getTopLeft(find.text('ข่าวพร้อมภาพปก')).dy;
    final mediaTop = tester
        .getTopLeft(find.byKey(const ValueKey('news-detail-media')))
        .dy;
    final mediaBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('news-detail-media')))
        .dy;
    expect(mediaTop, closeTo(articleTop, 1));
    expect(titleTop, greaterThan(mediaBottom));
    expect(find.byKey(const ValueKey('news-detail-divider')), findsOneWidget);
    expect(find.byKey(const ValueKey('news-detail-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news detail does not repeat summary in the article body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpNewsDetail(
      tester,
      const NewsItem(
        id: 'promo',
        title: 'ข่าวแคมเปญ',
        summary: 'สรุปโปรโมชัน',
        body: 'สรุปโปรโมชัน\n\nรายละเอียดเพิ่มเติมสำหรับสมาชิก',
        slug: 'promo',
        url: '',
        coverUrl: '',
        publishedAt: '2026-07-06T09:30:00+07:00',
      ),
    );

    expect(find.text('ข่าวแคมเปญ'), findsOneWidget);
    expect(find.text('ข่าวสารและกิจกรรม'), findsOneWidget);
    expect(find.text('สรุปโปรโมชัน'), findsOneWidget);
    expect(find.text('รายละเอียดเพิ่มเติมสำหรับสมาชิก'), findsOneWidget);
    expect(_textColor(tester, 'ข่าวสารและกิจกรรม'), const Color(0xFF0875DF));
    expect(_textColor(tester, 'ข่าวแคมเปญ'), const Color(0xFF1F2937));
    expect(_textColor(tester, 'สรุปโปรโมชัน'), const Color(0xFF53616F));
    expect(
      _textColor(tester, 'รายละเอียดเพิ่มเติมสำหรับสมาชิก'),
      const Color(0xFF344054),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('news detail renders production html body as readable paragraphs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpNewsDetail(
      tester,
      const NewsItem(
        id: 'html-news',
        title: 'ข่าวรูปแบบ HTML',
        summary: 'รายละเอียดสำหรับสมาชิก',
        body:
            '&lt;p&gt;รายละเอียดสำหรับสมาชิก&lt;/p&gt;&lt;p&gt;รับสิทธิ์ผ่านแอป &amp;amp; ร้านค้า&lt;/p&gt;&lt;ul&gt;&lt;li&gt;จำกัด 1 สิทธิ์&lt;/li&gt;&lt;/ul&gt;',
        slug: 'html-news',
        url: '',
        coverUrl: '',
        publishedAt: '2026-07-06T09:30:00+07:00',
      ),
    );

    expect(find.text('ข่าวรูปแบบ HTML'), findsOneWidget);
    expect(find.text('รายละเอียดสำหรับสมาชิก'), findsOneWidget);
    expect(find.text('รับสิทธิ์ผ่านแอป & ร้านค้า'), findsOneWidget);
    expect(find.text('จำกัด 1 สิทธิ์'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
    expect(find.textContaining('&lt;'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpNewsDetail(WidgetTester tester, NewsItem item) async {
  final router = GoRouter(
    initialLocation: '/news/${item.slug}',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(path: '/profile', builder: (_, __) => const Text('Profile')),
      GoRoute(path: '/tickets', builder: (_, __) => const Text('Tickets')),
      GoRoute(path: '/news', builder: (_, __) => const Text('News list')),
      GoRoute(
        path: '/news/:slug',
        builder: (_, state) =>
            NewsDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const {
            'site': {'name': 'Alpha Shop'},
          }),
        ),
        newsDetailProvider(item.slug).overrideWith((_) async => item),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Color? _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text).first).style?.color;
}
