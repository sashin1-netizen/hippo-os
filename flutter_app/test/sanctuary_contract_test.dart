import 'package:flutter_test/flutter_test.dart';
import 'package:hippo_os/camera_mode.dart';

void main() {
  test('launch camera contract includes bodycam', () {
    expect(SanctuaryCameraMode.values, contains(SanctuaryCameraMode.bodycam));
    expect(SanctuaryCameraMode.bodycam.engineValue, 'bodycam');
    expect(SanctuaryCameraMode.values.length, 4);
  });
}
