import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_mode.dart';
import 'customization_sheet.dart';
import 'customization_state.dart';
import 'device_time_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const HippoOsApp());
}

class HippoOsApp extends StatelessWidget {
  const HippoOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hippo OS',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF030706),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8F4EC),
          secondary: Color(0xFF96B8A5),
          surface: Color(0xFF0B1110),
        ),
      ),
      home: const SanctuaryScreen(),
    );
  }
}

class SanctuaryScreen extends StatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  State<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends State<SanctuaryScreen>
    with WidgetsBindingObserver {
  static const _control = MethodChannel('hippo_os/control');
  static const _events = EventChannel('hippo_os/events');

  final _clock = const DeviceTimeService();
  SanctuaryCameraMode _cameraMode = SanctuaryCameraMode.cinematic;
  SanctuaryCustomization _customization = const SanctuaryCustomization();
  String _animal = 'Mochi';
  String _species = 'Pygmy Hippo';
  String _status = 'Sanctuary online';
  String _zone = 'LOCAL TIME';
  String _worldPulse = 'Living world starting';
  String _lastCustomizationJson = '';
  bool _hudVisible = true;
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
      // Godot attaches immediately after the Flutter host is ready.
    }
  }

  void _handleEngineEvent(dynamic event) {
    if (event is! Map || !mounted) return;
    final wind = _asDouble(event['wind']);
    final humidity = _asDouble(event['humidity']);
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

    setState(() {
      _animal = '${event['animal_name'] ?? _animal}';
      _species = '${event['species_name'] ?? _species}';
      _status = '${event['status'] ?? _status}';
      if (restoredCustomization != null) {
        _customization = restoredCustomization;
      }
      if (wind != null && humidity != null) {
        _worldPulse =
            'Wind ${(wind * 100).round()}%  ·  Humidity ${(humidity * 100).round()}%';
      }
    });
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  Future<void> _setCamera(SanctuaryCameraMode mode) async {
    setState(() => _cameraMode = mode);
    await _control.invokeMethod('setCameraMode', mode.engineValue);
  }

  Future<void> _action(String action) async {
    await _control.invokeMethod('animalAction', action);
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

  Color get _accent => HSVColor.fromAHSV(
        1,
        _customization.accentHue * 360,
        0.34,
        0.92,
      ).toColor();

  @override
  Widget build(BuildContext context) {
    final textMedia = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(_customization.textScale),
    );
    return MediaQuery(
      data: textMedia,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: AndroidView(
                viewType: 'hippo_os/godot_view',
                layoutDirection: TextDirection.ltr,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.38),
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 650;
                  final uiScale = _customization.interfaceScale.clamp(0.78, 1.16);
                  return Stack(
                    children: [
                      if (_hudVisible) ...[
                        Align(
                          alignment: Alignment.topLeft,
                          child: Transform.scale(
                            scale: uiScale,
                            alignment: Alignment.topLeft,
                            child: _AnimalHud(
                              animal: _animal,
                              species: _species,
                              status: _status,
                              accent: _accent,
                              glass: _customization.interfaceGlass,
                              compact: compact,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Transform.scale(
                            scale: uiScale,
                            alignment: Alignment.topRight,
                            child: _WorldHud(
                              zone: _zone,
                              worldPulse: _worldPulse,
                              accent: _accent,
                              onFocusMode: () => setState(() => _hudVisible = false),
                              compact: compact,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.scale(
                            scale: uiScale,
                            alignment: Alignment.bottomCenter,
                            child: _ControlDeck(
                              selected: _cameraMode,
                              onSelected: _setCamera,
                              onAction: _action,
                              onCustomize: _openCustomization,
                              accent: _accent,
                              compact: compact,
                            ),
                          ),
                        ),
                      ] else
                        Align(
                          alignment: Alignment.topRight,
                          child: _FocusRestoreButton(
                            accent: _accent,
                            onTap: () => setState(() => _hudVisible = true),
                          ),
                        ),
                      if (_cameraMode == SanctuaryCameraMode.bodycam)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: compact ? 6 : 12),
                            child: const _BodycamBadge(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalHud extends StatelessWidget {
  const _AnimalHud({
    required this.animal,
    required this.species,
    required this.status,
    required this.accent,
    required this.glass,
    required this.compact,
  });

  final String animal;
  final String species;
  final String status;
  final Color accent;
  final double glass;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final alpha = (0.48 + glass * 0.28).clamp(0.48, 0.82);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 390 : 460),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 17,
          vertical: compact ? 9 : 12,
        ),
        decoration: _glassDecoration(accent, alpha),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$animal  ·  $species',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      color: const Color(0xFFC4D0C9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldHud extends StatelessWidget {
  const _WorldHud({
    required this.zone,
    required this.worldPulse,
    required this.accent,
    required this.onFocusMode,
    required this.compact,
  });

  final String zone;
  final String worldPulse;
  final Color accent;
  final VoidCallback onFocusMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 15,
        compact ? 7 : 9,
        compact ? 7 : 8,
        compact ? 7 : 9,
      ),
      decoration: _glassDecoration(accent, 0.68),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                zone,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                worldPulse,
                style: TextStyle(
                  fontSize: compact ? 8 : 9,
                  color: const Color(0xFF94A99E),
                ),
              ),
            ],
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Focus mode',
            visualDensity: VisualDensity.compact,
            onPressed: onFocusMode,
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.selected,
    required this.onSelected,
    required this.onAction,
    required this.onCustomize,
    required this.accent,
    required this.compact,
  });

  final SanctuaryCameraMode selected;
  final ValueChanged<SanctuaryCameraMode> onSelected;
  final ValueChanged<String> onAction;
  final VoidCallback onCustomize;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 760 : 900),
      child: Container(
        padding: EdgeInsets.all(compact ? 5 : 6),
        decoration: _glassDecoration(accent, 0.76),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in SanctuaryCameraMode.values)
              _CameraButton(
                mode: mode,
                selected: selected == mode,
                accent: accent,
                onTap: () => onSelected(mode),
                compact: compact,
              ),
            _divider(compact),
            _DeckIcon(
              tooltip: 'Feed',
              icon: Icons.restaurant,
              onTap: () => onAction('feed'),
              compact: compact,
            ),
            _DeckIcon(
              tooltip: 'Pet',
              icon: Icons.pan_tool_alt_outlined,
              onTap: () => onAction('pet'),
              compact: compact,
            ),
            _DeckIcon(
              tooltip: 'Journal',
              icon: Icons.auto_stories_outlined,
              onTap: () => onAction('journal'),
              compact: compact,
            ),
            _DeckIcon(
              tooltip: 'Customise',
              icon: Icons.tune,
              onTap: onCustomize,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool compact) => Container(
        width: 1,
        height: compact ? 28 : 34,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        color: Colors.white.withValues(alpha: 0.10),
      );
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.mode,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.compact,
  });

  final SanctuaryCameraMode mode;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: selected ? const Color(0xFF06100B) : const Color(0xFFC4CFC9),
          backgroundColor: selected ? accent : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 12,
            vertical: compact ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          mode.label,
          style: TextStyle(
            fontSize: compact ? 9 : 10,
            letterSpacing: 0.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DeckIcon extends StatelessWidget {
  const _DeckIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: compact ? 18 : 20,
      padding: EdgeInsets.all(compact ? 7 : 9),
      icon: Icon(icon),
    );
  }
}

class _FocusRestoreButton extends StatelessWidget {
  const _FocusRestoreButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassDecoration(accent, 0.62),
      child: IconButton(
        tooltip: 'Show controls',
        onPressed: onTap,
        icon: const Icon(Icons.visibility_outlined, size: 19),
      ),
    );
  }
}

class _BodycamBadge extends StatelessWidget {
  const _BodycamBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xB80B0E0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Color(0xFFE2574C)),
          SizedBox(width: 6),
          Text(
            'BODYCAM',
            style: TextStyle(fontSize: 9, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _glassDecoration(Color accent, double alpha) {
  return BoxDecoration(
    color: const Color(0xFF07100D).withValues(alpha: alpha),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: accent.withValues(alpha: 0.16)),
    boxShadow: const <BoxShadow>[
      BoxShadow(blurRadius: 22, color: Color(0x47000000)),
    ],
  );
}
