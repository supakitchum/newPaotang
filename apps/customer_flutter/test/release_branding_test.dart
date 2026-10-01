import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../tool/src/release_branding.dart';

void main() {
  test('release branding validates partner image inputs', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_release_branding_input_',
    );
    try {
      final appIcon = File('${root.path}/app-icon.png')
        ..writeAsBytesSync(
          image.encodePng(image.Image(width: 1024, height: 1024)),
        );
      final adaptiveForeground = File('${root.path}/foreground.png')
        ..writeAsBytesSync(
          image.encodePng(image.Image(width: 512, height: 512)),
        );

      expect(
        () => validateReleaseBrandingRequest(
          ReleaseBrandingRequest(
            projectRoot: root,
            partnerId: 'partner-lottery',
            iconSource: appIcon,
            adaptiveForegroundSource: adaptiveForeground,
            adaptiveBackground: '#087FF0',
            themeColor: '#19B8EF',
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validateReleaseBrandingRequest(
          ReleaseBrandingRequest(
            projectRoot: root,
            partnerId: 'customer_flutter',
            iconSource: appIcon,
            adaptiveForegroundSource: adaptiveForeground,
            adaptiveBackground: '#087FF0',
            themeColor: '#19B8EF',
          ),
        ),
        throwsArgumentError,
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('release branding rejects undersized or non-square app icons', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_release_branding_size_',
    );
    try {
      final appIcon = File('${root.path}/app-icon.png')
        ..writeAsBytesSync(
          image.encodePng(image.Image(width: 1024, height: 900)),
        );
      final adaptiveForeground = File('${root.path}/foreground.png')
        ..writeAsBytesSync(
          image.encodePng(image.Image(width: 512, height: 512)),
        );

      expect(
        () => validateReleaseBrandingRequest(
          ReleaseBrandingRequest(
            projectRoot: root,
            partnerId: 'partner-lottery',
            iconSource: appIcon,
            adaptiveForegroundSource: adaptiveForeground,
            adaptiveBackground: '#087FF0',
            themeColor: '#087FF0',
          ),
        ),
        throwsArgumentError,
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('release branding manifest detects stale generated files', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_release_branding_manifest_',
    );
    try {
      final hashes = <String, String>{};
      for (final path in requiredReleaseBrandingPaths(
        includeAndroid: false,
        includeIos: false,
        includeWeb: true,
      )) {
        final file = _writeFile(root, path, 'generated:$path');
        hashes[path] = releaseBrandingFileSha256(file);
      }
      final manifest = _writeFile(
        root,
        defaultReleaseBrandingManifestPath,
        jsonEncode({
          'schema_version': releaseBrandingSchemaVersion,
          'partner_id': 'partner-lottery',
          'icon_source_sha256': List.filled(64, 'a').join(),
          'adaptive_foreground_sha256': List.filled(64, 'b').join(),
          'adaptive_background': '#087FF0',
          'theme_color': '#087FF0',
          'files': hashes,
        }),
      );

      final valid = verifyReleaseBrandingManifest(
        projectRoot: root,
        manifest: manifest,
        includeAndroid: false,
        includeIos: false,
        includeWeb: true,
      );
      expect(valid.issues, isEmpty);

      _writeFile(root, 'web/icons/Icon-512.png', 'changed');
      final stale = verifyReleaseBrandingManifest(
        projectRoot: root,
        manifest: manifest,
        includeAndroid: false,
        includeIos: false,
        includeWeb: true,
      );
      expect(
        stale.issues,
        contains(
          'branding file changed after generation: web/icons/Icon-512.png',
        ),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}

File _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  return file;
}
