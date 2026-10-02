import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:customer_flutter/features/purchase_history/presentation/purchase_history_detail_screen.dart';
import 'package:customer_flutter/features/system/presentation/system_pages.dart';
import 'package:customer_flutter/shared/services/home_news_preloader.dart';
import 'package:customer_flutter/shared/widgets/siamblend_receipt_logo.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    ('success-320x568-th', const Size(320, 568), const Locale('th', 'TH'), 'Primary wallet', 1.0, false),
    ('success-390x844-th', const Size(390, 844), const Locale('th', 'TH'), 'Primary wallet', 1.0, false),
    ('success-1440x900-th', const Size(1440, 900), const Locale('th', 'TH'), 'Primary wallet', 1.0, false),
    ('success-320x568-large', const Size(320, 568), const Locale('th', 'TH'), 'Primary wallet', 1.3, false),
    ('success-844x390-landscape', const Size(844, 390), const Locale('th', 'TH'), 'Primary wallet', 1.0, false),
    ('success-390x844-en', const Size(390, 844), const Locale('en', 'US'), 'Primary wallet', 1.0, false),
    ('success-390x844-custom', const Size(390, 844), const Locale('th', 'TH'), 'QA Travel Wallet', 1.0, false),
    ('history-390x844-th', const Size(390, 844), const Locale('th', 'TH'), 'Primary wallet', 1.0, true),
  ];
  for (final item in cases) {
    testWidgets('QA render and production export ${item.$1}', (tester) async {
      final fonts = FontLoader('Kanit')
        ..addFont(rootBundle.load('assets/fonts/kanit/Kanit-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/kanit/Kanit-Bold.ttf'));
      await tester.runAsync(fonts.load);
      await tester.runAsync(() => (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = item.$2;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      final screenKey = GlobalKey();
      final recorder = _BoundaryRecorder();
      final order = PurchaseHistoryOrder.fromJson({
        'id': 'qa_fictional_order',
        'reference': 'QA-20261001-0001',
        'payment_method': 'wallet',
        'total': {'amount': 24000, 'currency': 'THB'},
        'ticket_count': 3,
        'game': {'name': 'QA fictional draw', 'draw_at': '2026-10-01T16:00:00+07:00'},
        'wallet': {'name': item.$4},
        'store': {'name': 'QA Fictional Store'},
        'paid_at': '2026-10-01T09:00:00+07:00',
      });
      await tester.pumpWidget(RepaintBoundary(
        key: screenKey,
        child: ProviderScope(
          overrides: [
            mobileBootstrapProvider.overrideWith((_) async => MobileBootstrap.fromJson({})),
            purchaseHistoryDetailProvider('qa_fictional_order').overrideWith((_) async => order),
            receiptExportCoordinatorProvider.overrideWithValue(recorder),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: item.$3,
            supportedLocales: supportedCustomerLocales,
            localizationsDelegates: const [CustomerLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(item.$5)),
              child: child!,
            ),
            home: item.$6
                ? const PurchaseHistoryDetailScreen(orderId: 'qa_fictional_order')
                : const SuccessScreen(orderId: 'qa_fictional_order'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
        const AssetImage('assets/branding/siamblend_horizontal_logo.png'),
        tester.element(find.byType(SiamblendReceiptLogo)),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SiamblendReceiptLogo), findsOneWidget);
      expect(find.text('L6'), findsNothing);
      final l10n = CustomerLocalizations(item.$3);
      expect(find.text(l10n.walletDisplayName(item.$4)), findsWidgets);
      final save = find.text(l10n.successSaveReceipt);
      Rect? before;
      if (!item.$6) {
        before = tester.getRect(find.byKey(const ValueKey('success-primary-action')));
        expect(before.bottom, lessThanOrEqualTo(item.$2.height - 34));
        expect(tester.getRect(save).top, greaterThanOrEqualTo(47));
      }
      await _writeScreen(tester, screenKey, '${item.$1}-top');
      await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
      await tester.pumpAndSettle();
      if (before != null) {
        expect(tester.getRect(find.byKey(const ValueKey('success-primary-action'))), before);
      }
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await _writeScreen(tester, screenKey, '${item.$1}-scrolled');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(recorder.boundary, isNotNull);
      final bytes = await tester.runAsync(() => RepaintBoundaryReceiptImageExporter().capturePng(recorder.boundary!));
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(10000));
      await tester.runAsync(() async {
        final pdf = await PdfReceiptPdfExporter().buildPdf(imageBytes: bytes);
        await File('/evidence/${item.$1}-export.png').writeAsBytes(bytes);
        await File('/evidence/${item.$1}-export.pdf').writeAsBytes(pdf);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('QA six distinct cover limit warm cache and failed cover completion', (tester) async {
    final client = _ImageClient();
    debugNetworkImageHttpClientProvider = () => client;
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    PaintingBinding.instance.imageCache.clear();
    late BuildContext imageContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      imageContext = context;
      return const SizedBox();
    })));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final preloader = container.read(homeNewsPreloaderProvider);
    final covers = ['', 'a', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final items = [for (var i = 0; i < covers.length; i++) NewsItem.fromJson({
      'id': 'qa_$i', 'cover_url': covers[i].isEmpty ? '' : 'https://qa-fixture.test/${covers[i]}.png',
    })];
    final cold = Stopwatch()..start();
    await tester.runAsync(() => preloader(imageContext, items));
    cold.stop();
    expect(client.urls.map((u) => u.path).toList(), ['/a.png', '/b.png', '/c.png', '/d.png', '/e.png', '/f.png']);
    final warm = Stopwatch()..start();
    await tester.runAsync(() => preloader(imageContext, items));
    warm.stop();
    expect(client.urls.length, 6);
    client.fail = true;
    await tester.runAsync(() => preloader(imageContext, [NewsItem.fromJson({'id': 'fail', 'cover_url': 'https://qa-fixture.test/fail.png'})]));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => File('/evidence/news-fixture-timing.json').writeAsString(jsonEncode({
      'cold_decode_ms': cold.elapsedMilliseconds,
      'warm_cache_ms': warm.elapsedMilliseconds,
      'distinct_cold_requests': 6,
      'extra_warm_requests': 0,
      'failed_cover_completed': true,
      'scope': 'In-process fixture image decode, not CDN/API/device latency',
    })));
    debugNetworkImageHttpClientProvider = null;
  });
}

Future<void> _writeScreen(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/evidence/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _BoundaryRecorder implements ReceiptExportCoordinator {
  GlobalKey? boundary;
  @override
  Future<ReceiptExportResult> exportReceipt({required GlobalKey boundaryKey, required String text, required String subject, required String imageFileName, required String pdfFileName, Rect? sharePositionOrigin}) async {
    boundary = boundaryKey;
    return ReceiptExportResult.shared;
  }
}

class _ImageClient implements HttpClient {
  final urls = <Uri>[];
  bool fail = false;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    if (fail) throw const SocketException('QA fixture failure');
    return _ImageRequest();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _ImageResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uint8List bytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZQmcAAAAASUVORK5CYII=');
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) => Stream<List<int>>.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
