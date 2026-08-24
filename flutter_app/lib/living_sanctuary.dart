import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_mode.dart';
import 'customization_sheet.dart';
import 'customization_state.dart';
import 'device_time_service.dart';

Future<void> runLivingSanctuary() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const HippoOsLivingApp());
}

class HippoOsLivingApp extends StatelessWidget {
  const HippoOsLivingApp({super.key});

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
          primary: Color(0xFFE4F0E8),
          secondary: Color(0xFF99B4A5),
          surface: Color(0xFF08100D),
        ),
      ),
      home: const LivingSanctuaryScreen(),
    );
  }
}

class LivingSanctuaryScreen extends StatefulWidget {
  const LivingSanctuaryScreen({super.key});

  @override
  State<LivingSanctuaryScreen> createState() => _LivingSanctuaryScreenState();
}

class _LivingSanctuaryScreenState extends State<LivingSanctuaryScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _control = MethodChannel('hippo_os/control');
  static const EventChannel _events = EventChannel('hippo_os/events');

  final DeviceTimeService _clock = const DeviceTimeService();
  SanctuaryCameraMode _cameraMode = SanctuaryCameraMode.cinematic;
  SanctuaryCustomization _customization = const SanctuaryCustomization();
  String _selectedId = 'hippo_01';
  String _animal = 'Mochi';
  String _species = 'Pygmy Hippo';
  String _status = 'Sanctuary waking up';
  String _zone = 'Local time';
  String _worldPulse = 'Living world starting';
  String _lastCustomizationJson = '';
  double _bond = 0.0;
  double _hunger = 0.0;
  double _energy = 0.0;
  double _security = 0.0;
  bool _hudVisible = true;
  List<Map<String, dynamic>> _journal = const <Map<String, dynamic>>[];
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncClock();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncClock());
    _eventSubscription = _events.receiveBroadcastStream().listen(
      _onEngineEvent,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _eventSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _syncClock();
    }
  }

  Future<void> _syncClock() async {
    try {
      final snapshot = await _clock.snapshot();
      if (mounted) setState(() => _zone = snapshot.ianaZone);
      await _control.invokeMethod<void>('syncDeviceTime', snapshot.toEnginePayload());
    } on PlatformException {
      // Godot can attach a fraction later than Flutter during a cold launch.
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  void _onEngineEvent(dynamic event) {
    if (!mounted || event is! Map) return;

    SanctuaryCustomization? restoredCustomization;
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

    List<Map<String, dynamic>>? restoredJournal;
    final journalJson = event['journal_json'];
    if (journalJson is String && journalJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(journalJson);
        if (decoded is List) {
          restoredJournal = decoded
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (entry) => Map<String, dynamic>.fromEntries(
                  entry.entries.map<MapEntry<String, dynamic>>(
                    (item) => MapEntry<String, dynamic>('${item.key}', item.value),
                  ),
                ),
              )
              .toList(growable: false);
        }
      } on FormatException {
        restoredJournal = null;
      }
    }

    final wind = _asDouble(event['wind']);
    final humidity = _asDouble(event['humidity']);
    setState(() {
      _selectedId = '${event['selected_id'] ?? _selectedId}';
      _animal = '${event['animal_name'] ?? _animal}';
      _species = '${event['species_name'] ?? _species}';
      _status = '${event['status'] ?? _status}';
      _bond = _asDouble(event['bond']) ?? _bond;
      _hunger = _asDouble(event['hunger']) ?? _hunger;
      _energy = _asDouble(event['energy']) ?? _energy;
      _security = _asDouble(event['security']) ?? _security;
      if (restoredCustomization != null) _customization = restoredCustomization;
      if (restoredJournal != null) _journal = restoredJournal;
      if (wind != null && humidity != null) {
        _worldPulse =
            'Wind ${(wind * 100).round()}% · Humidity ${(humidity * 100).round()}%';
      }
    });
  }

  Future<void> _action(String action) =>
      _control.invokeMethod<void>('animalAction', action);

  Future<void> _selectAnimal(String animalId) => _action('select:$animalId');

  Future<void> _setCamera(SanctuaryCameraMode mode) async {
    setState(() => _cameraMode = mode);
    await _control.invokeMethod<void>('setCameraMode', mode.engineValue);
  }

  Future<void> _applyCustomization(SanctuaryCustomization value) async {
    setState(() => _customization = value);
    await _control.invokeMethod<void>('applyCustomization', value.toEnginePayload());
  }

  Future<void> _openCustomization() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomizationSheet(
        initial: _customization,
        onChanged: _applyCustomization,
      ),
    );
  }

  Future<void> _openPetting() async {
    const regions = <String, String>{
      'forehead': 'Forehead',
      'cheek': 'Cheek',
      'snout': 'Snout',
      'back': 'Back',
      'belly': 'Belly',
      'ears': 'Ears',
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'PET ${_animal.toUpperCase()}',
              style: const TextStyle(
                fontSize: 13,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Touch preferences are species-specific. Repeated unwanted contact can make an animal move away.',
              style: TextStyle(fontSize: 12, color: Color(0xFFACBDB4)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: regions.entries
                  .map<Widget>(
                    (entry) => ActionChip(
                      label: Text(entry.value),
                      onPressed: () => Navigator.of(sheetContext).pop(entry.key),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
    if (selected != null) await _action('pet:$selected');
  }

  Future<void> _openJournal() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalSheet(journal: _journal),
    );
  }

  Color get _accent => HSVColor.fromAHSV(
        1.0,
        _customization.accentHue * 360.0,
        0.34,
        0.92,
      ).toColor();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(_customization.textScale),
    );
    final double uiScale =
        _customization.interfaceScale.clamp(0.82, 1.12).toDouble();

    return MediaQuery(
      data: media,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: AndroidView(
                viewType: 'hippo_os/godot_view',
                layoutDirection: TextDirection.ltr,
              ),
            ),
            const Positioned.fill(child: _Vignette()),
            if (_hudVisible)
              Positioned.fill(
                child: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: Transform.scale(
                    scale: uiScale,
                    alignment: Alignment.center,
                    child: Stack(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topLeft,
                          child: _StatusCard(
                            animal: _animal,
                            species: _species,
                            status: _status,
                            bond: _bond,
                            hunger: _hunger,
                            energy: _energy,
                            security: _security,
                            showStats: _customization.showStats,
                            accent: _accent,
                          ),
                        ),
                        Positioned(
                          top: 105,
                          left: 0,
                          child: _AnimalSwitcher(
                            selectedId: _selectedId,
                            names: <String, String>{
                              'hippo_01': _customization.mochi.name,
                              'pig_01': _customization.truffle.name,
                              'sharpei_01': _customization.bao.name,
                            },
                            accent: _accent,
                            onSelect: _selectAnimal,
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _ClockChip(zone: _zone, pulse: _worldPulse, accent: _accent),
                              const SizedBox(width: 8),
                              _TinyButton(
                                label: 'FOCUS',
                                icon: Icons.visibility_off_outlined,
                                onPressed: () => setState(() => _hudVisible = false),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _CameraStrip(
                            selected: _cameraMode,
                            accent: _accent,
                            onSelected: _setCamera,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 58),
                            child: _ActionDock(
                              accent: _accent,
                              onFeed: () => _action('feed'),
                              onPet: _openPetting,
                              onJournal: _openJournal,
                              onCustomize: _openCustomization,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_hudVisible)
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: _TinyButton(
                    label: 'SHOW HUD',
                    icon: Icons.visibility_outlined,
                    onPressed: () => setState(() => _hudVisible = true),
                  ),
                ),
              ),
            if (_cameraMode == SanctuaryCameraMode.bodycam && _hudVisible)
              const Positioned(
                right: 18,
                top: 104,
                child: SafeArea(child: _BodycamBadge()),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.animal,
    required this.species,
    required this.status,
    required this.bond,
    required this.hunger,
    required this.energy,
    required this.security,
    required this.showStats,
    required this.accent,
  });

  final String animal;
  final String species;
  final String status;
  final double bond;
  final double hunger;
  final double energy;
  final double security;
  final bool showStats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 405,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: _glass(accent, 0.65, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                'HIPPO OS · LIVE',
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  letterSpacing: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$animal · $species',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, height: 1.05),
          ),
          const SizedBox(height: 3),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFFC5D1CA)),
          ),
          if (showStats) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _MiniStat(label: 'BOND', value: bond, accent: accent),
                _MiniStat(label: 'ENERGY', value: energy, accent: accent),
                _MiniStat(label: 'SAFE', value: security, accent: accent),
                _MiniStat(label: 'FED', value: 1.0 - hunger, accent: accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.accent});
  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final double safeValue = value.clamp(0.0, 1.0).toDouble();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF82958B))),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: safeValue,
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
    required this.names,
    required this.accent,
    required this.onSelect,
  });
  final String selectedId;
  final Map<String, String> names;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _glass(accent, 0.56, 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: names.entries
            .map<Widget>(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(entry.value, style: const TextStyle(fontSize: 10)),
                  selected: selectedId == entry.key,
                  onSelected: (_) => onSelect(entry.key),
                  showCheckmark: false,
                  selectedColor: accent,
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    color: selectedId == entry.key
                        ? const Color(0xFF06100B)
                        : const Color(0xFFD2DDD7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.zone, required this.pulse, required this.accent});
  final String zone;
  final String pulse;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: _glass(accent, 0.56, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(zone, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(pulse, style: const TextStyle(fontSize: 8, color: Color(0xFF93A79B))),
        ],
      ),
    );
  }
}

class _CameraStrip extends StatelessWidget {
  const _CameraStrip({required this.selected, required this.accent, required this.onSelected});
  final SanctuaryCameraMode selected;
  final Color accent;
  final ValueChanged<SanctuaryCameraMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: _glass(accent, 0.69, 16),
      child: Row(
        children: SanctuaryCameraMode.values
            .map<Widget>(
              (mode) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: () => onSelected(mode),
                    style: TextButton.styleFrom(
                      backgroundColor: selected == mode ? accent : Colors.transparent,
                      foregroundColor: selected == mode
                          ? const Color(0xFF06100B)
                          : const Color(0xFFC6D1CB),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: Text(
                      mode.label,
                      style: const TextStyle(fontSize: 9, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.accent,
    required this.onFeed,
    required this.onPet,
    required this.onJournal,
    required this.onCustomize,
  });
  final Color accent;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onJournal;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _glass(accent, 0.64, 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _DockIcon(icon: Icons.restaurant_rounded, tooltip: 'Feed', onPressed: onFeed),
          _DockIcon(icon: Icons.pan_tool_alt_outlined, tooltip: 'Pet', onPressed: onPet),
          _DockIcon(icon: Icons.auto_stories_outlined, tooltip: 'Journal', onPressed: onJournal),
          _DockIcon(icon: Icons.tune_rounded, tooltip: 'Customise', onPressed: onCustomize),
        ],
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      color: const Color(0xFFE0E9E4),
    );
  }
}

class _TinyButton extends StatelessWidget {
  const _TinyButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 8, letterSpacing: 0.7)),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFD2DCD7),
        backgroundColor: const Color(0xA8070E0C),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
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
        color: const Color(0xB3070D0B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.circle, size: 7, color: Color(0xFFE45C50)),
          SizedBox(width: 6),
          Text('BODYCAM', style: TextStyle(fontSize: 9, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.20),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.26),
            ],
            stops: const <double>[0.0, 0.54, 1.0],
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
    return _SheetCard(
      heightFactor: 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'SANCTUARY JOURNAL',
            style: TextStyle(fontSize: 13, letterSpacing: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'Moments the sanctuary remembers.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9FB2A7)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: journal.isEmpty
                ? const Center(
                    child: Text(
                      'The story is just beginning.',
                      style: TextStyle(color: Color(0xFFA8B9B0)),
                    ),
                  )
                : ListView.separated(
                    itemCount: journal.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 18),
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
                        children: <Widget>[
                          SizedBox(
                            width: 52,
                            child: Text(
                              stamp,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF789087)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${event['text'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFD4DED9)),
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

class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.child, this.heightFactor});
  final Widget child;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    final double? height = heightFactor == null
        ? null
        : MediaQuery.sizeOf(context).height * heightFactor!;
    return Container(
      height: height,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xF2070E0C),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white12),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xAA000000), blurRadius: 28),
        ],
      ),
      child: child,
    );
  }
}

BoxDecoration _glass(Color accent, double alpha, double radius) {
  return BoxDecoration(
    color: const Color(0xFF07100D).withValues(alpha: alpha),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: 0.18)),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x55000000), blurRadius: 18),
    ],
  );
}
