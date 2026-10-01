import 'dart:io';

import 'src/android_smoke_doctor.dart';

void main(List<String> args) {
  final options = _parseArgs(args);
  if (options.flag('help')) {
    _printUsage();
    return;
  }

  final sdkRoot =
      options.value('sdk-root') ?? defaultAndroidSdkRoot(Platform.environment);
  final avdHome =
      options.value('avd-home') ?? defaultAndroidAvdHome(Platform.environment);
  final avd = options.value('avd') ??
      Platform.environment['CUSTOMER_FLUTTER_ANDROID_SMOKE_AVD'] ??
      'Pixel_4_API_33';

  final issues = runAndroidSmokeDoctor(
    AndroidSmokeDoctorInput(
      sdkRoot: sdkRoot,
      avdHome: avdHome,
      avdName: avd,
    ),
  );

  if (issues.isEmpty) {
    stdout.writeln('Android smoke doctor passed for AVD $avd.');
    return;
  }

  stderr.writeln('Android smoke doctor failed for AVD $avd:');
  for (final issue in issues) {
    stderr.writeln('- ${issue.code}: ${issue.message}');
    if (issue.remediation.trim().isNotEmpty) {
      stderr.writeln('  ${issue.remediation}');
    }
  }
  exitCode = 1;
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
      values.putIfAbsent(parts.first, () => []).add(parts.sublist(1).join('='));
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

void _printUsage() {
  stdout.writeln('''
Validate the local Android AVD used by customer_flutter smoke tests.

Usage:
  dart run tool/android_smoke_doctor.dart \\
    --avd Pixel_4_API_33 \\
    --sdk-root "\$HOME/Library/Android/sdk"

Options:
  --avd NAME          AVD name. Defaults to CUSTOMER_FLUTTER_ANDROID_SMOKE_AVD
                      or Pixel_4_API_33.
  --sdk-root PATH     Android SDK root. Defaults to ANDROID_SDK_ROOT,
                      ANDROID_HOME, or ~/Library/Android/sdk.
  --avd-home PATH     AVD home. Defaults to ANDROID_AVD_HOME or ~/.android/avd.

This catches partial/corrupt system-image installs before Flutter waits through
an Android integration smoke run.
''');
}

class _Options {
  const _Options(this._values, this._flags);

  final Map<String, List<String>> _values;
  final Set<String> _flags;

  bool flag(String key) => _flags.contains(key);

  String? value(String key) => _values[key]?.last;
}
