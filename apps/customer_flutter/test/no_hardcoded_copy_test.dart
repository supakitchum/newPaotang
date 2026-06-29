import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Dart files do not hardcode Thai user-facing copy', () {
    final violations = <String>[];
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .where((file) => !file.path.endsWith('.freezed.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in sourceFiles) {
      final path = file.path.replaceAll('\\', '/');
      if (_fullyAllowedLocalizedSources.contains(path)) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (!_thaiTextPattern.hasMatch(line)) {
          continue;
        }
        if (_allowedInlineThaiCopy(path, line)) {
          continue;
        }

        violations.add('$path:${index + 1}: ${line.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: [
        'Move Thai copy into CustomerLocalizations instead of hardcoding it in',
        'feature, screen, widget, route, model, or service files.',
        ...violations,
      ].join('\n'),
    );
  });

  test('production Dart files do not hardcode default lottery brand copy', () {
    final violations = <String>[];
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .where((file) => !file.path.endsWith('.freezed.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in sourceFiles) {
      final path = file.path.replaceAll('\\', '/');
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (!_defaultBrandCopyPattern.hasMatch(line)) {
          continue;
        }

        violations.add('$path:${index + 1}: ${line.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: [
        'Use tenant/bootstrap branding instead of hardcoded default lottery',
        'brand copy in production Flutter UI.',
        ...violations,
      ].join('\n'),
    );
  });

  test('production Dart files do not hardcode project-specific runtime values',
      () {
    final violations = <String>[];
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .where((file) => !file.path.endsWith('.freezed.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in sourceFiles) {
      final path = file.path.replaceAll('\\', '/');
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (!_projectRuntimeValuePattern.hasMatch(line)) {
          continue;
        }

        violations.add('$path:${index + 1}: ${line.trim()}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: [
        'Production Flutter code must read partner/project runtime values from',
        'bootstrap, dart-define, native config, or secure storage instead of',
        'hardcoded NewPaotang/local development defaults.',
        ...violations,
      ].join('\n'),
    );
  });
}

final _thaiTextPattern = RegExp(r'[ก-๙]');
final _defaultBrandCopyPattern = RegExp(r"""(['"])(GLO|L6)\1""");
final _projectRuntimeValuePattern = RegExp(
  r'(newpaotang|localhost|127\.0\.0\.1|0\.0\.0\.0)',
  caseSensitive: false,
);

const _fullyAllowedLocalizedSources = {
  'lib/core/i18n/customer_localizations.dart',
};

bool _allowedInlineThaiCopy(String path, String line) {
  if (path != 'lib/core/utils/formatters.dart') {
    return false;
  }

  return line.contains("'THB'") && line.contains("'บาท'");
}
