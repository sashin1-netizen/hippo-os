import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('production entrypoint wraps the open-world sanctuary', () {
    final main = read('lib/main.dart');
    final production = read('lib/production_app.dart');
    final openWorld = read('lib/open_world_app.dart');

    expect(main, contains("import 'production_app.dart';"));
    expect(main, contains('runProductionApp()'));
    expect(production, contains('OpenWorldSanctuaryScreen'));
    expect(production, contains('ENTER SANCTUARY'));
    expect(production, contains('PRIVACY'));
    expect(production, contains('CREDITS & LICENCES'));
    expect(production, contains('reset_sanctuary'));

    expect(openWorld, contains("'roam:"));
    expect(openWorld, contains("'look:"));
    expect(openWorld, contains('SanctuaryCameraMode.bodycam'));
    expect(openWorld, contains('_WorldMap'));
    expect(openWorld, contains('_Joystick'));
  });

  test('personal build manifest exposes only required device capability', () {
    final manifest = read('native_overrides/AndroidManifest.xml');
    final launcher = read('android/app/src/main/res/drawable/hippo_launcher.xml');

    expect(manifest, contains('android.permission.VIBRATE'));
    expect(manifest, contains('android:icon="@drawable/hippo_launcher"'));
    expect(manifest, contains('android:roundIcon="@drawable/hippo_launcher"'));
    expect(launcher, contains('<vector'));
    expect(launcher, contains('#163128'));

    for (final forbidden in <String>[
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.CAMERA',
      'android.permission.RECORD_AUDIO',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_AUDIO',
    ]) {
      expect(manifest, isNot(contains(forbidden)), reason: 'Forbidden permission: $forbidden');
    }
    expect(manifest, isNot(contains('<queries>')));
    expect(manifest, contains('android:screenOrientation="landscape"'));
  });

  test('Android QA package is API 36 and release optimized', () {
    final gradle = read('native_overrides/build.gradle.kts');
    expect(gradle, contains('compileSdk = 36'));
    expect(gradle, contains('minSdk = 26'));
    expect(gradle, contains('targetSdk = 36'));
    expect(gradle, contains('applicationId = "com.sashin.hippoos.preview"'));
    expect(gradle, contains('implementation("org.godotengine:godot:4.7.2.stable")'));
  });
}
