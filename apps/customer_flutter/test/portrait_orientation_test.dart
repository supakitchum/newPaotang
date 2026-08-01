import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer app is portrait-only on native and web PWA targets', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('SystemChrome.setPreferredOrientations'));
    expect(mainSource, contains('DeviceOrientation.portraitUp'));
    expect(mainSource, isNot(contains('DeviceOrientation.landscape')));

    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(androidManifest, contains('android:screenOrientation="portrait"'));

    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      iosInfo,
      contains('<string>UIInterfaceOrientationPortrait</string>'),
    );
    expect(iosInfo, isNot(contains('UIInterfaceOrientationLandscape')));
    expect(
      iosInfo,
      isNot(contains('UIInterfaceOrientationPortraitUpsideDown')),
    );
    expect(iosInfo, contains('<key>UIRequiresFullScreen</key>'));

    final webManifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(webManifest['orientation'], 'portrait-primary');

    final webIndex = File('web/index.html').readAsStringSync();
    expect(
      webIndex,
      contains('const manifestOrientation = "portrait-primary"'),
    );
    expect(
      webIndex,
      contains('lockOrientation(orientation, "portrait-primary")'),
    );
    expect(webIndex, contains('customer-portrait-orientation-guard'));
    expect(webIndex, isNot(contains('firstConfigValue(["orientation"')));
  });
}
