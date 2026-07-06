import 'dart:convert';

const defaultCustomerDeepLinkPaths = <String>[
  '/line/callback',
  '/social/*',
  '/reset-password',
  '/checkout/pending',
];

Object buildAndroidAssetLinks({
  required String packageName,
  required List<String> sha256Fingerprints,
}) {
  final fingerprints = sha256Fingerprints
      .map((fingerprint) => fingerprint.trim())
      .where((fingerprint) => fingerprint.isNotEmpty)
      .toList();

  if (packageName.trim().isEmpty) {
    throw ArgumentError.value(packageName, 'packageName', 'must not be empty');
  }
  if (fingerprints.isEmpty) {
    throw ArgumentError.value(
      sha256Fingerprints,
      'sha256Fingerprints',
      'must include at least one SHA-256 certificate fingerprint',
    );
  }

  return [
    {
      'relation': ['delegate_permission/common.handle_all_urls'],
      'target': {
        'namespace': 'android_app',
        'package_name': packageName.trim(),
        'sha256_cert_fingerprints': fingerprints,
      },
    },
  ];
}

Object buildAppleAppSiteAssociation({
  required String teamId,
  required String bundleId,
  List<String> paths = defaultCustomerDeepLinkPaths,
}) {
  final appId = '${teamId.trim()}.${bundleId.trim()}';
  final normalizedPaths = paths
      .map((path) => path.trim())
      .where((path) => path.startsWith('/'))
      .toSet()
      .toList();

  if (teamId.trim().isEmpty) {
    throw ArgumentError.value(teamId, 'teamId', 'must not be empty');
  }
  if (bundleId.trim().isEmpty) {
    throw ArgumentError.value(bundleId, 'bundleId', 'must not be empty');
  }
  if (normalizedPaths.isEmpty) {
    throw ArgumentError.value(paths, 'paths', 'must include at least one path');
  }

  return {
    'applinks': {
      'apps': <String>[],
      'details': [
        {
          'appIDs': [appId],
          'paths': normalizedPaths,
          'components': [
            for (final path in normalizedPaths)
              {
                '/': path,
                'comment': 'Customer Flutter deep link route',
              },
          ],
        },
      ],
    },
  };
}

String prettyJson(Object value) {
  return '${const JsonEncoder.withIndent('  ').convert(value)}\n';
}
