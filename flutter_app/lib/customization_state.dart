class AnimalCustomization {
  const AnimalCustomization({
    this.bodyScale = 1.0,
    this.skinWarmth = 0.5,
    this.patternStrength = 0.25,
    this.eyeBrightness = 0.5,
    this.curiosityBias = 0.5,
    this.socialBias = 0.5,
    this.energyBias = 0.5,
  });

  final double bodyScale;
  final double skinWarmth;
  final double patternStrength;
  final double eyeBrightness;
  final double curiosityBias;
  final double socialBias;
  final double energyBias;

  factory AnimalCustomization.fromJson(dynamic source) {
    final map = _stringMap(source);
    return AnimalCustomization(
      bodyScale: _number(map['body_scale'], 1.0),
      skinWarmth: _number(map['skin_warmth'], 0.5),
      patternStrength: _number(map['pattern_strength'], 0.25),
      eyeBrightness: _number(map['eye_brightness'], 0.5),
      curiosityBias: _number(map['curiosity_bias'], 0.5),
      socialBias: _number(map['social_bias'], 0.5),
      energyBias: _number(map['energy_bias'], 0.5),
    );
  }

  AnimalCustomization copyWith({
    double? bodyScale,
    double? skinWarmth,
    double? patternStrength,
    double? eyeBrightness,
    double? curiosityBias,
    double? socialBias,
    double? energyBias,
  }) {
    return AnimalCustomization(
      bodyScale: bodyScale ?? this.bodyScale,
      skinWarmth: skinWarmth ?? this.skinWarmth,
      patternStrength: patternStrength ?? this.patternStrength,
      eyeBrightness: eyeBrightness ?? this.eyeBrightness,
      curiosityBias: curiosityBias ?? this.curiosityBias,
      socialBias: socialBias ?? this.socialBias,
      energyBias: energyBias ?? this.energyBias,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'body_scale': bodyScale,
        'skin_warmth': skinWarmth,
        'pattern_strength': patternStrength,
        'eye_brightness': eyeBrightness,
        'curiosity_bias': curiosityBias,
        'social_bias': socialBias,
        'energy_bias': energyBias,
      };
}

class SanctuaryCustomization {
  const SanctuaryCustomization({
    this.accentHue = 0.39,
    this.interfaceGlass = 0.82,
    this.interfaceScale = 1.0,
    this.textScale = 1.0,
    this.vegetationDensity = 0.72,
    this.waterClarity = 0.72,
    this.mudAmount = 0.55,
    this.lightWarmth = 0.58,
    this.weatherLife = 0.65,
    this.windLife = 0.55,
    this.worldMotion = 0.62,
    this.bodycamMotion = 0.45,
    this.cameraSensitivity = 1.0,
    this.masterVolume = 1.0,
    this.animalVolume = 1.0,
    this.ambienceVolume = 0.85,
    this.uiVolume = 0.85,
    this.haptics = true,
    this.showStats = true,
    this.reducedMotion = false,
    this.autoLivingWorld = true,
    this.mochi = const AnimalCustomization(),
    this.truffle = const AnimalCustomization(),
    this.bao = const AnimalCustomization(),
  });

  final double accentHue;
  final double interfaceGlass;
  final double interfaceScale;
  final double textScale;
  final double vegetationDensity;
  final double waterClarity;
  final double mudAmount;
  final double lightWarmth;
  final double weatherLife;
  final double windLife;
  final double worldMotion;
  final double bodycamMotion;
  final double cameraSensitivity;
  final double masterVolume;
  final double animalVolume;
  final double ambienceVolume;
  final double uiVolume;
  final bool haptics;
  final bool showStats;
  final bool reducedMotion;
  final bool autoLivingWorld;
  final AnimalCustomization mochi;
  final AnimalCustomization truffle;
  final AnimalCustomization bao;

  factory SanctuaryCustomization.fromEnginePayload(dynamic source) {
    final root = _stringMap(source);
    final interface = _stringMap(root['interface']);
    final world = _stringMap(root['world']);
    final camera = _stringMap(root['camera']);
    final animals = _stringMap(root['animals']);
    final settings = _stringMap(root['settings']);
    return SanctuaryCustomization(
      accentHue: _number(interface['accent_hue'], 0.39),
      interfaceGlass: _number(interface['glass'], 0.82),
      interfaceScale: _number(interface['scale'], 1.0),
      textScale: _number(settings['text_scale'], 1.0),
      vegetationDensity: _number(world['vegetation_density'], 0.72),
      waterClarity: _number(world['water_clarity'], 0.72),
      mudAmount: _number(world['mud_amount'], 0.55),
      lightWarmth: _number(world['light_warmth'], 0.58),
      weatherLife: _number(world['weather_life'], 0.65),
      windLife: _number(world['wind_life'], 0.55),
      worldMotion: _number(world['world_motion'], 0.62),
      bodycamMotion: _number(camera['bodycam_motion'], 0.45),
      cameraSensitivity: _number(settings['camera_sensitivity'], 1.0),
      masterVolume: _number(settings['master_volume'], 1.0),
      animalVolume: _number(settings['animal_volume'], 1.0),
      ambienceVolume: _number(settings['ambience_volume'], 0.85),
      uiVolume: _number(settings['ui_volume'], 0.85),
      haptics: _boolean(settings['haptics'], true),
      showStats: _boolean(settings['show_stats'], true),
      reducedMotion: _boolean(settings['reduced_motion'], false),
      autoLivingWorld: _boolean(world['auto_living_world'], true),
      mochi: AnimalCustomization.fromJson(animals['hippo_01']),
      truffle: AnimalCustomization.fromJson(animals['pig_01']),
      bao: AnimalCustomization.fromJson(animals['sharpei_01']),
    );
  }

  SanctuaryCustomization copyWith({
    double? accentHue,
    double? interfaceGlass,
    double? interfaceScale,
    double? textScale,
    double? vegetationDensity,
    double? waterClarity,
    double? mudAmount,
    double? lightWarmth,
    double? weatherLife,
    double? windLife,
    double? worldMotion,
    double? bodycamMotion,
    double? cameraSensitivity,
    double? masterVolume,
    double? animalVolume,
    double? ambienceVolume,
    double? uiVolume,
    bool? haptics,
    bool? showStats,
    bool? reducedMotion,
    bool? autoLivingWorld,
    AnimalCustomization? mochi,
    AnimalCustomization? truffle,
    AnimalCustomization? bao,
  }) {
    return SanctuaryCustomization(
      accentHue: accentHue ?? this.accentHue,
      interfaceGlass: interfaceGlass ?? this.interfaceGlass,
      interfaceScale: interfaceScale ?? this.interfaceScale,
      textScale: textScale ?? this.textScale,
      vegetationDensity: vegetationDensity ?? this.vegetationDensity,
      waterClarity: waterClarity ?? this.waterClarity,
      mudAmount: mudAmount ?? this.mudAmount,
      lightWarmth: lightWarmth ?? this.lightWarmth,
      weatherLife: weatherLife ?? this.weatherLife,
      windLife: windLife ?? this.windLife,
      worldMotion: worldMotion ?? this.worldMotion,
      bodycamMotion: bodycamMotion ?? this.bodycamMotion,
      cameraSensitivity: cameraSensitivity ?? this.cameraSensitivity,
      masterVolume: masterVolume ?? this.masterVolume,
      animalVolume: animalVolume ?? this.animalVolume,
      ambienceVolume: ambienceVolume ?? this.ambienceVolume,
      uiVolume: uiVolume ?? this.uiVolume,
      haptics: haptics ?? this.haptics,
      showStats: showStats ?? this.showStats,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      autoLivingWorld: autoLivingWorld ?? this.autoLivingWorld,
      mochi: mochi ?? this.mochi,
      truffle: truffle ?? this.truffle,
      bao: bao ?? this.bao,
    );
  }

  Map<String, Object> toEnginePayload() => <String, Object>{
        'interface': <String, Object>{
          'accent_hue': accentHue,
          'glass': interfaceGlass,
          'scale': interfaceScale,
        },
        'world': <String, Object>{
          'vegetation_density': vegetationDensity,
          'water_clarity': waterClarity,
          'mud_amount': mudAmount,
          'light_warmth': lightWarmth,
          'weather_life': weatherLife,
          'wind_life': windLife,
          'world_motion': worldMotion,
          'auto_living_world': autoLivingWorld,
        },
        'camera': <String, Object>{
          'bodycam_motion': bodycamMotion,
        },
        'settings': <String, Object>{
          'master_volume': masterVolume,
          'animal_volume': animalVolume,
          'ambience_volume': ambienceVolume,
          'ui_volume': uiVolume,
          'haptics': haptics,
          'show_stats': showStats,
          'reduced_motion': reducedMotion,
          'camera_sensitivity': cameraSensitivity,
          'text_scale': textScale,
        },
        'animals': <String, Object>{
          'hippo_01': mochi.toJson(),
          'pig_01': truffle.toJson(),
          'sharpei_01': bao.toJson(),
        },
      };
}

double _number(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

bool _boolean(dynamic value, bool fallback) {
  if (value is bool) return value;
  if ('$value'.toLowerCase() == 'true') return true;
  if ('$value'.toLowerCase() == 'false') return false;
  return fallback;
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry('$key', item));
}
