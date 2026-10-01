import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_repository.dart';
import 'package:customer_flutter/features/monitoring/presentation/public_visit_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public visit source prefers explicit UTM source', () {
    expect(
      publicVisitTrafficSource('/buy?utm_source=LINE@Official', ''),
      'lineofficial',
    );
  });

  test('public visit source detects affiliate and known referrers', () {
    expect(publicVisitTrafficSource('/?ref=AFF123', ''), 'affiliate');
    expect(
      publicVisitTrafficSource('/', 'https://line.me/R/ti/p/example'),
      'line',
    );
    expect(
      publicVisitTrafficSource('/', 'https://www.google.co.th/search?q=lotto'),
      'google',
    );
    expect(publicVisitTrafficSource('/', ''), 'direct');
  });

  test('public visit channel and route names are normalized', () {
    expect(publicVisitTrafficChannel('/buy?utm_medium=cpc'), 'cpc');
    expect(publicVisitTrafficChannel('/buy?utm_campaign=draw-01'), 'draw-01');
    expect(publicVisitRouteName('/buy/search?d1=1'), 'buy_search');
    expect(publicVisitRouteName('/'), 'home');
  });

  test('public visit host scope and payload are backend-friendly', () {
    expect(
      normalizePublicVisitHostScope('พบโชค.localhost:3000'),
      'localhost:3000',
    );

    final payload = const PublicVisitPayload(
      visitorId: 'pv_1',
      sessionId: 'pvs_1',
      source: 'affiliate',
      channel: 'AFF123',
      path: '/buy?ref=AFF123',
      screen: '390x844',
      timezone: 'Asia/Bangkok',
      routeName: 'buy',
    ).toJson();

    expect(payload['visitor_id'], 'pv_1');
    expect(payload['session_id'], 'pvs_1');
    expect(payload['source'], 'affiliate');
    expect(payload['channel'], 'AFF123');
    expect(payload['path'], '/buy?ref=AFF123');
    expect(payload['screen'], '390x844');
    expect(payload['timezone'], 'Asia/Bangkok');
    expect(payload['route_name'], 'buy');
  });

  test('public visit scopes native identity to the customer tenant', () {
    const config = AppConfig(
      apiBaseUrl: 'https://api.example.com/api/v1',
      defaultLocale: 'th-TH',
      tenantHost: 'configured.example.com',
    );

    expect(
      publicVisitHostScope(
        config,
        webHost: '',
        runtimeTenantHost: 'runtime.example.com',
      ),
      'configured.example.com',
    );
    expect(
      publicVisitHostScope(
        const AppConfig(
          apiBaseUrl: 'https://api.example.com/api/v1',
          defaultLocale: 'th-TH',
        ),
        webHost: '',
        runtimeCanonicalUrl: 'https://runtime.example.com',
      ),
      'runtime.example.com',
    );
  });
}
