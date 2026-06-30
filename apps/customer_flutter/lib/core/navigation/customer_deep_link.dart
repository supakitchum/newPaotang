import '../../app/customer_routes.dart';

String? customerDeepLinkPath(Uri uri) {
  final normalized = _normalizeUriPath(uri);
  if (normalized == null) return null;

  if (_isAllowedPath(normalized.path)) {
    return normalized.toString();
  }

  return null;
}

Uri? _normalizeUriPath(Uri uri) {
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return Uri(path: uri.path, queryParameters: _queryOrNull(uri));
  }

  final host = uri.host.trim().toLowerCase();
  final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  final appRoutePath = _customSchemeRoutePath(host: host, path: path);

  if (host == 'line' && path == '/callback') {
    return Uri(path: '/line/callback', queryParameters: _queryOrNull(uri));
  }

  if (host == 'social') {
    return Uri(path: '/social$path', queryParameters: _queryOrNull(uri));
  }

  if (host == 'reset-password') {
    return Uri(path: '/reset-password', queryParameters: _queryOrNull(uri));
  }

  if (appRoutePath != null) {
    return Uri(path: appRoutePath, queryParameters: _queryOrNull(uri));
  }

  return null;
}

String? _customSchemeRoutePath({required String host, required String path}) {
  if (host.isEmpty) return path;
  if (path == '/') return '/$host';
  return '/$host$path';
}

Map<String, String>? _queryOrNull(Uri uri) {
  return uri.queryParameters.isEmpty ? null : uri.queryParameters;
}

bool _isAllowedPath(String path) {
  return customerFeatureRoutes.any((route) => _matchesRoute(route.path, path));
}

bool _matchesRoute(String pattern, String path) {
  if (pattern == path) return true;

  final patternParts =
      pattern.split('/').where((part) => part.isNotEmpty).toList();
  final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();

  if (patternParts.length != pathParts.length) return false;

  for (var index = 0; index < patternParts.length; index++) {
    final patternPart = patternParts[index];
    if (patternPart.startsWith(':')) continue;
    if (patternPart != pathParts[index]) return false;
  }

  return true;
}
