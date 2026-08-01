import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter customer API surface covers Nuxt customer API endpoints', () {
    final nuxtEndpoints = _extractEndpoints(
      Directory('../customer'),
      extensions: const {'.vue', '.ts', '.js'},
    );
    final flutterEndpoints = _extractEndpoints(
      Directory('lib'),
      extensions: const {'.dart'},
    );

    final missing = <String>[];
    for (final endpoint in nuxtEndpoints) {
      final replacements = _intentionalReplacements[endpoint];
      if (replacements != null) {
        final covered = replacements.any(
          (replacement) => _hasEndpoint(replacement, flutterEndpoints),
        );
        if (!covered) {
          missing.add(
            '$endpoint -> expected one of ${replacements.join(', ')}',
          );
        }
        continue;
      }

      if (!_hasEndpoint(endpoint, flutterEndpoints)) {
        missing.add(endpoint);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: [
        'Every customer/public API endpoint used by the Nuxt customer app',
        'should be used by Flutter or mapped to an intentional replacement.',
        ...missing,
      ].join('\n'),
    );
  });

  test('customer API integration map matches Flutter production routing', () {
    final map = File(
      '../../docs/customer-api-integration-map.md',
    ).readAsStringSync();

    expect(
      map,
      contains('GET /public/stock/search?store_id=...&mode=random'),
      reason:
          'Customer store stock must stay randomized; ordered browse mode should not be documented as the Flutter target.',
    );
    expect(
      map,
      isNot(contains('GET /public/stock/search?store_id=...&mode=browse')),
    );
    expect(
      map,
      contains('/customer/auth/social/{provider}/login'),
      reason:
          'Flutter uses the generic store-compliant social login flow for LINE, Google, Apple, and Facebook.',
    );
    expect(map, contains('/customer/auth/social/{provider}/link-phone'));
    expect(map, contains('/customer/auth/social/accounts'));
    expect(map, contains('/customer/auth/social/accounts/{provider}'));
    expect(map, contains('/public/mobile/bootstrap'));
    expect(map, contains('/customer/auth/biometric/challenge'));
    expect(map, contains('/customer/auth/biometric/verify'));
    expect(map, contains('/customer/auth/passkeys/login/options'));
    expect(map, contains('/customer/auth/passkeys/login/verify'));
    expect(map, contains('/customer/auth/passkeys/register/options'));
    expect(map, contains('/customer/auth/passkeys/{passkey_id}'));
  });
}

const _intentionalReplacements = <String, List<String>>{
  '/customer/auth/line': ['/customer/auth/social/'],
  '/customer/auth/line/callback': ['/customer/auth/social/'],
  '/customer/auth/line/link-phone': ['/customer/auth/social/'],
  '/customer/auth/line/login': ['/customer/auth/social/'],
  '/customer/auth/me': ['/customer/profile'],
  '/customer/auth/password/forgot': [
    '/customer/auth/otp/request',
    '/customer/auth/social/',
  ],
  '/customer/auth/pin': ['/customer/auth/pin/status'],
  '/customer/auth/pin/change': ['/customer/auth/pin/setup'],
  '/customer/auth/pin/reset': ['/customer/auth/pin/reset/request-otp'],
  '/customer/auth/pin/reset/verify-password': [
    '/customer/auth/pin/reset/verify-otp',
  ],
  '/public/site-config': ['/public/mobile/bootstrap'],
};

Set<String> _extractEndpoints(
  Directory root, {
  required Set<String> extensions,
}) {
  if (!root.existsSync()) return const {};

  final endpoints = <String>{};
  final endpointPattern = RegExp(
    r"""['"](/(?:api/v1/)?(?:customer|public)[^'"\s?#)]*)""",
  );
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => extensions.any(file.path.endsWith));

  for (final file in files) {
    final source = file.readAsStringSync();
    for (final match in endpointPattern.allMatches(source)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final normalized = _normalizeEndpoint(raw);
      if (normalized.isNotEmpty) endpoints.add(normalized);
    }
  }

  return endpoints;
}

String _normalizeEndpoint(String value) {
  var endpoint = value.trim().replaceFirst(RegExp(r'^/api/v1'), '');
  endpoint = endpoint
      .replaceAll(RegExp(r'\$\{[^}]+\}'), ':param')
      .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), ':param');
  endpoint = endpoint.replaceFirst(RegExp(r'/+$'), '');
  return endpoint.isEmpty ? '/' : endpoint;
}

bool _hasEndpoint(String expected, Set<String> actual) {
  final normalized = _normalizeEndpoint(expected);
  if (actual.contains(normalized)) return true;

  if (normalized.endsWith('/')) {
    return actual.any((endpoint) => endpoint.startsWith(normalized));
  }

  return actual.any((endpoint) => endpoint.startsWith('$normalized/'));
}
