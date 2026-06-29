import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../navigation/web_runtime.dart' as web_runtime;
import '../network/api_client.dart';
import 'app_locale.dart';
import 'customer_locale_controller.dart';

final customerTranslationRepositoryProvider =
    Provider<CustomerTranslationRepository>((ref) {
  return CustomerTranslationRepository(ref.watch(apiClientProvider));
});

final customerTranslationBundleProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!customerTranslationRuntimeFetchAllowed(config.apiBaseUrl)) {
    return const <String, String>{};
  }

  final locale = ref.watch(customerLocaleProvider);
  final repository = ref.watch(customerTranslationRepositoryProvider);
  final previewToken = translationPreviewTokenFromLocation(
    web_runtime.currentWebHref,
  );

  return repository.bundle(
    locale: localeTag(locale),
    previewToken: previewToken,
  );
});

class CustomerTranslationRepository {
  const CustomerTranslationRepository(this._api);

  final ApiClient _api;

  Future<Map<String, String>> bundle({
    required String locale,
    String previewToken = '',
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/translations',
      auth: false,
      query: {
        'locale': locale,
        'surface': 'customer',
        if (previewToken.trim().isNotEmpty)
          'preview_token': previewToken.trim(),
      },
    );

    return parseCustomerTranslationMessages(response.data);
  }
}

Map<String, String> parseCustomerTranslationMessages(Object? data) {
  final root = _asMap(data);
  final payload = _asMap(root['data']).isNotEmpty ? _asMap(root['data']) : root;
  final messages = _asMap(payload['messages']);

  return {
    for (final entry in messages.entries)
      if (entry.key.trim().isNotEmpty && entry.value != null)
        entry.key.trim(): entry.value.toString(),
  };
}

String translationPreviewTokenFromLocation(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return '';

  for (final key in const [
    'preview_token',
    'translation_preview',
    'translation_preview_token',
  ]) {
    final value = uri.queryParameters[key]?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }

  return '';
}

bool customerTranslationRuntimeFetchAllowed(
  String apiBaseUrl, {
  bool isWeb = kIsWeb,
}) {
  final value = apiBaseUrl.trim();
  if (value.isEmpty) return false;
  if (value.startsWith('/')) return isWeb;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return false;
  }

  final host = uri.host.trim().toLowerCase();
  final exampleDomain = '${'example'}.com';
  return host != exampleDomain && !host.endsWith('.$exampleDomain');
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
