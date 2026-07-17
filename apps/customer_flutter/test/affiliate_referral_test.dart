import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractAffiliateRefCode accepts valid referral query aliases only', () {
    expect(extractAffiliateRefCode('/?ref=ABC123'), 'ABC123');
    expect(extractAffiliateRefCode('/buy?ref_code=ZXCV09'), 'ZXCV09');
    expect(extractAffiliateRefCode('/stores?affiliate=ab1200'), 'ab1200');
    expect(extractAffiliateRefCode('/?ref=too-long'), isNull);
    expect(extractAffiliateRefCode('/?ref=<bad>'), isNull);
    expect(extractAffiliateRefCode('/'), isNull);
  });

  test('service captures, tracks, and applies stored referral', () async {
    final repository = _FakeAffiliateReferralRepository();
    final store = _MemoryAffiliateReferralStore();
    final service = AffiliateReferralService(
      config: const AppConfig(
        apiBaseUrl: 'https://alpha.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      repository: repository,
      store: store,
      visitIdStore: _FixedPublicVisitIdStore('visitor-1'),
      webHost: () => 'alpha.example.com',
      webHref: () => 'https://alpha.example.com/register?ref=ABC123',
    );

    final captured = await service.captureFromLocation('/register?ref=ABC123');
    await service.applyStored(registered: true);

    expect(captured, 'ABC123');
    expect(repository.clickedRefCode, 'ABC123');
    expect(repository.clickedVisitorId, 'visitor-1');
    expect(
      repository.clickedLandingUrl,
      'https://alpha.example.com/register?ref=ABC123',
    );
    expect(repository.appliedRefCode, 'ABC123');
    expect(repository.appliedVisitorId, 'visitor-1');
    expect(repository.appliedRegistered, isTrue);
    expect(await store.read('alpha.example.com'), 'ABC123');
  });

  test('service clears stale referral when backend rejects it', () async {
    final repository = _FakeAffiliateReferralRepository()
      ..applyErrorStatus = 422;
    final store = _MemoryAffiliateReferralStore();
    final service = AffiliateReferralService(
      config: const AppConfig(
        apiBaseUrl: 'https://alpha.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      repository: repository,
      store: store,
      visitIdStore: _FixedPublicVisitIdStore('visitor-1'),
      webHost: () => 'alpha.example.com',
      webHref: () => '',
    );

    await store.save('alpha.example.com', 'ABC123');
    await service.applyStored();

    expect(await store.read('alpha.example.com'), isNull);
  });

  test('native referral storage is scoped to tenant instead of central API',
      () async {
    final repository = _FakeAffiliateReferralRepository();
    final store = _MemoryAffiliateReferralStore();
    final service = AffiliateReferralService(
      config: const AppConfig(
        apiBaseUrl: 'https://api.example.com/api/v1',
        defaultLocale: 'th-TH',
        tenantHost: 'partner.example.com',
      ),
      repository: repository,
      store: store,
      visitIdStore: _FixedPublicVisitIdStore('visitor-1'),
      runtimeTenantHost: 'runtime.example.com',
      webHost: () => '',
      webHref: () => '',
    );

    await service.captureFromLocation('/register?ref=ABC123');

    expect(await store.read('partner.example.com'), 'ABC123');
    expect(await store.read('api.example.com'), isNull);
  });
}

class _FakeAffiliateReferralRepository extends AffiliateReferralRepository {
  _FakeAffiliateReferralRepository()
      : super(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://alpha.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
            AuthTokenStore(),
            localeTag: 'th-TH',
          ),
        );

  String clickedRefCode = '';
  String clickedVisitorId = '';
  String clickedLandingUrl = '';
  String appliedRefCode = '';
  String appliedVisitorId = '';
  bool appliedRegistered = false;
  int? applyErrorStatus;

  @override
  Future<void> trackClick({
    required String refCode,
    required String visitorId,
    required String landingUrl,
  }) async {
    clickedRefCode = refCode;
    clickedVisitorId = visitorId;
    clickedLandingUrl = landingUrl;
  }

  @override
  Future<void> apply({
    required String refCode,
    required String visitorId,
    bool registered = false,
  }) async {
    if (applyErrorStatus != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/customer/affiliate/referrals'),
        response: Response(
          requestOptions: RequestOptions(path: '/customer/affiliate/referrals'),
          statusCode: applyErrorStatus,
        ),
      );
    }
    appliedRefCode = refCode;
    appliedVisitorId = visitorId;
    appliedRegistered = registered;
  }
}

class _MemoryAffiliateReferralStore extends AffiliateReferralStore {
  final _values = <String, String>{};

  @override
  Future<void> save(String hostScope, String refCode) async {
    final normalized = normalizeAffiliateRefCode(refCode);
    if (normalized != null) {
      _values[normalizePublicVisitHostScope(hostScope)] = normalized;
    }
  }

  @override
  Future<String?> read(String hostScope) async {
    return _values[normalizePublicVisitHostScope(hostScope)];
  }

  @override
  Future<void> clear(String hostScope) async {
    _values.remove(normalizePublicVisitHostScope(hostScope));
  }
}

class _FixedPublicVisitIdStore extends PublicVisitIdStore {
  _FixedPublicVisitIdStore(this.id);

  final String id;

  @override
  Future<String> visitorId(String hostScope) async => id;
}
