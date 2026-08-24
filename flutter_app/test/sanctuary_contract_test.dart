import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_os/camera_mode.dart';
import 'package:hippo_os/customization_state.dart';
import 'package:hippo_os/production_app.dart';

void main() {
  test('production shell is the release application surface', () {
    expect(const HippoOsProductionApp(), isNotNull);
  });

  test('launch camera contract includes bodycam', () {
    expect(SanctuaryCameraMode.values, contains(SanctuaryCameraMode.bodycam));
    expect(SanctuaryCameraMode.bodycam.engineValue, 'bodycam');
    expect(SanctuaryCameraMode.values.length, 4);
  });

  test('living customization covers world interface camera settings and animals', () {
    const customization = SanctuaryCustomization();
    final payload = customization.toEnginePayload();

    expect(
      payload.keys,
      containsAll(<String>['interface', 'world', 'camera', 'settings', 'animals']),
    );

    final animals = payload['animals']! as Map<String, Object>;
    expect(animals.keys, containsAll(<String>['hippo_01', 'pig_01', 'sharpei_01']));
    expect((animals['hippo_01']! as Map<String, Object>)['name'], 'Mochi');
    expect((animals['pig_01']! as Map<String, Object>)['name'], 'Truffle');
    expect((animals['sharpei_01']! as Map<String, Object>)['name'], 'Bao');

    final world = payload['world']! as Map<String, Object>;
    expect(world['auto_living_world'], isTrue);
    expect(world['weather_life'], isA<double>());

    final camera = payload['camera']! as Map<String, Object>;
    expect(camera['bodycam_motion'], isA<double>());

    final settings = payload['settings']! as Map<String, Object>;
    expect(settings['master_volume'], 1.0);
    expect(settings['haptics'], isTrue);
    expect(settings['reduced_motion'], isFalse);
    expect(settings['text_scale'], 1.0);
  });

  test('engine customization payload restores user choices', () {
    final restored = SanctuaryCustomization.fromEnginePayload(<String, Object>{
      'interface': <String, Object>{
        'accent_hue': 0.72,
        'glass': 0.65,
        'scale': 1.10,
      },
      'world': <String, Object>{
        'vegetation_density': 0.91,
        'water_clarity': 0.64,
        'mud_amount': 0.78,
        'light_warmth': 0.44,
        'weather_life': 0.88,
        'wind_life': 0.71,
        'world_motion': 0.80,
        'auto_living_world': true,
      },
      'camera': <String, Object>{'bodycam_motion': 0.35},
      'settings': <String, Object>{
        'master_volume': 0.90,
        'animal_volume': 0.75,
        'ambience_volume': 0.60,
        'ui_volume': 0.55,
        'haptics': false,
        'show_stats': false,
        'reduced_motion': true,
        'camera_sensitivity': 1.35,
        'text_scale': 1.15,
      },
      'animals': <String, Object>{
        'hippo_01': <String, Object>{'name': 'River', 'body_scale': 1.06},
        'pig_01': <String, Object>{'name': 'Bean'},
        'sharpei_01': <String, Object>{'name': 'Bao'},
      },
    });

    expect(restored.accentHue, 0.72);
    expect(restored.mochi.name, 'River');
    expect(restored.mochi.bodyScale, 1.06);
    expect(restored.truffle.name, 'Bean');
    expect(restored.reducedMotion, isTrue);
    expect(restored.haptics, isFalse);
    expect(restored.textScale, 1.15);
    expect(restored.cameraSensitivity, 1.35);
  });
}
