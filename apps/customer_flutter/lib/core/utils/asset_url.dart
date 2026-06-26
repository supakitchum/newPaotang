import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final assetUrlResolverProvider = Provider<AssetUrlResolver>((ref) {
  return AssetUrlResolver(ref.watch(appConfigProvider));
});

class AssetUrlResolver {
  const AssetUrlResolver(this._config);

  final AppConfig _config;

  String call(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.hasScheme ||
            trimmed.startsWith('data:') ||
            trimmed.startsWith('//'))) {
      return trimmed;
    }

    final apiBase = Uri.tryParse(_config.apiBaseUrl.trim());
    final origin = _assetOrigin(apiBase);
    if (origin == null) return trimmed;

    final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return origin.resolve(normalizedPath).toString();
  }

  Uri? _assetOrigin(Uri? apiBase) {
    if (apiBase != null && apiBase.hasScheme && apiBase.host.isNotEmpty) {
      return Uri(
        scheme: apiBase.scheme,
        host: apiBase.host,
        port: apiBase.hasPort ? apiBase.port : null,
      );
    }

    final current = Uri.base;
    if (current.hasScheme &&
        (current.scheme == 'http' || current.scheme == 'https') &&
        current.host.isNotEmpty) {
      return Uri(
        scheme: current.scheme,
        host: current.host,
        port: current.hasPort ? current.port : null,
      );
    }

    return null;
  }
}
