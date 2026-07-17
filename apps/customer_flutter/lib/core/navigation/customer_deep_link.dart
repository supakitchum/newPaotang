import '../../app/customer_routes.dart';
import '../tenant/customer_tenant_host.dart';

String? customerDeepLinkPath(
  Uri uri, {
  Iterable<String> allowedHosts = const [],
}) {
  final normalized = _normalizeUriPath(uri, allowedHosts: allowedHosts);
  if (normalized == null) return null;

  if (_isAllowedPath(normalized.path)) {
    return normalized.toString();
  }

  return null;
}

Uri? _normalizeUriPath(Uri uri, {required Iterable<String> allowedHosts}) {
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    if (!_isAllowedHost(uri.host, allowedHosts)) return null;
    final fragmentRoutePath = _fragmentRoutePath(uri.fragment);
    final routePath = fragmentRoutePath ?? uri.path;
    return Uri(
      path: routePath,
      queryParameters: _routeQueryOrNull(uri, routePath),
    );
  }

  final host = uri.host.trim().toLowerCase();
  final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  final fragmentRoutePath = _fragmentRoutePath(uri.fragment);
  if (fragmentRoutePath != null) {
    return Uri(
      path: fragmentRoutePath,
      queryParameters: _routeQueryOrNull(uri, fragmentRoutePath),
    );
  }
  final appRoutePath = _customSchemeRoutePath(host: host, path: path);

  if (host == 'line' && path == '/callback') {
    return Uri(
      path: '/line/callback',
      queryParameters: _routeQueryOrNull(uri, '/line/callback'),
    );
  }

  if (host == 'social') {
    final routePath = '/social$path';
    return Uri(
      path: routePath,
      queryParameters: _routeQueryOrNull(uri, routePath),
    );
  }

  if (host == 'reset-password') {
    return Uri(
      path: '/reset-password',
      queryParameters: _routeQueryOrNull(uri, '/reset-password'),
    );
  }

  if (appRoutePath != null) {
    return Uri(
      path: appRoutePath,
      queryParameters: _routeQueryOrNull(uri, appRoutePath),
    );
  }

  return null;
}

Set<String> customerDeepLinkAllowedHosts({
  required String tenantHost,
  required String apiBaseUrl,
  String runtimeTenantHost = '',
  String runtimeCanonicalUrl = '',
}) {
  final tenantHosts = {
    normalizeCustomerTenantHost(tenantHost),
    normalizeCustomerTenantHost(runtimeTenantHost),
    normalizeCustomerTenantHost(runtimeCanonicalUrl),
  }..removeWhere((host) => host.isEmpty);
  if (tenantHosts.isNotEmpty) return tenantHosts;

  final apiHost = normalizeCustomerTenantHost(apiBaseUrl);
  return apiHost.isEmpty ? const {} : {apiHost};
}

bool _isAllowedHost(String host, Iterable<String> allowedHosts) {
  final normalizedHost = normalizeCustomerTenantHost(host);
  final normalizedAllowed = allowedHosts
      .map(normalizeCustomerTenantHost)
      .toSet()
    ..removeWhere((allowedHost) => allowedHost.isEmpty);
  return normalizedAllowed.isEmpty ||
      normalizedAllowed.contains(normalizedHost);
}

String? _customSchemeRoutePath({required String host, required String path}) {
  if (host.isEmpty) return path;
  if (path == '/') return '/$host';
  return '/$host$path';
}

Map<String, String> customerAuthRouteParameters(Uri uri) {
  final parameters = <String, String>{...uri.queryParameters};
  final fragmentParameters = _fragmentQueryParameters(uri.fragment);
  for (final entry in fragmentParameters.entries) {
    parameters.putIfAbsent(entry.key, () => entry.value);
  }
  return parameters;
}

Map<String, String>? _routeQueryOrNull(Uri uri, String path) {
  final parameters = _acceptsFragmentParameters(path)
      ? customerAuthRouteParameters(uri)
      : uri.queryParameters;
  return parameters.isEmpty ? null : parameters;
}

bool _acceptsFragmentParameters(String path) {
  if (path == '/line/callback' ||
      path == '/line/link-phone' ||
      path == '/reset-password') {
    return true;
  }
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  return parts.length == 3 &&
      parts.first == 'social' &&
      (parts.last == 'callback' || parts.last == 'link-phone');
}

Map<String, String> _fragmentQueryParameters(
  String value, [
  int depth = 0,
]) {
  if (depth >= 5) return const {};
  var fragment = value.trim();
  if (fragment.isEmpty) return const {};
  while (fragment.startsWith('#') || fragment.startsWith('!')) {
    fragment = fragment.substring(1).trim();
  }
  if (fragment.isEmpty) return const {};

  final parsed = Uri.tryParse(fragment);
  if (parsed != null) {
    if (parsed.queryParameters.isNotEmpty) {
      return parsed.queryParameters;
    }
    if (parsed.hasScheme && parsed.fragment.isNotEmpty) {
      return _fragmentQueryParameters(parsed.fragment, depth + 1);
    }
  }

  var query = fragment;
  final queryIndex = query.indexOf('?');
  if (queryIndex >= 0) query = query.substring(queryIndex + 1);
  if (query.startsWith('?')) query = query.substring(1);
  if (query.contains('=')) {
    try {
      return Uri.splitQueryString(query);
    } on FormatException {
      return const {};
    }
  }

  final decoded = _decodeFragmentValue(fragment);
  if (decoded == fragment) return const {};
  return _fragmentQueryParameters(decoded, depth + 1);
}

String? _fragmentRoutePath(String value, [int depth = 0]) {
  if (depth >= 5) return null;
  var fragment = value.trim();
  if (fragment.isEmpty) return null;
  while (fragment.startsWith('#') || fragment.startsWith('!')) {
    fragment = fragment.substring(1).trim();
  }
  if (fragment.isEmpty) return null;

  final parsed = Uri.tryParse(fragment);
  if (parsed != null) {
    if (parsed.hasScheme && parsed.path.startsWith('/')) {
      return parsed.path;
    }
    if (fragment.startsWith('/') && parsed.path.startsWith('/')) {
      return parsed.path;
    }
  }

  final decoded = _decodeFragmentValue(fragment);
  if (decoded == fragment) return null;
  return _fragmentRoutePath(decoded, depth + 1);
}

String _decodeFragmentValue(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  }
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
