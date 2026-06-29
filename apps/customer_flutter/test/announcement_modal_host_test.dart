import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/news/presentation/announcement_modal_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('announcement modal suppresses news and maintenance paths', () {
    expect(shouldSuppressAnnouncementModal('/news'), isTrue);
    expect(shouldSuppressAnnouncementModal('/news/promo'), isTrue);
    expect(shouldSuppressAnnouncementModal('/maintenance'), isTrue);
    expect(shouldSuppressAnnouncementModal('/maintenance/planned'), isTrue);
    expect(shouldSuppressAnnouncementModal('/'), isFalse);
    expect(shouldSuppressAnnouncementModal('/activities'), isFalse);
  });

  testWidgets('announcement modal shows once and opens detail', (tester) async {
    final repository = _FakeNewsRepository(
      item: const NewsItem(
        id: 'news_1',
        title: 'Promo',
        summary: '',
        body: '',
        slug: 'promo',
        url: '',
        coverUrl: 'https://example.invalid/promo.webp',
        publishedAt: null,
      ),
    );
    final router = _testRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(repository),
        ],
        child: _TestApp(router: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.modalCalls, 1);
    expect(find.text('Home'), findsOneWidget);
    expect(
      find.byKey(const Key('announcement-modal-close-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('announcement-modal-image-button')));
    await tester.pumpAndSettle();

    expect(find.text('News detail'), findsOneWidget);
    expect(
      find.byKey(const Key('announcement-modal-close-button')),
      findsNothing,
    );
  });

  testWidgets('announcement modal can be dismissed without navigating', (
    tester,
  ) async {
    final repository = _FakeNewsRepository(
      item: const NewsItem(
        id: 'news_1',
        title: 'Promo',
        summary: '',
        body: '',
        slug: 'promo',
        url: '',
        coverUrl: 'https://example.invalid/promo.webp',
        publishedAt: null,
      ),
    );
    final router = _testRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(repository),
        ],
        child: _TestApp(router: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('announcement-modal-close-button')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(
      find.byKey(const Key('announcement-modal-close-button')),
      findsNothing,
    );
    expect(repository.modalCalls, 1);
  });

  testWidgets('announcement modal does not load on suppressed news routes', (
    tester,
  ) async {
    final repository = _FakeNewsRepository(
      item: const NewsItem(
        id: 'news_1',
        title: 'Promo',
        summary: '',
        body: '',
        slug: 'promo',
        url: '',
        coverUrl: 'https://example.invalid/promo.webp',
        publishedAt: null,
      ),
    );
    final router = _testRouter(initialLocation: '/news');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newsRepositoryProvider.overrideWithValue(repository),
        ],
        child: _TestApp(router: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('News index'), findsOneWidget);
    expect(
      find.byKey(const Key('announcement-modal-close-button')),
      findsNothing,
    );
    expect(repository.modalCalls, 0);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        return AnnouncementModalHost(
          router: router,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

GoRouter _testRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Text('Home')),
      GoRoute(
        path: '/news',
        builder: (context, state) => const Text('News index'),
      ),
      GoRoute(
        path: '/news/:slug',
        builder: (context, state) => const Text('News detail'),
      ),
    ],
  );
}

class _FakeNewsRepository extends NewsRepository {
  _FakeNewsRepository({required this.item})
      : super(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'en-US',
            ),
            AuthTokenStore(),
            localeTag: 'en-US',
          ),
          (value) => value,
        );

  final NewsItem? item;
  int modalCalls = 0;

  @override
  Future<NewsItem?> modal() async {
    modalCalls++;
    return item;
  }

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
