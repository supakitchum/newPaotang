import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

const int releaseBrandingSchemaVersion = 1;
const String defaultReleaseBrandingManifestPath = 'release/branding.json';

const Set<String> _knownFlutterIconHashes = {
  '7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926',
  'baccb205ae45f0b421be1657259b4943ac40c95094ab877f3bcbe12cd544dcbe',
  '3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180',
};

const Set<String> _genericPartnerIds = {
  'customer',
  'customerflutter',
  'flutter',
  'newpaotang',
};

const List<String> _requiredAndroidIconPaths = [
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
];

const List<String> _requiredIosIconPaths = [
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
];

const List<String> _requiredWebIconPaths = [
  'web/favicon.png',
  'web/icons/Icon-192.png',
  'web/icons/Icon-512.png',
  'web/icons/Icon-maskable-192.png',
  'web/icons/Icon-maskable-512.png',
  'web/manifest.json',
];

class ReleaseBrandingRequest {
  const ReleaseBrandingRequest({
    required this.projectRoot,
    required this.partnerId,
    required this.iconSource,
    required this.adaptiveForegroundSource,
    required this.adaptiveBackground,
    required this.themeColor,
    this.manifestPath = defaultReleaseBrandingManifestPath,
  });

  final Directory projectRoot;
  final String partnerId;
  final File iconSource;
  final File adaptiveForegroundSource;
  final String adaptiveBackground;
  final String themeColor;
  final String manifestPath;
}

class ReleaseBrandingResult {
  const ReleaseBrandingResult({
    required this.manifest,
    required this.generatedFiles,
    required this.commandOutput,
  });

  final File manifest;
  final List<String> generatedFiles;
  final String commandOutput;
}

class ReleaseBrandingVerification {
  const ReleaseBrandingVerification(this.issues);

  final List<String> issues;

  bool get isValid => issues.isEmpty;
}

Future<ReleaseBrandingResult> prepareReleaseBranding(
  ReleaseBrandingRequest request,
) async {
  validateReleaseBrandingRequest(request);

  final root = request.projectRoot.absolute;
  final config = File(_join(root.path, '.customer_flutter_release_icons.yaml'));
  final manifest = File(_resolveWithin(root.path, request.manifestPath));
  final iconPath = request.iconSource.absolute.path;
  final foregroundPath = request.adaptiveForegroundSource.absolute.path;

  config.writeAsStringSync(
    _launcherIconConfig(
      iconPath: iconPath,
      adaptiveForegroundPath: foregroundPath,
      adaptiveBackground: request.adaptiveBackground,
      themeColor: request.themeColor,
    ),
  );

  ProcessResult result;
  try {
    result = await Process.run('dart', [
      'run',
      'flutter_launcher_icons',
      '-f',
      config.path,
    ], workingDirectory: root.path);
  } finally {
    if (config.existsSync()) config.deleteSync();
  }

  final output = '${result.stdout}${result.stderr}'.trim();
  if (result.exitCode != 0) {
    throw StateError(
      'flutter_launcher_icons failed with exit code ${result.exitCode}:\n$output',
    );
  }

  final generatedFiles = collectReleaseBrandingFiles(root);
  final missing = requiredReleaseBrandingPaths(
    includeAndroid: true,
    includeIos: true,
    includeWeb: true,
  ).where((path) => !generatedFiles.contains(path)).toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'Launcher icon generation did not create required files: '
      '${missing.join(', ')}',
    );
  }

  final fileHashes = <String, String>{
    for (final path in generatedFiles)
      path: releaseBrandingFileSha256(File(_join(root.path, path))),
  };
  final manifestPayload = <String, Object>{
    'schema_version': releaseBrandingSchemaVersion,
    'partner_id': request.partnerId.trim(),
    'icon_source_sha256': releaseBrandingFileSha256(request.iconSource),
    'adaptive_foreground_sha256': releaseBrandingFileSha256(
      request.adaptiveForegroundSource,
    ),
    'adaptive_background': request.adaptiveBackground.toUpperCase(),
    'theme_color': request.themeColor.toUpperCase(),
    'files': fileHashes,
  };

  manifest.parent.createSync(recursive: true);
  manifest.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifestPayload)}\n',
  );

  return ReleaseBrandingResult(
    manifest: manifest,
    generatedFiles: generatedFiles,
    commandOutput: output,
  );
}

void validateReleaseBrandingRequest(ReleaseBrandingRequest request) {
  if (!request.projectRoot.existsSync()) {
    throw ArgumentError.value(
      request.projectRoot.path,
      'projectRoot',
      'does not exist',
    );
  }

  final normalizedPartner = request.partnerId.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_-]+'),
    '',
  );
  if (normalizedPartner.isEmpty ||
      _genericPartnerIds.contains(normalizedPartner)) {
    throw ArgumentError.value(
      request.partnerId,
      'partnerId',
      'must identify the release partner and cannot use a scaffold name',
    );
  }

  _validateIconSource(
    request.iconSource,
    argumentName: 'iconSource',
    minimumSize: 1024,
    rejectKnownFlutterIcon: true,
  );
  _validateIconSource(
    request.adaptiveForegroundSource,
    argumentName: 'adaptiveForegroundSource',
    minimumSize: 432,
    rejectKnownFlutterIcon: false,
  );
  _validateHexColor(request.adaptiveBackground, 'adaptiveBackground');
  _validateHexColor(request.themeColor, 'themeColor');

  _resolveWithin(request.projectRoot.absolute.path, request.manifestPath);
}

List<String> collectReleaseBrandingFiles(Directory projectRoot) {
  final root = projectRoot.absolute.path;
  final paths = <String>{};

  final androidRes = Directory(_join(root, 'android/app/src/main/res'));
  if (androidRes.existsSync()) {
    for (final entity in androidRes.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = _relativePath(root, entity.path);
      final name = entity.uri.pathSegments.last;
      if (name.startsWith('ic_launcher') ||
          relative.endsWith('/values/colors.xml')) {
        paths.add(relative);
      }
    }
  }

  final iosIcons = Directory(
    _join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset'),
  );
  if (iosIcons.existsSync()) {
    for (final entity in iosIcons.listSync()) {
      if (entity is File) paths.add(_relativePath(root, entity.path));
    }
  }

  final webIcons = Directory(_join(root, 'web/icons'));
  if (webIcons.existsSync()) {
    for (final entity in webIcons.listSync()) {
      if (entity is File) paths.add(_relativePath(root, entity.path));
    }
  }
  for (final path in ['web/favicon.png', 'web/manifest.json']) {
    if (File(_join(root, path)).existsSync()) paths.add(path);
  }

  final sorted = paths.toList()..sort();
  return sorted;
}

Set<String> requiredReleaseBrandingPaths({
  required bool includeAndroid,
  required bool includeIos,
  required bool includeWeb,
}) {
  return {
    if (includeAndroid) ..._requiredAndroidIconPaths,
    if (includeIos) ..._requiredIosIconPaths,
    if (includeWeb) ..._requiredWebIconPaths,
  };
}

ReleaseBrandingVerification verifyReleaseBrandingManifest({
  required Directory projectRoot,
  required File manifest,
  required bool includeAndroid,
  required bool includeIos,
  required bool includeWeb,
}) {
  final issues = <String>[];
  if (!manifest.existsSync()) {
    return ReleaseBrandingVerification([
      'branding manifest does not exist: ${manifest.path}',
    ]);
  }

  Map<String, dynamic> payload;
  try {
    final decoded = jsonDecode(manifest.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      return const ReleaseBrandingVerification([
        'branding manifest must contain a JSON object',
      ]);
    }
    payload = decoded;
  } on FormatException catch (error) {
    return ReleaseBrandingVerification([
      'branding manifest is invalid JSON: ${error.message}',
    ]);
  }

  if (payload['schema_version'] != releaseBrandingSchemaVersion) {
    issues.add(
      'branding manifest schema_version must be '
      '$releaseBrandingSchemaVersion',
    );
  }

  final partnerId = payload['partner_id']?.toString() ?? '';
  final normalizedPartner = partnerId.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_-]+'),
    '',
  );
  if (normalizedPartner.isEmpty ||
      _genericPartnerIds.contains(normalizedPartner)) {
    issues.add('branding manifest partner_id must be partner-specific');
  }

  final sourceHash =
      payload['icon_source_sha256']?.toString().toLowerCase() ?? '';
  if (!_looksLikeSha256(sourceHash)) {
    issues.add('branding manifest icon_source_sha256 is invalid');
  } else if (_knownFlutterIconHashes.contains(sourceHash)) {
    issues.add('branding manifest still references a Flutter scaffold icon');
  }

  final rawFiles = payload['files'];
  if (rawFiles is! Map) {
    issues.add('branding manifest files must be a path-to-SHA-256 map');
    return ReleaseBrandingVerification(issues);
  }

  final fileHashes = <String, String>{};
  for (final entry in rawFiles.entries) {
    final path = entry.key.toString();
    final hash = entry.value.toString().toLowerCase();
    if (!_isSafeRelativePath(path) || !_looksLikeSha256(hash)) {
      issues.add('branding manifest contains an invalid file entry: $path');
      continue;
    }
    fileHashes[path] = hash;
  }

  final required = requiredReleaseBrandingPaths(
    includeAndroid: includeAndroid,
    includeIos: includeIos,
    includeWeb: includeWeb,
  );
  for (final path in required) {
    if (!fileHashes.containsKey(path)) {
      issues.add('branding manifest does not track required file: $path');
    }
  }

  final root = projectRoot.absolute.path;
  for (final entry in fileHashes.entries) {
    if (!_pathMatchesTarget(
      entry.key,
      includeAndroid: includeAndroid,
      includeIos: includeIos,
      includeWeb: includeWeb,
    )) {
      continue;
    }
    final file = File(_join(root, entry.key));
    if (!file.existsSync()) {
      issues.add('branding file is missing: ${entry.key}');
      continue;
    }
    if (releaseBrandingFileSha256(file) != entry.value) {
      issues.add('branding file changed after generation: ${entry.key}');
    }
  }

  return ReleaseBrandingVerification(issues);
}

String releaseBrandingFileSha256(File file) {
  return sha256.convert(file.readAsBytesSync()).toString();
}

void _validateIconSource(
  File file, {
  required String argumentName,
  required int minimumSize,
  required bool rejectKnownFlutterIcon,
}) {
  if (!file.existsSync()) {
    throw ArgumentError.value(file.path, argumentName, 'does not exist');
  }

  final decoded = image.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    throw ArgumentError.value(file.path, argumentName, 'is not a valid image');
  }
  if (decoded.width != decoded.height || decoded.width < minimumSize) {
    throw ArgumentError.value(
      file.path,
      argumentName,
      'must be a square image at least ${minimumSize}x$minimumSize',
    );
  }

  final hash = releaseBrandingFileSha256(file);
  if (rejectKnownFlutterIcon && _knownFlutterIconHashes.contains(hash)) {
    throw ArgumentError.value(
      file.path,
      argumentName,
      'must not use the Flutter scaffold icon',
    );
  }
}

void _validateHexColor(String value, String argumentName) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.trim())) {
    throw ArgumentError.value(value, argumentName, 'must use #RRGGBB format');
  }
}

String _launcherIconConfig({
  required String iconPath,
  required String adaptiveForegroundPath,
  required String adaptiveBackground,
  required String themeColor,
}) {
  final encodedIcon = jsonEncode(iconPath);
  final encodedForeground = jsonEncode(adaptiveForegroundPath);
  final encodedBackground = jsonEncode(adaptiveBackground.toUpperCase());
  final encodedTheme = jsonEncode(themeColor.toUpperCase());
  return '''
flutter_launcher_icons:
  android: true
  ios: true
  image_path: $encodedIcon
  image_path_android: $encodedIcon
  image_path_ios: $encodedIcon
  min_sdk_android: 21
  adaptive_icon_background: $encodedBackground
  adaptive_icon_foreground: $encodedForeground
  adaptive_icon_foreground_inset: 16
  remove_alpha_ios: true
  background_color_ios: $encodedBackground
  web:
    generate: true
    image_path: $encodedIcon
    background_color: $encodedBackground
    theme_color: $encodedTheme
''';
}

bool _pathMatchesTarget(
  String path, {
  required bool includeAndroid,
  required bool includeIos,
  required bool includeWeb,
}) {
  return (includeAndroid && path.startsWith('android/')) ||
      (includeIos && path.startsWith('ios/')) ||
      (includeWeb && path.startsWith('web/'));
}

bool _looksLikeSha256(String value) {
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

bool _isSafeRelativePath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.startsWith('\\')) {
    return false;
  }
  final segments = path.replaceAll('\\', '/').split('/');
  return !segments.contains('..') && !segments.contains('.');
}

String _resolveWithin(String root, String path) {
  if (!_isSafeRelativePath(path)) {
    throw ArgumentError.value(path, 'path', 'must stay inside project root');
  }
  return _join(root, path);
}

String _relativePath(String root, String path) {
  final normalizedRoot = root
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceAll('\\', '/');
  if (!normalizedPath.startsWith('$normalizedRoot/')) {
    throw ArgumentError.value(path, 'path', 'must be inside $root');
  }
  return normalizedPath.substring(normalizedRoot.length + 1);
}

String _join(String left, String right) {
  final separator = Platform.pathSeparator;
  final normalizedLeft = left.replaceAll(RegExp(r'[\\/]+$'), '');
  final normalizedRight = right.replaceAll(RegExp(r'^[\\/]+'), '');
  return '$normalizedLeft$separator$normalizedRight';
}
