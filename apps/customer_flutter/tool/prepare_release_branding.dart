import 'dart:io';

import 'src/release_branding.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.hasFlag('help')) {
    _printUsage();
    return;
  }

  final projectRoot = Directory(options.value('project-root') ?? '.');
  final partnerId = _required(options, 'partner-id');
  final iconSource = File(_required(options, 'icon-source'));
  final adaptiveForeground = File(_required(options, 'adaptive-foreground'));
  final adaptiveBackground = _required(options, 'adaptive-background');
  final themeColor = _required(options, 'theme-color');
  final manifestPath =
      options.value('manifest') ?? defaultReleaseBrandingManifestPath;

  try {
    final result = await prepareReleaseBranding(
      ReleaseBrandingRequest(
        projectRoot: projectRoot,
        partnerId: partnerId,
        iconSource: iconSource,
        adaptiveForegroundSource: adaptiveForeground,
        adaptiveBackground: adaptiveBackground,
        themeColor: themeColor,
        manifestPath: manifestPath,
      ),
    );
    if (result.commandOutput.isNotEmpty) stdout.writeln(result.commandOutput);
    stdout.writeln(
      'Prepared ${result.generatedFiles.length} release branding files.',
    );
    stdout.writeln('Manifest: ${result.manifest.path}');
  } on Object catch (error) {
    stderr.writeln('Customer Flutter release branding failed: $error');
    exitCode = 1;
  }
}

String _required(_Options options, String key) {
  final value = options.value(key)?.trim() ?? '';
  if (value.isEmpty) {
    throw ArgumentError('Missing required --$key');
  }
  return value;
}

void _printUsage() {
  stdout.writeln('''
Generate partner-specific Android, iOS, and Web launcher icons.

Usage:
  dart run tool/prepare_release_branding.dart \\
    --partner-id partner-key \\
    --icon-source /secure/partner-app-icon-1024.png \\
    --adaptive-foreground /secure/partner-adaptive-foreground-1024.png \\
    --adaptive-background '#087FF0' \\
    --theme-color '#087FF0'

Options:
  --project-root PATH       customer_flutter project root (default: .)
  --manifest PATH           generated hash manifest relative to project root
  --partner-id VALUE        non-generic release partner/build identifier
  --icon-source PATH        square app icon, at least 1024x1024
  --adaptive-foreground PATH
                            square Android adaptive foreground, at least 432x432
  --adaptive-background HEX
                            Android/iOS/Web icon background in #RRGGBB form
  --theme-color HEX         Web manifest theme color in #RRGGBB form
''');
}

class _Options {
  _Options(this._values, this._flags);

  factory _Options.parse(List<String> args) {
    final values = <String, String>{};
    final flags = <String>{};
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (!arg.startsWith('--')) continue;
      final body = arg.substring(2);
      final separator = body.indexOf('=');
      if (separator >= 0) {
        values[body.substring(0, separator)] = body.substring(separator + 1);
        continue;
      }
      if (index + 1 < args.length && !args[index + 1].startsWith('--')) {
        values[body] = args[++index];
      } else {
        flags.add(body);
      }
    }
    return _Options(values, flags);
  }

  final Map<String, String> _values;
  final Set<String> _flags;

  String? value(String key) => _values[key];
  bool hasFlag(String key) => _flags.contains(key);
}
