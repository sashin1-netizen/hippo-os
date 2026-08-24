enum SanctuaryCameraMode {
  cinematic,
  caretaker,
  bodycam,
  overhead;

  String get label => switch (this) {
        SanctuaryCameraMode.cinematic => 'CINEMATIC',
        SanctuaryCameraMode.caretaker => 'CARETAKER',
        SanctuaryCameraMode.bodycam => 'BODYCAM',
        SanctuaryCameraMode.overhead => 'OVERHEAD',
      };

  String get engineValue => name;
}
