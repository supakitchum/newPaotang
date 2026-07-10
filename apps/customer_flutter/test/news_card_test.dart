import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/presentation/news_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
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

    expect(_textColor(tester, 'ข่าวประชาสัมพันธ์'), const Color(0xFF0B69DC));
    expect(_textColor(tester, 'ข่าวสีตรงต้นฉบับ'), const Color(0xFF17335F));
    expect(
      _textColor(tester, 'รายละเอียดตามการ์ดข่าว Nuxt'),
      const Color(0xFF64748B),
    );
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
