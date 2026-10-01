String normalizeCustomerTenantHost(String value) {
  final trimmed = value.trim().toLowerCase();
  if (trimmed.isEmpty) return '';

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.host.toLowerCase();
  }

  return trimmed.split('/').first.split(':').first.toLowerCase();
}

String resolveCustomerTenantHost({
  String currentHost = '',
  String configuredTenantHost = '',
  String runtimeTenantHost = '',
  String runtimeCanonicalUrl = '',
  String apiBaseUrl = '',
}) {
  for (final candidate in [
    currentHost,
    configuredTenantHost,
    runtimeTenantHost,
    runtimeCanonicalUrl,
    apiBaseUrl,
  ]) {
    final host = normalizeCustomerTenantHost(candidate);
    if (host.isNotEmpty) return host;
  }
  return '';
}

String customerTenantStorageScope(String value) {
  final host = normalizeCustomerTenantHost(value);
  if (host.isEmpty) return '';
  return host
      .replaceAll(RegExp(r'[^a-z0-9.-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[_\-.]+|[_\-.]+$'), '');
}
