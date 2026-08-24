import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_mode.dart';
import 'customization_sheet.dart';
import 'customization_state.dart';
import 'device_time_service.dart';

Future<void> runOpenWorldApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const HippoOsOpenWorldApp());
}

class HippoOsOpenWorldApp extends StatelessWidget {
  const HippoOsOpenWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hippo OS',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE7EFEA),
          secondary: Color(0xFF98B6A5),
          surface: Color(0xFF09100D),
        ),
      ),
      home: const OpenWorldSanctuaryScreen(),
    );
  }
}

class OpenWorldSanctuaryScreen extends StatefulWidget {
  const OpenWorldSanctuaryScreen({super.key});

  @override
  State<OpenWorldSanctuaryScreen> createState() => _OpenWorldSanctuaryScreenState();
}

class _OpenWorldSanctuaryScreenState extends State<OpenWorldSanctuaryScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _control = MethodChannel('hippo_os/control');
  static const EventChannel _events = EventChannel('hippo_os/events');

  final DeviceTimeService _clock = const DeviceTimeService();
  SanctuaryCameraMode _camera = SanctuaryCameraMode.caretaker;
  SanctuaryCustomization _customization = const SanctuaryCustomization();
  StreamSubscription<dynamic>? _eventsSub;
  Timer? _clockTimer;

  String _selectedId = 'hippo_01';
  String _animal = 'Mochi';
  String _species = 'Pygmy Hippo';
  String _status = 'Exploring the sanctuary';
  String _zone = 'Local';
  String _worldPulse = 'Living world';
  String _hint = '';
  String _lastCustomizationJson = '';
  bool _hudVisible = true;
  bool _canInteract = true;

  double _bond = 0;
  double _hunger = 0;
  double _energy = 0;
  double _security = 0;
  double _playerX = 0;
  double _playerZ = 10;
  double _playerYaw = 0;
  double _worldHalfX = 46;
  double _worldHalfZ = 30;
  double _hippoX = 1;
  double _hippoZ = 6;
  double _pigX = -17;
  double _pigZ = -5;
  double _dogX = 17;
  double _dogZ = -4;
  double _selectedDistance = 0;
  List<Map<String, dynamic>> _journal = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncClock();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncClock());
    _eventsSub = _events.receiveBroadcastStream().listen(_onEngineEvent, onError: (_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setCamera(SanctuaryCameraMode.caretaker);
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _clockTimer?.cancel();
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

  double _number(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  Future<void> _syncClock() async {
    try {
      final snapshot = await _clock.snapshot();
      if (mounted) setState(() => _zone = snapshot.ianaZone);
      await _control.invokeMethod<void>('syncDeviceTime', snapshot.toEnginePayload());
    } on PlatformException {
      // The embedded engine may attach a fraction after Flutter during cold launch.
    }
  }

  void _onEngineEvent(dynamic raw) {
    if (!mounted || raw is! Map) return;

    SanctuaryCustomization? restored;
    final customizationJson = raw['customization_json'];
    if (customizationJson is String &&
        customizationJson.isNotEmpty &&
        customizationJson != _lastCustomizationJson) {
      try {
        restored = SanctuaryCustomization.fromEnginePayload(jsonDecode(customizationJson));
        _lastCustomizationJson = customizationJson;
      } on FormatException {
        restored = null;
      }
    }

    List<Map<String, dynamic>>? journal;
    final journalJson = raw['journal_json'];
    if (journalJson is String && journalJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(journalJson);
        if (decoded is List) {
          journal = decoded
              .whereType<Map>()
              .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
              .cast<Map<String, dynamic>>()
              .toList(growable: false);
        }
      } on FormatException {
        journal = null;
      }
    }

    final wind = _number(raw['wind'], 0.0);
    final humidity = _number(raw['humidity'], 0.0);
    setState(() {
      _selectedId = '${raw['selected_id'] ?? _selectedId}';
      _animal = '${raw['animal_name'] ?? _animal}';
      _species = '${raw['species_name'] ?? _species}';
      _status = '${raw['status'] ?? _status}';
      _hint = '${raw['interaction_hint'] ?? ''}';
      _bond = _number(raw['bond'], _bond);
      _hunger = _number(raw['hunger'], _hunger);
      _energy = _number(raw['energy'], _energy);
      _security = _number(raw['security'], _security);
      _playerX = _number(raw['roam_x'], _playerX);
      _playerZ = _number(raw['roam_z'], _playerZ);
      _playerYaw = _number(raw['roam_yaw'], _playerYaw);
      _worldHalfX = _number(raw['world_half_x'], _worldHalfX);
      _worldHalfZ = _number(raw['world_half_z'], _worldHalfZ);
      _hippoX = _number(raw['hippo_x'], _hippoX);
      _hippoZ = _number(raw['hippo_z'], _hippoZ);
      _pigX = _number(raw['pig_x'], _pigX);
      _pigZ = _number(raw['pig_z'], _pigZ);
      _dogX = _number(raw['dog_x'], _dogX);
      _dogZ = _number(raw['dog_z'], _dogZ);
      _selectedDistance = _number(raw['selected_distance'], _selectedDistance);
      _canInteract = raw['can_interact'] is bool ? raw['can_interact'] as bool : _canInteract;
      if (restored != null) _customization = restored;
      if (journal != null) _journal = journal;
      _worldPulse = 'Wind ${(wind * 100).round()}% · Humidity ${(humidity * 100).round()}%';
    });
  }

  Future<void> _action(String value) =>
      _control.invokeMethod<void>('animalAction', value);

  Future<void> _setCamera(SanctuaryCameraMode mode) async {
    setState(() => _camera = mode);
    await _control.invokeMethod<void>('setCameraMode', mode.engineValue);
  }

  Future<void> _select(String animalId) => _action('select:$animalId');

  void _move(Offset vector) {
    _action('roam:${vector.dx.toStringAsFixed(3)}:${vector.dy.toStringAsFixed(3)}');
  }

  void _stopMove() => _action('roam_stop');

  void _look(Offset delta) {
    if (_camera != SanctuaryCameraMode.bodycam &&
        _camera != SanctuaryCameraMode.caretaker) {
      return;
    }
    _action('look:${delta.dx.toStringAsFixed(2)}:${delta.dy.toStringAsFixed(2)}');
  }

  Future<void> _openPet() async {
    const regions = <String, String>{
      'forehead': 'Forehead',
      'cheek': 'Cheek',
      'snout': 'Snout',
      'back': 'Back',
      'belly': 'Belly',
      'ears': 'Ears',
    };
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => _DarkSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('TOUCH ${_animal.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            const Text('Preferences are individual. They can accept the touch or move away.',
                style: TextStyle(fontSize: 12, color: Color(0xFFA9B8B0))),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: regions.entries
                  .map((entry) => ActionChip(
                        label: Text(entry.value),
                        onPressed: () => Navigator.of(sheetContext).pop(entry.key),
                      ))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) await _action('pet:$chosen');
  }

  Future<void> _openJournal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DarkSheet(
        heightFactor: 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('SANCTUARY JOURNAL',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            const Text('Moments the sanctuary remembers.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9EB0A6))),
            const SizedBox(height: 12),
            Expanded(
              child: _journal.isEmpty
                  ? const Center(child: Text('The story is just beginning.'))
                  : ListView.separated(
                      itemCount: _journal.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (context, index) {
                        final item = _journal[index];
                        return Text('${item['text'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFD7E0DB)));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomization() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomizationSheet(
        initial: _customization,
        onChanged: (value) async {
          setState(() => _customization = value);
          await _control.invokeMethod<void>('applyCustomization', value.toEnginePayload());
        },
      ),
    );
  }

  Color get _accent => HSVColor.fromAHSV(
        1,
        _customization.accentHue * 360,
        0.34,
        0.95,
      ).toColor();

  bool get _freeRoam =>
      _camera == SanctuaryCameraMode.bodycam || _camera == SanctuaryCameraMode.caretaker;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(_customization.textScale),
    );
    return MediaQuery(
      data: scaled,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: AndroidView(
                viewType: 'hippo_os/godot_view',
                layoutDirection: TextDirection.ltr,
              ),
            ),
            if (_freeRoam)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) => _look(details.delta),
                ),
              ),
            const Positioned.fill(child: IgnorePointer(child: _EdgeVignette())),
            if (_hudVisible)
              SafeArea(
                minimum: const EdgeInsets.all(10),
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topLeft,
                      child: _AnimalStatus(
                        animal: _animal,
                        species: _species,
                        status: _status,
                        bond: _bond,
                        energy: _energy,
                        security: _security,
                        fed: 1 - _hunger,
                        accent: _accent,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 102,
                      child: _AnimalSelector(
                        selectedId: _selectedId,
                        names: <String, String>{
                          'hippo_01': _customization.mochi.name,
                          'pig_01': _customization.truffle.name,
                          'sharpei_01': _customization.bao.name,
                        },
                        accent: _accent,
                        onSelect: _select,
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _WorldMap(
                            player: Offset(_playerX, _playerZ),
                            yaw: _playerYaw,
                            hippo: Offset(_hippoX, _hippoZ),
                            pig: Offset(_pigX, _pigZ),
                            dog: Offset(_dogX, _dogZ),
                            halfX: _worldHalfX,
                            halfZ: _worldHalfZ,
                            selectedId: _selectedId,
                            accent: _accent,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              _InfoChip(title: _zone, subtitle: _worldPulse),
                              const SizedBox(height: 6),
                              _MiniButton(
                                icon: Icons.visibility_off_outlined,
                                label: 'FOCUS',
                                onPressed: () => setState(() => _hudVisible = false),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_freeRoam)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _Joystick(
                            accent: _accent,
                            onChanged: _move,
                            onEnd: _stopMove,
                            onSprint: (enabled) => _action('sprint:${enabled ? 1 : 0}'),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _CameraBar(
                        current: _camera,
                        accent: _accent,
                        onChanged: _setCamera,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ActionRail(
                        accent: _accent,
                        distance: _selectedDistance,
                        canInteract: _canInteract || !_freeRoam,
                        onFeed: () => _action('feed'),
                        onPet: _openPet,
                        onJournal: _openJournal,
                        onCustomize: _openCustomization,
                      ),
                    ),
                    if (_hint.isNotEmpty)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 58),
                          child: _HintChip(text: _hint),
                        ),
                      ),
                    if (_camera == SanctuaryCameraMode.bodycam)
                      const Positioned(
                        left: 12,
                        bottom: 150,
                        child: _BodycamTag(),
                      ),
                  ],
                ),
              ),
            if (!_hudVisible)
              Positioned(
                right: 12,
                top: 12,
                child: SafeArea(
                  child: _MiniButton(
                    icon: Icons.visibility_outlined,
                    label: 'HUD',
                    onPressed: () => setState(() => _hudVisible = true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimalStatus extends StatelessWidget {
  const _AnimalStatus({
    required this.animal,
    required this.species,
    required this.status,
    required this.bond,
    required this.energy,
    required this.security,
    required this.fed,
    required this.accent,
  });

  final String animal;
  final String species;
  final String status;
  final double bond;
  final double energy;
  final double security;
  final double fed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: _glass(accent, 0.58, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            const Text('HIPPO OS · LIVE', style: TextStyle(fontSize: 8, letterSpacing: 1.3)),
          ]),
          const SizedBox(height: 4),
          Text('$animal · $species',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFB8C7BF))),
          const SizedBox(height: 7),
          Row(children: <Widget>[
            _Bar(value: bond, icon: Icons.favorite_rounded, accent: accent),
            _Bar(value: energy, icon: Icons.bolt_rounded, accent: accent),
            _Bar(value: security, icon: Icons.shield_outlined, accent: accent),
            _Bar(value: fed, icon: Icons.restaurant_rounded, accent: accent),
          ]),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.icon, required this.accent});
  final double value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Row(children: <Widget>[
          Icon(icon, size: 10, color: accent),
          const SizedBox(width: 3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1).toDouble(),
                minHeight: 3,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AnimalSelector extends StatelessWidget {
  const _AnimalSelector({required this.selectedId, required this.names, required this.accent, required this.onSelect});
  final String selectedId;
  final Map<String, String> names;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: _glass(accent, 0.48, 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: names.entries.map((entry) {
          final selected = entry.key == selectedId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextButton(
              onPressed: () => onSelect(entry.key),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                backgroundColor: selected ? accent : Colors.transparent,
                foregroundColor: selected ? const Color(0xFF07100D) : const Color(0xFFD5DED9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              child: Text(entry.value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _WorldMap extends StatelessWidget {
  const _WorldMap({
    required this.player,
    required this.yaw,
    required this.hippo,
    required this.pig,
    required this.dog,
    required this.halfX,
    required this.halfZ,
    required this.selectedId,
    required this.accent,
  });
  final Offset player;
  final double yaw;
  final Offset hippo;
  final Offset pig;
  final Offset dog;
  final double halfX;
  final double halfZ;
  final String selectedId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      height: 142,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0x9A06100C),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x66000000), blurRadius: 18)],
      ),
      child: CustomPaint(
        painter: _MapPainter(
          player: player,
          yaw: yaw,
          hippo: hippo,
          pig: pig,
          dog: dog,
          halfX: halfX,
          halfZ: halfZ,
          selectedId: selectedId,
          accent: accent,
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.player,
    required this.yaw,
    required this.hippo,
    required this.pig,
    required this.dog,
    required this.halfX,
    required this.halfZ,
    required this.selectedId,
    required this.accent,
  });
  final Offset player;
  final double yaw;
  final Offset hippo;
  final Offset pig;
  final Offset dog;
  final double halfX;
  final double halfZ;
  final String selectedId;
  final Color accent;

  Offset mapPoint(Offset world, Size size) {
    final x = ((world.dx / halfX).clamp(-1.0, 1.0) + 1) * size.width * 0.5;
    final y = ((world.dy / halfZ).clamp(-1.0, 1.0) + 1) * size.height * 0.5;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.shortestSide / 2, Paint()..color = const Color(0xAA17271B));
    canvas.drawCircle(center, size.shortestSide * 0.34, Paint()..color = const Color(0x552A5A38));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.47, 0)
        ..quadraticBezierTo(size.width * 0.58, size.height * 0.40, size.width * 0.50, size.height),
      Paint()
        ..color = const Color(0xAA2C7375)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );

    void animal(Offset point, String id, Color color) {
      final p = mapPoint(point, size);
      final selected = id == selectedId;
      if (selected) canvas.drawCircle(p, 7, Paint()..color = accent.withValues(alpha: 0.35));
      canvas.drawCircle(p, selected ? 4.5 : 3.7, Paint()..color = color);
    }

    animal(hippo, 'hippo_01', const Color(0xFFD1A4B1));
    animal(pig, 'pig_01', const Color(0xFFE7B69B));
    animal(dog, 'sharpei_01', const Color(0xFFD8A65F));

    final p = mapPoint(player, size);
    final heading = Offset(-math.sin(yaw), -math.cos(yaw));
    final tip = p + heading * 8;
    final left = p + Offset(-heading.dy, heading.dx) * 4 - heading * 3;
    final right = p - Offset(-heading.dy, heading.dx) * 4 - heading * 3;
    canvas.drawPath(
      Path()..moveTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)..lineTo(right.dx, right.dy)..close(),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(center, size.shortestSide / 2 - 2, Paint()..color = Colors.white10..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}

class _Joystick extends StatefulWidget {
  const _Joystick({required this.accent, required this.onChanged, required this.onEnd, required this.onSprint});
  final Color accent;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onEnd;
  final ValueChanged<bool> onSprint;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset knob = Offset.zero;
  static const radius = 52.0;

  void update(Offset local) {
    final center = const Offset(radius, radius);
    var delta = local - center;
    if (delta.distance > radius * 0.72) {
      delta = Offset.fromDirection(delta.direction, radius * 0.72);
    }
    setState(() => knob = delta);
    widget.onChanged(Offset(delta.dx / (radius * 0.72), delta.dy / (radius * 0.72)));
  }

  void stop() {
    setState(() => knob = Offset.zero);
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        GestureDetector(
          onPanStart: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          onPanEnd: (_) => stop(),
          onPanCancel: stop,
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x59040A08),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              children: <Widget>[
                const Center(child: Icon(Icons.add, color: Colors.white24, size: 62)),
                Positioned(
                  left: radius - 20 + knob.dx,
                  top: radius - 20 + knob.dy,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent.withValues(alpha: 0.28),
                      border: Border.all(color: widget.accent.withValues(alpha: 0.72)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 7),
        GestureDetector(
          onLongPressStart: (_) => widget.onSprint(true),
          onLongPressEnd: (_) => widget.onSprint(false),
          child: Container(
            width: 42,
            height: 42,
            decoration: _glass(widget.accent, 0.52, 14),
            child: const Icon(Icons.directions_run_rounded, size: 20),
          ),
        ),
      ],
    );
  }
}

class _CameraBar extends StatelessWidget {
  const _CameraBar({required this.current, required this.accent, required this.onChanged});
  final SanctuaryCameraMode current;
  final Color accent;
  final ValueChanged<SanctuaryCameraMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 390,
      padding: const EdgeInsets.all(3),
      decoration: _glass(accent, 0.55, 15),
      child: Row(
        children: SanctuaryCameraMode.values.map((mode) {
          final active = mode == current;
          return Expanded(
            child: TextButton(
              onPressed: () => onChanged(mode),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: active ? accent : Colors.transparent,
                foregroundColor: active ? const Color(0xFF07100D) : Colors.white70,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              child: Text(mode.label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.accent,
    required this.distance,
    required this.canInteract,
    required this.onFeed,
    required this.onPet,
    required this.onJournal,
    required this.onCustomize,
  });
  final Color accent;
  final double distance;
  final bool canInteract;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onJournal;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _glass(accent, 0.54, 17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _RailButton(icon: Icons.restaurant_rounded, label: 'FEED', onPressed: onFeed, active: canInteract),
          _RailButton(icon: Icons.pan_tool_alt_outlined, label: 'PET', onPressed: onPet, active: canInteract),
          _RailButton(icon: Icons.auto_stories_outlined, label: 'JOURNAL', onPressed: onJournal),
          _RailButton(icon: Icons.tune_rounded, label: 'CUSTOM', onPressed: onCustomize),
          if (!canInteract)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${distance.toStringAsFixed(1)}m', style: const TextStyle(fontSize: 8, color: Colors.white54)),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.onPressed, this.active = true});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: active ? Colors.white : Colors.white38,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: _glass(Colors.white, 0.42, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.5, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: _glass(Colors.white, 0.55, 14),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 8)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        backgroundColor: const Color(0x80050B08),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class _BodycamTag extends StatelessWidget {
  const _BodycamTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x8A070B09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.circle, size: 6, color: Color(0xFFE66359)),
          SizedBox(width: 5),
          Text('BODYCAM', style: TextStyle(fontSize: 8, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _EdgeVignette extends StatelessWidget {
  const _EdgeVignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.20),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.24),
          ],
          stops: const <double>[0, 0.52, 1],
        ),
      ),
    );
  }
}

class _DarkSheet extends StatelessWidget {
  const _DarkSheet({required this.child, this.heightFactor});
  final Widget child;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    final height = heightFactor == null ? null : MediaQuery.sizeOf(context).height * heightFactor!;
    return Container(
      height: height,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xF3070E0C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0xAA000000), blurRadius: 28)],
      ),
      child: child,
    );
  }
}

BoxDecoration _glass(Color accent, double alpha, double radius) {
  return BoxDecoration(
    color: const Color(0xFF07100D).withValues(alpha: alpha),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: 0.15)),
    boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x55000000), blurRadius: 16)],
  );
}
