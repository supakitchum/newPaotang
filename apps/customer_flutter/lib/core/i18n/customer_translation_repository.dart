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
    FutureProvider<CustomerTranslationBundle>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (!customerTranslationRuntimeFetchAllowed(config.apiBaseUrl)) {
    return const CustomerTranslationBundle();
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

final customerSupportedLocaleOptionsProvider =
    Provider<List<CustomerLocaleOption>>((ref) {
  final bundle = ref.watch(customerTranslationBundleProvider).valueOrNull;
  return effectiveCustomerLocaleOptions(
    bundle?.availableLocales ?? const <CustomerLocaleOption>[],
  );
});

class CustomerTranslationBundle {
  const CustomerTranslationBundle({
    this.locale = '',
    this.messages = const <String, String>{},
    this.availableLocales = const <CustomerLocaleOption>[],
  });

  final String locale;
  final Map<String, String> messages;
  final List<CustomerLocaleOption> availableLocales;
}

class CustomerTranslationRepository {
  const CustomerTranslationRepository(this._api);

  final ApiClient _api;

  Future<CustomerTranslationBundle> bundle({
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

    return parseCustomerTranslationBundle(response.data);
  }
}

Map<String, String> parseCustomerTranslationMessages(Object? data) {
  return parseCustomerTranslationBundle(data).messages;
}

CustomerTranslationBundle parseCustomerTranslationBundle(Object? data) {
  final root = _asMap(data);
  final payload = _asMap(root['data']).isNotEmpty ? _asMap(root['data']) : root;
  final messages = _asMap(payload['messages']);
  final locale = _string(payload['locale']).isNotEmpty
      ? _string(payload['locale'])
      : _string(root['locale']);
  final rawLocales = payload['available_locales'] ??
      payload['availableLocales'] ??
      root['available_locales'] ??
      root['availableLocales'];
  final availableLocales = _parseAvailableLocales(rawLocales);

  return CustomerTranslationBundle(
    locale: locale,
    messages: {
      for (final entry in messages.entries)
        if (entry.key.trim().isNotEmpty && entry.value != null)
          entry.key.trim(): entry.value.toString(),
    },
    availableLocales: availableLocales,
  );
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

List<CustomerLocaleOption> _parseAvailableLocales(Object? value) {
  if (value is! Iterable) return const <CustomerLocaleOption>[];

  final options = <CustomerLocaleOption>[];
  for (final item in value) {
    final row = _asMap(item);
    final locale = tryParseCustomerLocale(_string(row['locale']));
    if (locale == null) continue;
    final status = _string(row['status']).toLowerCase();
    if (status.isNotEmpty && status != 'active') continue;
    options.add(
      CustomerLocaleOption(
        locale: locale,
        name: _string(row['name']),
        nativeName: _string(row['native_name'] ?? row['nativeName']),
        isDefault: _asBool(row['is_default'] ?? row['isDefault']),
        sortOrder: int.tryParse(
              _string(row['sort_order'] ?? row['sortOrder']),
            ) ??
            100,
      ),
    );
  }
  return effectiveCustomerLocaleOptions(options);
}

String _string(Object? value) {
  if (value == null || value is Map || value is Iterable) return '';
  return value.toString().trim();
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {'1', 'true', 'yes', 'on'}.contains(
    _string(value).toLowerCase(),
  );
}
