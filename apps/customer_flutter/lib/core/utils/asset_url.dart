import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../tenant/mobile_bootstrap_controller.dart';

final assetUrlResolverProvider = Provider<AssetUrlResolver>((ref) {
  final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
  return AssetUrlResolver(
    ref.watch(appConfigProvider),
    assetCdnBaseUrl: bootstrap?.assetCdnBaseUrl ?? '',
  );
});

class AssetUrlResolver {
  const AssetUrlResolver(
    this._config, {
    this.assetCdnBaseUrl = '',
  });

  final AppConfig _config;
  final String assetCdnBaseUrl;

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

    final base = _assetBase();
    if (base == null) return trimmed;

    final normalizedPath = _normalizedAssetPath(trimmed);
    return base.resolve(normalizedPath).toString();
  }

  Uri? _assetBase() {
    final origin = _assetOrigin();
    final configured = assetCdnBaseUrl.trim();
    if (configured.isEmpty) return origin;

    final configuredUri = Uri.tryParse(configured);
    if (configuredUri == null) return origin;
    if (configuredUri.hasScheme && configuredUri.host.isNotEmpty) {
      return _directoryUri(configuredUri);
    }
    if (origin == null) return null;
    return _directoryUri(origin.resolve(configuredUri.toString()));
  }

  Uri? _assetOrigin() {
    final apiBase = Uri.tryParse(_config.apiBaseUrl.trim());
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

  String _normalizedAssetPath(String value) {
    final hadLeadingSlash = value.startsWith('/');
    final path = value.replaceFirst(RegExp(r'^/+'), '');
    if (path.isEmpty) return '';

    if (hadLeadingSlash || _isRootedAssetPath(path)) {
      return path;
    }
    return 'upload/$path';
  }

  bool _isRootedAssetPath(String path) {
    final firstSegment = path.split('/').first.toLowerCase();
    return const {
      'api',
      'assets',
      'public',
      'storage',
      'upload',
    }.contains(firstSegment);
  }

  Uri _directoryUri(Uri uri) {
    final value = uri.toString();
    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }
}
