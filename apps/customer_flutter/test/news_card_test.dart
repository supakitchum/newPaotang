import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/presentation/news_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('news timestamps use Bangkok time independently of device timezone', () {
    expect(
      formatBangkokLocalizedDateTime('2026-06-08T06:14:00Z', 'en-US'),
      '8 Jun 2026 13:14',
    );
  });

  testWidgets('news card opens runtime external url through shared launcher', (
    tester,
  ) async {
    final launcher = _RecordingLinkLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerLinkLauncherProvider.overrideWithValue(launcher),
        ],
        child: const _NewsCardTestApp(
          item: NewsItem(
            id: 'news_external',
            title: 'ข่าวภายนอก',
            summary: 'เปิดจาก url ภายนอกที่ backend ส่งมา',
            body: '',
            slug: 'fallback-news',
            url: 'https://partner.example.com/campaign',
            coverUrl: '',
            publishedAt: '2026-06-08T13:14:00+07:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ข่าวภายนอก'));
    await tester.pumpAndSettle();

    expect(launcher.openedUris, [
      Uri.parse('https://partner.example.com/campaign'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news card rejects unsafe runtime url before slug fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _NewsCardTestApp(
          item: NewsItem(
            id: 'news_unsafe',
            title: 'ข่าว unsafe',
            summary: 'ไม่ควรเปิด javascript URL',
            body: '',
            slug: 'fallback-news',
            url: 'javascript:alert(1)',
            coverUrl: '',
            publishedAt: '2026-06-08T13:14:00+07:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = tester.widget<GestureDetector>(
      find.descendant(
        of: find.byType(NewsSideCard),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(gesture.onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news card uses exact Nuxt list colors', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _NewsCardTestApp(
          item: NewsItem(
            id: 'news_visual',
            title: 'ข่าวสีตรงต้นฉบับ',
            summary: 'รายละเอียดตามการ์ดข่าว Nuxt',
            body: '',
            slug: 'news-visual',
            url: '',
            coverUrl: '',
            publishedAt: '2026-06-08T13:14:00+07:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textColor(tester, 'ข่าวสาร'), const Color(0xFF0B69DC));
    expect(_textColor(tester, 'ข่าวสีตรงต้นฉบับ'), const Color(0xFF17335F));
    expect(
      _textColor(tester, 'รายละเอียดตามการ์ดข่าว Nuxt'),
      const Color(0xFF64748B),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('news card uses full-width 16:9 cover media', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: _NewsCardTestApp(
          item: NewsItem(
            id: 'news_layout',
            title: 'ข่าวอ่านง่าย',
            summary: 'ภาพปกต้องกินเต็มความกว้างของการ์ด',
            body: '',
            slug: 'news-layout',
            url: '',
            coverUrl: '',
            publishedAt: '2026-06-08T13:14:00+07:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardSize =
        tester.getSize(find.byKey(const ValueKey('news-card-surface')));
    final mediaSize =
        tester.getSize(find.byKey(const ValueKey('news-card-media')));

    expect(mediaSize.width, closeTo(cardSize.width, 1));
    expect(mediaSize.width / mediaSize.height, closeTo(16 / 9, 0.02));
    expect(tester.takeException(), isNull);
  });
}

Color? _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style?.color;
}

class _NewsCardTestApp extends StatelessWidget {
  const _NewsCardTestApp({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: fallbackCustomerLocale,
      supportedLocales: supportedCustomerLocales,
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: NewsSideCard(item: item))),
    );
  }
}

class _RecordingLinkLauncher extends CustomerLinkLauncher {
  final openedUris = <Uri>[];

  @override
  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
    openedUris.add(uri);
    return true;
  }
}
