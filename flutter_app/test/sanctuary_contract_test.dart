import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_os/camera_mode.dart';
import 'package:hippo_os/customization_state.dart';

void main() {
  test('launch camera contract includes bodycam', () {
    expect(SanctuaryCameraMode.values, contains(SanctuaryCameraMode.bodycam));
    expect(SanctuaryCameraMode.bodycam.engineValue, 'bodycam');
    expect(SanctuaryCameraMode.values.length, 4);
  });

  test('living customization payload covers world camera interface and animals', () {
    const customization = SanctuaryCustomization();
    final payload = customization.toEnginePayload();

    expect(payload.keys, containsAll(<String>['interface', 'world', 'camera', 'animals']));
    final animals = payload['animals']! as Map<String, Object>;
    expect(animals.keys, containsAll(<String>['hippo_01', 'pig_01', 'sharpei_01']));

    final world = payload['world']! as Map<String, Object>;
    expect(world['auto_living_world'], isTrue);
    expect(world['weather_life'], isA<double>());

    final camera = payload['camera']! as Map<String, Object>;
    expect(camera['bodycam_motion'], isA<double>());
  });
}
