import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_mode.dart';
import 'customization_sheet.dart';
import 'customization_state.dart';
import 'device_time_service.dart';

Future<void> runHippoOs() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const HippoOsAppV2());
}

class HippoOsAppV2 extends StatelessWidget {
  const HippoOsAppV2({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hippo OS',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF020605),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE6F1E9),
          secondary: Color(0xFF9AB8A7),
          surface: Color(0xFF09100E),
        ),
      ),
      home: const SanctuaryScreenV2(),
    );
  }
}

class SanctuaryScreenV2 extends StatefulWidget {
  const SanctuaryScreenV2({super.key});

  @override
  State<SanctuaryScreenV2> createState() => _SanctuaryScreenV2State();
}

class _SanctuaryScreenV2State extends State<SanctuaryScreenV2>
    with WidgetsBindingObserver {
  static const _control = MethodChannel('hippo_os/control');
  static const _events = EventChannel('hippo_os/events');
  final _clock = const DeviceTimeService();

  SanctuaryCameraMode _cameraMode = SanctuaryCameraMode.cinematic;
  SanctuaryCustomization _customization = const SanctuaryCustomization();
  String _animal = 'Mochi';
  String _species = 'Pygmy Hippo';
  String _status = 'Sanctuary waking up';
  String _selectedId = 'hippo_01';
  String _zone = 'LOCAL TIME';
  String _worldPulse = 'Living world starting';
  String _lastCustomizationJson = '';
  double _bond = 0.0;
  double _hunger = 0.0;
  double _energy = 0.0;
  double _security = 0.0;
  bool _hudVisible = true;
  List<Map<String, dynamic>> _journal = const [];
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _clockSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncRealTime();
    _clockSyncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _syncRealTime(),
    );
    _eventSubscription = _events.receiveBroadcastStream().listen(
      _handleEngineEvent,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _clockSyncTimer?.cancel();
    _eventSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _syncRealTime();
    }
  }

  Future<void> _syncRealTime() async {
    try {
      final snapshot = await _clock.snapshot();
      if (mounted) setState(() => _zone = snapshot.ianaZone);
      await _control.invokeMethod('syncDeviceTime', snapshot.toEnginePayload());
    } on PlatformException {
      // The Godot host attaches immediately after Flutter is ready.
    }
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  void _handleEngineEvent(dynamic event) {
    if (event is! Map || !mounted) return;
    final wind = _number(event['wind']);
    final humidity = _number(event['humidity']);
    SanctuaryCustomization? restoredCustomization;
    List<Map<String, dynamic>>? restoredJournal;

    final customizationJson = event['customization_json'];
    if (customizationJson is String &&
        customizationJson.isNotEmpty &&
        customizationJson != _lastCustomizationJson) {
      try {
        restoredCustomization = SanctuaryCustomization.fromEnginePayload(
          jsonDecode(customizationJson),
        );
        _lastCustomizationJson = customizationJson;
      } on FormatException {
        restoredCustomization = null;
      }
    }

    final journalJson = event['journal_json'];
    if (journalJson is String && journalJson.isNotEmpty) {
      try {
        final parsed = jsonDecode(journalJson);
        if (parsed is List) {
          restoredJournal = parsed
              .whereType<Map>()
              .map((entry) => entry.map(
                    (key, value) => MapEntry('$key', value),
                  ))
              .toList(growable: false);
        }
      } on FormatException {
        restoredJournal = null;
      }
    }

    setState(() {
      _animal = '${event['animal_name'] ?? _animal}';
      _species = '${event['species_name'] ?? _species}';
      _status = '${event['status'] ?? _status}';
      _selectedId = '${event['selected_id'] ?? _selectedId}';
      _bond = _number(event['bond']) ?? _bond;
      _hunger = _number(event['hunger']) ?? _hunger;
      _energy = _number(event['energy']) ?? _energy;
      _security = _number(event['security']) ?? _security;
      if (restoredCustomization != null) {
        _customization = restoredCustomization;
      }
      if (restoredJournal != null) {
        _journal = restoredJournal;
      }
      if (wind != null && humidity != null) {
        _worldPulse =
            'Wind ${(wind * 100).round()}%  ·  Humidity ${(humidity * 100).round()}%';
      }
    });
  }

  Future<void> _setCamera(SanctuaryCameraMode mode) async {
    setState(() => _cameraMode = mode);
    await _control.invokeMethod('setCameraMode', mode.engineValue);
  }

  Future<void> _action(String action) async {
    await _control.invokeMethod('animalAction', action);
  }

  Future<void> _selectAnimal(String id) async {
    await _action('select:$id');
  }

  Future<void> _applyCustomization(SanctuaryCustomization next) async {
    setState(() => _customization = next);
    await _control.invokeMethod('applyCustomization', next.toEnginePayload());
  }

  Future<void> _openCustomization() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomizationSheet(
        initial: _customization,
        onChanged: _applyCustomization,
      ),
    );
  }

  Future<void> _openPetMenu() async {
    const regions = <(String, String)>[
      ('forehead', 'Forehead'),
      ('cheek', 'Cheek'),
      ('snout', 'Snout'),
      ('back', 'Back'),
      ('belly', 'Belly'),
      ('ears', 'Ears'),
    ];
    final region = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BottomCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHERE DO YOU PET $_animal?'.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.4,
                color: Color(0xFF9CB3A6),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Each animal has its own touch preferences and can move away if it does not want contact.',
              style: TextStyle(color: Color(0xFFC8D3CD)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final region in regions)
                  ActionChip(
                    label: Text(region.$2),
                    onPressed: () => Navigator.of(context).pop(region.$1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (region != null) await _action('pet:$region');
  }

  Future<void> _openJournal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalSheet(journal: _journal),
    );
  }

  Color get _accent => HSVColor.fromAHSV(
        1,
        _customization.accentHue * 360,
        0.34,
        0.92,
      ).toColor();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(_customization.textScale),
    );
    return MediaQuery(
      data: media,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: AndroidView(
                viewType: 'hippo_os/godot_view',
                layoutDirection: TextDirection.ltr,
              ),
            ),
            const Positioned.fill(child: _WorldVignette()),
            if (_hudVisible)
              Positioned.fill(
                child: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: _Hud(
                    animal: _animal,
                    species: _species,
                    status: _status,
                    selectedId: _selectedId,
                    zone: _zone,
                    worldPulse: _worldPulse,
                    bond: _bond,
                    hunger: _hunger,
                    energy: _energy,
                    security: _security,
                    cameraMode: _cameraMode,
                    accent: _accent,
                    customization: _customization,
                    onSelectAnimal: _selectAnimal,
                    onCamera: _setCamera,
                    onFeed: () => _action('feed'),
                    onPet: _openPetMenu,
                    onJournal: _openJournal,
                    onCustomize: _openCustomization,
                    onFocus: () => setState(() => _hudVisible = false),
                  ),
                ),
              ),
            if (!_hudVisible)
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: _FocusButton(
                    label: 'SHOW HUD',
                    icon: Icons.visibility_outlined,
                    onTap: () => setState(() => _hudVisible = true),
                  ),
                ),
              ),
            if (_cameraMode == SanctuaryCameraMode.bodycam && _hudVisible)
              const Positioned(
                top: 112,
                right: 18,
                child: SafeArea(child: _BodycamBadge()),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.animal,
    required this.species,
    required this.status,
    required this.selectedId,
    required this.zone,
    required this.worldPulse,
    required this.bond,
    required this.hunger,
    required this.energy,
    required this.security,
    required this.cameraMode,
    required this.accent,
    required this.customization,
    required this.onSelectAnimal,
    required this.onCamera,
    required this.onFeed,
    required this.onPet,
    required this.onJournal,
    required this.onCustomize,
    required this.onFocus,
  });

  final String animal;
  final String species;
  final String status;
  final String selectedId;
  final String zone;
  final String worldPulse;
  final double bond;
  final double hunger;
  final double energy;
  final double security;
  final SanctuaryCameraMode cameraMode;
  final Color accent;
  final SanctuaryCustomization customization;
  final ValueChanged<String> onSelectAnimal;
  final ValueChanged<SanctuaryCameraMode> onCamera;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onJournal;
  final VoidCallback onCustomize;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 650;
    final scale = customization.interfaceScale.clamp(0.82, 1.12);
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: _AnimalStatusCard(
              animal: animal,
              species: species,
              status: status,
              bond: bond,
              hunger: hunger,
              energy: energy,
              security: security,
              accent: accent,
              showStats: customization.showStats,
              compact: compact,
            ),
          ),
        ),
        Positioned(
          top: compact ? 96 : 112,
          left: 0,
          child: _AnimalSwitcher(
            selectedId: selectedId,
            mochi: customization.mochi.name,
            truffle: customization.truffle.name,
            bao: customization.bao.name,
            accent: accent,
            onSelect: onSelectAnimal,
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ClockChip(zone: zone, pulse: worldPulse),
              const SizedBox(width: 8),
              _FocusButton(
                label: 'FOCUS',
                icon: Icons.visibility_off_outlined,
                onTap: onFocus,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _CameraStrip(
              selected: cameraMode,
              onSelected: onCamera,
              accent: accent,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 62),
            child: _ActionRail(
              onFeed: onFeed,
              onPet: onPet,
              onJournal: onJournal,
              onCustomize: onCustomize,
              accent: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimalStatusCard extends StatelessWidget {
  const _AnimalStatusCard({
    required this.animal,
    required this.species,
    required this.status,
    required this.bond,
    required this.hunger,
    required this.energy,
    required this.security,
    required this.accent,
    required this.showStats,
    required this.compact,
  });

  final String animal;
  final String species;
  final String status;
  final double bond;
  final double hunger;
  final double energy;
  final double security;
  final Color accent;
  final bool showStats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 360 : 410,
      padding: EdgeInsets.fromLTRB(15, compact ? 10 : 12, 15, compact ? 9 : 11),
      decoration: _glassDecoration(accent, 0.68, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                'HIPPO OS  ·  LIVE',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$animal  ·  $species',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 20 : 23,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFFC4D0C9)),
          ),
          if (showStats) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(label: 'BOND', value: bond, accent: accent),
                _MiniStat(label: 'ENERGY', value: energy, accent: accent),
                _MiniStat(label: 'SAFE', value: security, accent: accent),
                _MiniStat(label: 'HUNGER', value: hunger, accent: accent, invert: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.accent,
    this.invert = false,
  });

  final String label;
  final double value;
  final Color accent;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final display = (invert ? 1.0 - value : value).clamp(0.0, 1.0);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF82958B))),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: display,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalSwitcher extends StatelessWidget {
  const _AnimalSwitcher({
    required this.selectedId,
    required this.mochi,
    required this.truffle,
    required this.bao,
    required this.accent,
    required this.onSelect,
  });

  final String selectedId;
  final String mochi;
  final String truffle;
  final String bao;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final animals = <(String, String)>[
      ('hippo_01', mochi),
      ('pig_01', truffle),
      ('sharpei_01', bao),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _glassDecoration(accent, 0.58, 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final animal in animals)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Text(animal.$2, style: const TextStyle(fontSize: 10)),
                selected: selectedId == animal.$1,
                onSelected: (_) => onSelect(animal.$1),
                showCheckmark: false,
                selectedColor: accent,
                backgroundColor: Colors.transparent,
                labelStyle: TextStyle(
                  color: selectedId == animal.$1 ? const Color(0xFF06100B) : const Color(0xFFD3DDD7),
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.zone, required this.pulse});
  final String zone;
  final String pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: _glassDecoration(const Color(0xFF98B4A4), 0.58, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(zone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(pulse, style: const TextStyle(fontSize: 9, color: Color(0xFF93A79B))),
        ],
      ),
    );
  }
}

class _CameraStrip extends StatelessWidget {
  const _CameraStrip({required this.selected, required this.onSelected, required this.accent});
  final SanctuaryCameraMode selected;
  final ValueChanged<SanctuaryCameraMode> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: _glassDecoration(accent, 0.70, 17),
      child: Row(
        children: [
          for (final mode in SanctuaryCameraMode.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  onPressed: () => onSelected(mode),
                  style: TextButton.styleFrom(
                    backgroundColor: selected == mode ? accent : Colors.transparent,
                    foregroundColor: selected == mode ? const Color(0xFF06100B) : const Color(0xFFC7D2CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(mode.label, style: const TextStyle(fontSize: 10, letterSpacing: 0.55)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.onFeed,
    required this.onPet,
    required this.onJournal,
    required this.onCustomize,
    required this.accent,
  });
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onJournal;
  final VoidCallback onCustomize;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: _glassDecoration(accent, 0.66, 17),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(icon: Icons.restaurant_rounded, label: 'FEED', onTap: onFeed),
          _IconAction(icon: Icons.pan_tool_alt_outlined, label: 'PET', onTap: onPet),
          _IconAction(icon: Icons.auto_stories_outlined, label: 'JOURNAL', onTap: onJournal),
          _IconAction(icon: Icons.tune_rounded, label: 'CUSTOM', onTap: onCustomize),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFFE1EAE5),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _FocusButton extends StatelessWidget {
  const _FocusButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 0.8)),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD1DCD6),
        backgroundColor: const Color(0xA80A100E),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _BodycamBadge extends StatelessWidget {
  const _BodycamBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xB80B0F0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Color(0xFFE4584C)),
          SizedBox(width: 6),
          Text('BODYCAM', style: TextStyle(fontSize: 9, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _WorldVignette extends StatelessWidget {
  const _WorldVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.24),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.30),
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
        ),
      ),
    );
  }
}

class _JournalSheet extends StatelessWidget {
  const _JournalSheet({required this.journal});
  final List<Map<String, dynamic>> journal;

  @override
  Widget build(BuildContext context) {
    return _BottomCard(
      heightFactor: 0.74,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SANCTUARY JOURNAL',
            style: TextStyle(fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Moments the sanctuary remembers.',
            style: TextStyle(color: Color(0xFF9EB1A6)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: journal.isEmpty
                ? const Center(
                    child: Text(
                      'The story is just beginning.',
                      style: TextStyle(color: Color(0xFFA9BBB1)),
                    ),
                  )
                : ListView.separated(
                    itemCount: journal.length,
                    separatorBuilder: (_, __) => const Divider(height: 18, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final event = journal[index];
                      final unix = (event['unix'] as num?)?.toInt() ?? 0;
                      final time = unix > 0
                          ? DateTime.fromMillisecondsSinceEpoch(unix * 1000).toLocal()
                          : null;
                      final stamp = time == null
                          ? ''
                          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 54,
                            child: Text(stamp, style: const TextStyle(fontSize: 10, color: Color(0xFF789087))),
                          ),
                          Expanded(
                            child: Text(
                              '${event['text'] ?? ''}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFFD5DFDA)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.child, this.heightFactor});
  final Widget child;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      height: heightFactor == null ? null : height * heightFactor!,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xF20A100E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 28)],
      ),
      child: child,
    );
  }
}

BoxDecoration _glassDecoration(Color accent, double alpha, double radius) {
  return BoxDecoration(
    color: const Color(0xFF07100D).withValues(alpha: alpha),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: 0.18)),
    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18)],
  );
}
