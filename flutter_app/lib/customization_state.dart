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
    this.vegetationDensity = 0.72,
    this.waterClarity = 0.72,
    this.mudAmount = 0.55,
    this.lightWarmth = 0.58,
    this.weatherLife = 0.65,
    this.windLife = 0.55,
    this.worldMotion = 0.62,
    this.bodycamMotion = 0.45,
    this.autoLivingWorld = true,
    this.mochi = const AnimalCustomization(),
    this.truffle = const AnimalCustomization(),
    this.bao = const AnimalCustomization(),
  });

  final double accentHue;
  final double interfaceGlass;
  final double interfaceScale;
  final double vegetationDensity;
  final double waterClarity;
  final double mudAmount;
  final double lightWarmth;
  final double weatherLife;
  final double windLife;
  final double worldMotion;
  final double bodycamMotion;
  final bool autoLivingWorld;
  final AnimalCustomization mochi;
  final AnimalCustomization truffle;
  final AnimalCustomization bao;

  SanctuaryCustomization copyWith({
    double? accentHue,
    double? interfaceGlass,
    double? interfaceScale,
    double? vegetationDensity,
    double? waterClarity,
    double? mudAmount,
    double? lightWarmth,
    double? weatherLife,
    double? windLife,
    double? worldMotion,
    double? bodycamMotion,
    bool? autoLivingWorld,
    AnimalCustomization? mochi,
    AnimalCustomization? truffle,
    AnimalCustomization? bao,
  }) {
    return SanctuaryCustomization(
      accentHue: accentHue ?? this.accentHue,
      interfaceGlass: interfaceGlass ?? this.interfaceGlass,
      interfaceScale: interfaceScale ?? this.interfaceScale,
      vegetationDensity: vegetationDensity ?? this.vegetationDensity,
      waterClarity: waterClarity ?? this.waterClarity,
      mudAmount: mudAmount ?? this.mudAmount,
      lightWarmth: lightWarmth ?? this.lightWarmth,
      weatherLife: weatherLife ?? this.weatherLife,
      windLife: windLife ?? this.windLife,
      worldMotion: worldMotion ?? this.worldMotion,
      bodycamMotion: bodycamMotion ?? this.bodycamMotion,
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
        'animals': <String, Object>{
          'hippo_01': mochi.toJson(),
          'pig_01': truffle.toJson(),
          'sharpei_01': bao.toJson(),
        },
      };
}
