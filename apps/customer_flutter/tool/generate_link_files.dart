import 'dart:io';

import 'src/deep_link_association_files.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options.flag('help')) {
    _printUsage();
    return;
  }

  final outputDir = Directory(
    options.value('output-dir') ??
        Platform.environment['CUSTOMER_FLUTTER_LINK_OUTPUT_DIR'] ??
        'build/link-association',
  );
  final androidPackage = options.value('android-package') ??
      Platform.environment['CUSTOMER_FLUTTER_APPLICATION_ID'];
  final fingerprints = options.values('sha256-fingerprint').isEmpty
      ? _splitCsv(Platform.environment['CUSTOMER_FLUTTER_SHA256_FINGERPRINTS'])
      : options.values('sha256-fingerprint').expand(_splitCsv).toList();
  final iosTeamId = options.value('ios-team-id') ??
      Platform.environment['CUSTOMER_FLUTTER_IOS_TEAM_ID'];
  final iosBundleId = options.value('ios-bundle-id') ??
      Platform.environment['CUSTOMER_FLUTTER_IOS_BUNDLE_ID'];
  final paths = options.values('path').isEmpty
      ? defaultCustomerDeepLinkPaths
      : options.values('path');

  final wellKnownDir = Directory('${outputDir.path}/.well-known');
  await wellKnownDir.create(recursive: true);

  if (androidPackage != null && fingerprints.isNotEmpty) {
    final assetLinks = buildAndroidAssetLinks(
      packageName: androidPackage,
      sha256Fingerprints: fingerprints,
    );
    final file = File('${wellKnownDir.path}/assetlinks.json');
    await file.writeAsString(prettyJson(assetLinks));
    stdout.writeln('Wrote ${file.path}');
  } else {
    stdout.writeln(
      'Skipped Android assetlinks.json: provide --android-package and '
      '--sha256-fingerprint.',
    );
  }

  if (iosTeamId != null && iosBundleId != null) {
    final association = buildAppleAppSiteAssociation(
      teamId: iosTeamId,
      bundleId: iosBundleId,
      paths: paths,
    );
    final file = File('${wellKnownDir.path}/apple-app-site-association');
    await file.writeAsString(prettyJson(association));
    stdout.writeln('Wrote ${file.path}');
  } else {
    stdout.writeln(
      'Skipped Apple app site association: provide --ios-team-id and '
      '--ios-bundle-id.',
    );
  }
}

_Options _parseArgs(List<String> args) {
  final values = <String, List<String>>{};
  final flags = <String>{};

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (!arg.startsWith('--')) continue;

    final body = arg.substring(2);
    if (body.contains('=')) {
      final parts = body.split('=');
      final key = parts.first;
      final value = parts.sublist(1).join('=');
      values.putIfAbsent(key, () => []).add(value);
      continue;
    }

    final next = index + 1 < args.length ? args[index + 1] : null;
    if (next != null && !next.startsWith('--')) {
      values.putIfAbsent(body, () => []).add(next);
      index++;
    } else {
      flags.add(body);
    }
  }

  return _Options(values, flags);
}

List<String> _splitCsv(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

void _printUsage() {
  stdout.writeln('''
Generate Android and iOS domain association files for customer_flutter.

Usage:
  dart run tool/generate_link_files.dart \\
    --output-dir build/link-association \\
    --android-package com.partner.customer \\
    --sha256-fingerprint AA:BB:CC:... \\
    --ios-team-id ABCDE12345 \\
    --ios-bundle-id com.partner.customer

Environment alternatives:
  CUSTOMER_FLUTTER_LINK_OUTPUT_DIR
  CUSTOMER_FLUTTER_APPLICATION_ID
  CUSTOMER_FLUTTER_SHA256_FINGERPRINTS
  CUSTOMER_FLUTTER_IOS_TEAM_ID
  CUSTOMER_FLUTTER_IOS_BUNDLE_ID
''');
}

class _Options {
  const _Options(this._values, this._flags);

  final Map<String, List<String>> _values;
  final Set<String> _flags;

  bool flag(String key) => _flags.contains(key);

  String? value(String key) => _values[key]?.last;

  List<String> values(String key) => _values[key] ?? const [];
}
