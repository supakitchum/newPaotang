import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/src/deep_link_association_files.dart';

void main() {
  test('buildAndroidAssetLinks creates Android app link relation', () {
    final json = buildAndroidAssetLinks(
      packageName: 'com.partner.customer',
      sha256Fingerprints: ['AA:BB:CC', 'DD:EE:FF'],
    ) as List<Object?>;

    final item = json.single as Map<String, Object?>;
    final target = item['target']! as Map<String, Object?>;

    expect(item['relation'], ['delegate_permission/common.handle_all_urls']);
    expect(target['namespace'], 'android_app');
    expect(target['package_name'], 'com.partner.customer');
    expect(target['sha256_cert_fingerprints'], ['AA:BB:CC', 'DD:EE:FF']);
  });

  test('buildAppleAppSiteAssociation creates callback app IDs and paths', () {
    final json = buildAppleAppSiteAssociation(
      teamId: 'ABCDE12345',
      bundleId: 'com.partner.customer',
    ) as Map<String, Object?>;

    final applinks = json['applinks']! as Map<String, Object?>;
    final details = applinks['details']! as List<Object?>;
    final detail = details.single! as Map<String, Object?>;

    expect(applinks['apps'], isEmpty);
    expect(detail['appIDs'], ['ABCDE12345.com.partner.customer']);
    expect(detail['paths'], contains('/line/callback'));
    expect(detail['paths'], contains('/social/*'));
    expect(detail['paths'], contains('/reset-password'));
    expect(detail['paths'], contains('/checkout/pending'));
  });

  test('prettyJson emits parseable JSON with trailing newline', () {
    final encoded = prettyJson({'ok': true});

    expect(jsonDecode(encoded), {'ok': true});
    expect(encoded.endsWith('\n'), isTrue);
  });
}
