import 'dart:io';

class AndroidSmokeDoctorInput {
  const AndroidSmokeDoctorInput({
    required this.sdkRoot,
    required this.avdName,
    required this.avdHome,
  });

  final String sdkRoot;
  final String avdName;
  final String avdHome;
}

class AndroidSmokeDoctorIssue {
  const AndroidSmokeDoctorIssue({
    required this.code,
    required this.message,
    this.remediation = '',
  });

  final String code;
  final String message;
  final String remediation;

  @override
  String toString() {
    if (remediation.trim().isEmpty) return '[$code] $message';
    return '[$code] $message Remediation: $remediation';
  }
}

List<AndroidSmokeDoctorIssue> runAndroidSmokeDoctor(
  AndroidSmokeDoctorInput input,
) {
  final issues = <AndroidSmokeDoctorIssue>[];
  final sdkRoot = Directory(input.sdkRoot.trim());
  if (!sdkRoot.existsSync()) {
    return [
      AndroidSmokeDoctorIssue(
        code: 'android_sdk_missing',
        message: 'Android SDK root was not found: ${sdkRoot.path}',
        remediation:
            'Set ANDROID_SDK_ROOT or pass --sdk-root to the Android SDK path.',
      ),
    ];
  }

  final avdName = input.avdName.trim();
  if (avdName.isEmpty) {
    return const [
      AndroidSmokeDoctorIssue(
        code: 'android_avd_missing',
        message: 'AVD name is required.',
        remediation: 'Pass --avd Pixel_4_API_33 or another smoke-test AVD.',
      ),
    ];
  }

  final avdDir = Directory('${input.avdHome}/$avdName.avd');
  final avdConfig = File('${avdDir.path}/config.ini');
  if (!avdConfig.existsSync()) {
    return [
      AndroidSmokeDoctorIssue(
        code: 'android_avd_config_missing',
        message: 'AVD config was not found: ${avdConfig.path}',
        remediation:
            'Create the AVD in Android Studio or run flutter emulators --create.',
      ),
    ];
  }

  final config = parseAndroidAvdConfig(avdConfig.readAsStringSync());
  final imageSysdir = config['image.sysdir.1']?.trim() ?? '';
  if (imageSysdir.isEmpty) {
    issues.add(
      AndroidSmokeDoctorIssue(
        code: 'android_avd_image_missing',
        message: 'AVD $avdName does not declare image.sysdir.1.',
        remediation:
            'Recreate the AVD or choose an AVD with a configured system image.',
      ),
    );
    return issues;
  }

  final imageDir = Directory(resolveAndroidImageDir(sdkRoot.path, imageSysdir));
  if (!imageDir.existsSync()) {
    issues.add(
      AndroidSmokeDoctorIssue(
        code: 'android_system_image_dir_missing',
        message: 'System image directory was not found: ${imageDir.path}',
        remediation:
            'Install the AVD system image with sdkmanager "$imageSysdir".',
      ),
    );
    return issues;
  }

  final initialImages = androidInitialSystemImageCandidates(imageDir.path)
      .where((file) => file.existsSync())
      .toList(growable: false);
  if (initialImages.isEmpty) {
    issues.add(
      AndroidSmokeDoctorIssue(
        code: 'android_system_image_payload_missing',
        message:
            'System image ${imageDir.path} is missing system.img/system-qemu.img/super.img, so the emulator will fail with "No initial system image".',
        remediation:
            'Remove the partial system image directory and reinstall it with sdkmanager --sdk_root="${sdkRoot.path}" "${imageSysdir.replaceAll(RegExp(r"/$"), "").replaceAll("/", ";")}".',
      ),
    );
  }

  final kernelExists = File('${imageDir.path}/kernel-ranchu').existsSync() ||
      File('${imageDir.path}/kernel-qemu').existsSync();
  if (!kernelExists) {
    issues.add(
      AndroidSmokeDoctorIssue(
        code: 'android_system_image_kernel_missing',
        message: 'System image ${imageDir.path} is missing an emulator kernel.',
        remediation:
            'Reinstall the system image package before running Android smoke.',
      ),
    );
  }

  return issues;
}

Map<String, String> parseAndroidAvdConfig(String source) {
  final values = <String, String>{};
  for (final rawLine in source.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final index = line.indexOf('=');
    values[line.substring(0, index).trim()] = line.substring(index + 1).trim();
  }
  return values;
}

String resolveAndroidImageDir(String sdkRoot, String imageSysdir) {
  final value = imageSysdir.trim();
  if (value.startsWith('/')) return _stripTrailingSlash(value);
  return _stripTrailingSlash('${_stripTrailingSlash(sdkRoot)}/$value');
}

List<File> androidInitialSystemImageCandidates(String imageDir) {
  final root = _stripTrailingSlash(imageDir);
  return [
    File('$root/system.img'),
    File('$root/system-qemu.img'),
    File('$root/super.img'),
  ];
}

String defaultAndroidSdkRoot(Map<String, String> environment) {
  final explicit =
      (environment['ANDROID_SDK_ROOT'] ?? environment['ANDROID_HOME'] ?? '')
          .trim();
  if (explicit.isNotEmpty) return explicit;
  final home = environment['HOME']?.trim() ?? '';
  return home.isEmpty ? '' : '$home/Library/Android/sdk';
}

String defaultAndroidAvdHome(Map<String, String> environment) {
  final explicit = environment['ANDROID_AVD_HOME']?.trim() ?? '';
  if (explicit.isNotEmpty) return explicit;
  final home = environment['HOME']?.trim() ?? '';
  return home.isEmpty ? '' : '$home/.android/avd';
}

String _stripTrailingSlash(String value) {
  var result = value.trim();
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
