import 'package:flutter/material.dart';

import 'customization_state.dart';

class CustomizationSheet extends StatefulWidget {
  const CustomizationSheet({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final SanctuaryCustomization initial;
  final ValueChanged<SanctuaryCustomization> onChanged;

  @override
  State<CustomizationSheet> createState() => _CustomizationSheetState();
}

class _CustomizationSheetState extends State<CustomizationSheet> {
  late SanctuaryCustomization value;
  String animalId = 'hippo_01';

  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  void _commit(SanctuaryCustomization next) {
    setState(() => value = next);
    widget.onChanged(next);
  }

  AnimalCustomization get animal {
    if (animalId == 'pig_01') return value.truffle;
    if (animalId == 'sharpei_01') return value.bao;
    return value.mochi;
  }

  void _setAnimal(AnimalCustomization next) {
    if (animalId == 'pig_01') {
      _commit(value.copyWith(truffle: next));
    } else if (animalId == 'sharpei_01') {
      _commit(value.copyWith(bao: next));
    } else {
      _commit(value.copyWith(mochi: next));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: const Color(0xFF090E0C),
        child: DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'CUSTOMISE THE LIVING SANCTUARY',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your choices shape the world and each animal’s baseline temperament. Memory, preferences and autonomous behaviour continue to evolve on their own.',
                  style: TextStyle(color: Color(0xFFAFC0B7), height: 1.35),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'SANCTUARY',
                  children: [
                    _SliderRow(
                      label: 'Vegetation',
                      value: value.vegetationDensity,
                      onChanged: (v) => _commit(value.copyWith(vegetationDensity: v)),
                    ),
                    _SliderRow(
                      label: 'Water clarity',
                      value: value.waterClarity,
                      onChanged: (v) => _commit(value.copyWith(waterClarity: v)),
                    ),
                    _SliderRow(
                      label: 'Mud amount',
                      value: value.mudAmount,
                      onChanged: (v) => _commit(value.copyWith(mudAmount: v)),
                    ),
                    _SliderRow(
                      label: 'Lighting warmth',
                      value: value.lightWarmth,
                      onChanged: (v) => _commit(value.copyWith(lightWarmth: v)),
                    ),
                    _SliderRow(
                      label: 'Living weather',
                      value: value.weatherLife,
                      onChanged: (v) => _commit(value.copyWith(weatherLife: v)),
                    ),
                    _SliderRow(
                      label: 'Wind life',
                      value: value.windLife,
                      onChanged: (v) => _commit(value.copyWith(windLife: v)),
                    ),
                    _SliderRow(
                      label: 'World motion',
                      value: value.worldMotion,
                      onChanged: (v) => _commit(value.copyWith(worldMotion: v)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto living world'),
                      subtitle: const Text('The sanctuary continues changing by itself.'),
                      value: value.autoLivingWorld,
                      onChanged: (v) => _commit(value.copyWith(autoLivingWorld: v)),
                    ),
                  ],
                ),
                _Section(
                  title: 'INTERFACE & POV',
                  children: [
                    _SliderRow(
                      label: 'Accent',
                      value: value.accentHue,
                      onChanged: (v) => _commit(value.copyWith(accentHue: v)),
                    ),
                    _SliderRow(
                      label: 'Glass depth',
                      value: value.interfaceGlass,
                      min: 0.25,
                      onChanged: (v) => _commit(value.copyWith(interfaceGlass: v)),
                    ),
                    _SliderRow(
                      label: 'Interface scale',
                      value: (value.interfaceScale - 0.85) / 0.40,
                      onChanged: (v) => _commit(value.copyWith(interfaceScale: 0.85 + v * 0.40)),
                    ),
                    _SliderRow(
                      label: 'Bodycam motion',
                      value: value.bodycamMotion,
                      onChanged: (v) => _commit(value.copyWith(bodycamMotion: v)),
                    ),
                  ],
                ),
                _Section(
                  title: 'ANIMALS',
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'hippo_01', label: Text('MOCHI')),
                        ButtonSegment(value: 'pig_01', label: Text('TRUFFLE')),
                        ButtonSegment(value: 'sharpei_01', label: Text('BAO')),
                      ],
                      selected: {animalId},
                      onSelectionChanged: (selection) => setState(() => animalId = selection.first),
                    ),
                    const SizedBox(height: 12),
                    _SliderRow(
                      label: 'Body build',
                      value: (animal.bodyScale - 0.88) / 0.24,
                      onChanged: (v) => _setAnimal(animal.copyWith(bodyScale: 0.88 + v * 0.24)),
                    ),
                    _SliderRow(
                      label: 'Skin warmth',
                      value: animal.skinWarmth,
                      onChanged: (v) => _setAnimal(animal.copyWith(skinWarmth: v)),
                    ),
                    _SliderRow(
                      label: 'Pattern strength',
                      value: animal.patternStrength,
                      onChanged: (v) => _setAnimal(animal.copyWith(patternStrength: v)),
                    ),
                    _SliderRow(
                      label: 'Eye presence',
                      value: animal.eyeBrightness,
                      onChanged: (v) => _setAnimal(animal.copyWith(eyeBrightness: v)),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'TEMPERAMENT BIAS',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.25, color: Color(0xFF91A59A)),
                    ),
                    const SizedBox(height: 6),
                    _SliderRow(
                      label: 'Curiosity',
                      value: animal.curiosityBias,
                      onChanged: (v) => _setAnimal(animal.copyWith(curiosityBias: v)),
                    ),
                    _SliderRow(
                      label: 'Social',
                      value: animal.socialBias,
                      onChanged: (v) => _setAnimal(animal.copyWith(socialBias: v)),
                    ),
                    _SliderRow(
                      label: 'Play energy',
                      value: animal.energyBias,
                      onChanged: (v) => _setAnimal(animal.copyWith(energyBias: v)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'These sliders influence starting tendencies. They do not overwrite learned memories or force actions.',
                      style: TextStyle(color: Color(0xFF82958B), fontSize: 12),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101714),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, letterSpacing: 1.45, color: Color(0xFF9FB3A8)),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 124, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
