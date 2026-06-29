import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Flutter UI does not ship empty tap handlers', () {
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
        if (_emptyHandlerPattern.hasMatch(line)) {
          violations.add('$path:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Replace empty button/tap handlers with real behavior or disabled state.\n'
          '${violations.join('\n')}',
    );
  });
}

final _emptyHandlerPattern =
    RegExp(r'on(?:Pressed|Tap):\s*(?:\(\)\s*)?(?:async\s*)?\{\s*\}');
