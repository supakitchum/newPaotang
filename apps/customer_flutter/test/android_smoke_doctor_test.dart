import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/src/android_smoke_doctor.dart';

void main() {
  test('parseAndroidAvdConfig ignores comments and keeps key values', () {
    final config = parseAndroidAvdConfig('''
# Pixel smoke AVD
AvdId=Pixel_4_API_33
image.sysdir.1 = system-images/android-33/google_apis/arm64-v8a/

invalid-line
hw.cpu.arch=arm64
''');

    expect(config['AvdId'], 'Pixel_4_API_33');
    expect(
      config['image.sysdir.1'],
      'system-images/android-33/google_apis/arm64-v8a/',
    );
    expect(config['hw.cpu.arch'], 'arm64');
    expect(config, isNot(contains('invalid-line')));
  });

  test('resolveAndroidImageDir trims relative and absolute image paths', () {
    expect(
      resolveAndroidImageDir('/sdk/', 'system-images/android-33/google_apis/'),
      '/sdk/system-images/android-33/google_apis',
    );
    expect(
      resolveAndroidImageDir('/sdk', '/opt/android/system-image/'),
      '/opt/android/system-image',
    );
  });

  test('doctor passes when the AVD system image payload is complete', () {
    final fixture = _AndroidDoctorFixture.create();
    try {
      fixture.writeAvdConfig(
        'system-images/android-33/google_apis/arm64-v8a/',
      );
      fixture.writeSystemImagePayload(systemImageName: 'system.img');

      final issues = runAndroidSmokeDoctor(fixture.input);

      expect(issues, isEmpty);
    } finally {
      fixture.dispose();
    }
  });

  test('doctor reports partial system image payload before emulator launch',
      () {
    final fixture = _AndroidDoctorFixture.create();
    try {
      fixture.writeAvdConfig(
        'system-images/android-33/google_apis/arm64-v8a',
      );
      fixture.writeKernelOnlySystemImage();

      final issues = runAndroidSmokeDoctor(fixture.input);

      expect(
        issues.map((issue) => issue.code),
        contains('android_system_image_payload_missing'),
      );
      expect(
        issues
            .firstWhere(
              (issue) => issue.code == 'android_system_image_payload_missing',
            )
            .remediation,
        contains('system-images;android-33;google_apis;arm64-v8a'),
      );
    } finally {
      fixture.dispose();
    }
  });

  test('doctor reports missing AVD config with actionable remediation', () {
    final fixture = _AndroidDoctorFixture.create();
    try {
      final issues = runAndroidSmokeDoctor(fixture.input);

      expect(issues, hasLength(1));
      expect(issues.single.code, 'android_avd_config_missing');
      expect(issues.single.remediation, contains('Create the AVD'));
    } finally {
      fixture.dispose();
    }
  });
}

class _AndroidDoctorFixture {
  _AndroidDoctorFixture._(this.root)
      : sdkRoot = Directory('${root.path}/sdk'),
        avdHome = Directory('${root.path}/avd') {
    sdkRoot.createSync(recursive: true);
    avdHome.createSync(recursive: true);
  }

  final Directory root;
  final Directory sdkRoot;
  final Directory avdHome;
  final avdName = 'Pixel_4_API_33';

  static _AndroidDoctorFixture create() {
    return _AndroidDoctorFixture._(
      Directory.systemTemp.createTempSync('android_smoke_doctor_test_'),
    );
  }

  AndroidSmokeDoctorInput get input => AndroidSmokeDoctorInput(
        sdkRoot: sdkRoot.path,
        avdHome: avdHome.path,
        avdName: avdName,
      );

  Directory get avdDir => Directory('${avdHome.path}/$avdName.avd');

  Directory get imageDir => Directory(
        '${sdkRoot.path}/system-images/android-33/google_apis/arm64-v8a',
      );

  void writeAvdConfig(String imageSysdir) {
    avdDir.createSync(recursive: true);
    File('${avdDir.path}/config.ini').writeAsStringSync('''
AvdId=$avdName
image.sysdir.1=$imageSysdir
''');
  }

  void writeSystemImagePayload({required String systemImageName}) {
    imageDir.createSync(recursive: true);
    File('${imageDir.path}/$systemImageName').writeAsStringSync('image');
    File('${imageDir.path}/kernel-ranchu').writeAsStringSync('kernel');
  }

  void writeKernelOnlySystemImage() {
    imageDir.createSync(recursive: true);
    File('${imageDir.path}/kernel-ranchu').writeAsStringSync('kernel');
  }

  void dispose() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}
