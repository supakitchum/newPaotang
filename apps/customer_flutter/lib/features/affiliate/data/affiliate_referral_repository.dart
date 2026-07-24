import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/navigation/web_runtime.dart';
import '../../../core/network/api_client.dart';
import '../../../core/tenant/customer_tenant_host.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../monitoring/data/public_visit_id_store.dart';

final affiliateReferralRepositoryProvider =
    Provider<AffiliateReferralRepository>((ref) {
      return AffiliateReferralRepository(ref.watch(apiClientProvider));
    });

final affiliateReferralStoreProvider = Provider<AffiliateReferralStore>((ref) {
  return AffiliateReferralStore();
});

final affiliateReferralServiceProvider = Provider<AffiliateReferralService>((
  ref,
) {
  final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
  return AffiliateReferralService(
    config: ref.watch(appConfigProvider),
    repository: ref.watch(affiliateReferralRepositoryProvider),
    store: ref.watch(affiliateReferralStoreProvider),
    visitIdStore: ref.watch(publicVisitIdStoreProvider),
    runtimeTenantHost: bootstrap?.tenantHost ?? '',
    runtimeCanonicalUrl: bootstrap?.canonicalUrl ?? '',
  );
});

const affiliateReferralTtl = Duration(days: 30);

class AffiliateReferralRepository {
  const AffiliateReferralRepository(this._api);

  final ApiClient _api;

  Future<void> trackClick({
    required String refCode,
    required String visitorId,
    required String landingUrl,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/public/affiliate/referrals/click',
      data: {
        'ref': refCode,
        'visitor_id': visitorId,
        'landing_url': landingUrl,
      },
    );
  }

  Future<void> apply({
    required String refCode,
    required String visitorId,
    bool registered = false,
  }) async {
    await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/affiliate/referrals/apply',
      data: {'ref': refCode, 'visitor_id': visitorId, 'registered': registered},
      headers: {
        'Idempotency-Key': newIdempotencyKey('affiliate_referral_apply'),
      },
    );
  }
}

class AffiliateReferralStore {
  AffiliateReferralStore({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(migrateWithBackup: true),
           ),
       _clock = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Map<String, _StoredReferral> _memory = {};

  Future<void> save(String hostScope, String refCode) async {
    final scope = normalizePublicVisitHostScope(hostScope);
    final normalized = normalizeAffiliateRefCode(refCode);
    if (normalized == null) return;
    final item = _StoredReferral(
      refCode: normalized,
      expiresAt: _clock().add(affiliateReferralTtl),
    );
    _memory[scope] = item;
    await _write(scope, item);
  }

  Future<String?> read(String hostScope) async {
    final scope = normalizePublicVisitHostScope(hostScope);
    final memory = _memory[scope];
    if (memory != null) return _validOrNull(scope, memory);

    try {
      final raw = await _storage.read(key: _key(scope));
      final item = _StoredReferral.parse(raw);
      if (item == null) return null;
      _memory[scope] = item;
      return _validOrNull(scope, item);
    } catch (_) {
      return _validOrNull(scope, _memory[scope]);
    }
  }

  Future<void> clear(String hostScope) async {
    final scope = normalizePublicVisitHostScope(hostScope);
    _memory.remove(scope);
    try {
      await _storage.delete(key: _key(scope));
    } catch (_) {
      // Local storage cleanup should not interrupt customer journeys.
    }
  }

  Future<void> _write(String scope, _StoredReferral item) async {
    try {
      await _storage.write(key: _key(scope), value: item.serialize());
    } catch (_) {
      // Keep the in-memory copy when secure storage is unavailable.
    }
  }

  String? _validOrNull(String scope, _StoredReferral? item) {
    if (item == null) return null;
    if (item.expiresAt.isBefore(_clock())) {
      _memory.remove(scope);
      return null;
    }
    return item.refCode;
  }

  String _key(String scope) => 'affiliate_ref_$scope';
}

class AffiliateReferralService {
  AffiliateReferralService({
    required AppConfig config,
    required AffiliateReferralRepository repository,
    required AffiliateReferralStore store,
    required PublicVisitIdStore visitIdStore,
    String runtimeTenantHost = '',
    String runtimeCanonicalUrl = '',
    String Function()? webHost,
    String Function()? webHref,
  }) : _config = config,
       _repository = repository,
       _store = store,
       _visitIdStore = visitIdStore,
       _runtimeTenantHost = runtimeTenantHost,
       _runtimeCanonicalUrl = runtimeCanonicalUrl,
       _webHost = webHost ?? (() => currentWebHost),
       _webHref = webHref ?? (() => currentWebHref);

  final AppConfig _config;
  final AffiliateReferralRepository _repository;
  final AffiliateReferralStore _store;
  final PublicVisitIdStore _visitIdStore;
  final String _runtimeTenantHost;
  final String _runtimeCanonicalUrl;
  final String Function() _webHost;
  final String Function() _webHref;

  Future<String?> captureFromLocation(String location) async {
    final refCode = extractAffiliateRefCode(location);
    if (refCode == null) return null;

    final scope = _hostScope();
    await _store.save(scope, refCode);

    try {
      await _repository.trackClick(
        refCode: refCode,
        visitorId: await _visitIdStore.visitorId(scope),
        landingUrl: _webHref().trim().isEmpty ? location : _webHref().trim(),
      );
    } catch (_) {
      // Tracking must never block navigation or registration.
    }

    return refCode;
  }

  Future<void> applyStored({bool registered = false}) async {
    final scope = _hostScope();
    final refCode = await _store.read(scope);
    if (refCode == null) {
      await _store.clear(scope);
      return;
    }

    try {
      await _repository.apply(
        refCode: refCode,
        visitorId: await _visitIdStore.visitorId(scope),
        registered: registered,
      );
    } catch (error) {
      final status = error is DioException ? error.response?.statusCode : null;
      if (status == 404 || status == 422) {
        await _store.clear(scope);
      }
    }
  }

  String _hostScope() {
    return normalizePublicVisitHostScope(
      resolveCustomerTenantHost(
        currentHost: _webHost(),
        configuredTenantHost: _config.normalizedTenantHost,
        runtimeTenantHost: _runtimeTenantHost,
        runtimeCanonicalUrl: _runtimeCanonicalUrl,
        apiBaseUrl: _config.apiBaseUrl,
      ),
    );
  }
}

String? extractAffiliateRefCode(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return null;
  for (final key in const ['ref', 'ref_code', 'affiliate']) {
    final value = normalizeAffiliateRefCode(uri.queryParameters[key]);
    if (value != null) return value;
  }
  return null;
}

String? normalizeAffiliateRefCode(String? value) {
  final ref = value?.trim() ?? '';
  return RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(ref) ? ref : null;
}

class _StoredReferral {
  const _StoredReferral({required this.refCode, required this.expiresAt});

  final String refCode;
  final DateTime expiresAt;

  String serialize() => '$refCode|${expiresAt.millisecondsSinceEpoch}';

  static _StoredReferral? parse(String? raw) {
    final parts = (raw ?? '').split('|');
    if (parts.length != 2) return null;
    final refCode = normalizeAffiliateRefCode(parts[0]);
    final expiresAtMs = int.tryParse(parts[1]);
    if (refCode == null || expiresAtMs == null) return null;
    return _StoredReferral(
      refCode: refCode,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
    );
  }
}
