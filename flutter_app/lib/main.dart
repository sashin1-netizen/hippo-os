import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_mode.dart';
import 'customization_sheet.dart';
import 'customization_state.dart';
import 'device_time_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    if (state == AppLifecycleState.resumed) _syncRealTime();
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
        _customization = restoredCustomization!;
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
                        Colors.black.withValues(alpha: 0.54),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.68),
                      ],
                      stops: const [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Transform.scale(
                scale: _customization.interfaceScale,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    children: [
                      _TopBar(
                        animal: _animal,
                        species: _species,
                        status: _status,
                        zone: _zone,
                        worldPulse: _worldPulse,
                        accent: _accent,
                        glass: _customization.interfaceGlass,
                      ),
                      const Spacer(),
                      _CameraStrip(
                        selected: _cameraMode,
                        onSelected: _setCamera,
                        accent: _accent,
                      ),
                      const SizedBox(height: 12),
                      _ActionDock(
                        onAction: _action,
                        onCustomize: _openCustomization,
                        accent: _accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_cameraMode == SanctuaryCameraMode.bodycam)
              const Positioned(
                top: 108,
                right: 20,
                child: _BodycamBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.animal,
    required this.species,
    required this.status,
    required this.zone,
    required this.worldPulse,
    required this.accent,
    required this.glass,
  });

  final String animal;
  final String species;
  final String status;
  final String zone;
  final String worldPulse;
  final Color accent;
  final double glass;

  @override
  Widget build(BuildContext context) {
    final alpha = (0.58 + glass * 0.30).clamp(0.58, 0.92);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0E).withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
        boxShadow: const [BoxShadow(blurRadius: 30, color: Color(0x66000000))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HIPPO OS  /  LIVING SANCTUARY',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.9,
                        color: accent,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$animal  ·  $species',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFC5D1CA)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'REAL WORLD CLOCK',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  color: Color(0xFF83998E),
                ),
              ),
              const SizedBox(height: 4),
              Text(zone, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(
                worldPulse,
                style: const TextStyle(fontSize: 10, color: Color(0xFF91A69B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CameraStrip extends StatelessWidget {
  const _CameraStrip({
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  final SanctuaryCameraMode selected;
  final ValueChanged<SanctuaryCameraMode> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xD90A0F0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          for (final mode in SanctuaryCameraMode.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilledButton.tonal(
                  onPressed: () => onSelected(mode),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        selected == mode ? accent : const Color(0xFF111817),
                    foregroundColor: selected == mode
                        ? const Color(0xFF07100C)
                        : const Color(0xFFC2CEC7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    mode.label,
                    style: const TextStyle(fontSize: 11, letterSpacing: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.onAction,
    required this.onCustomize,
    required this.accent,
  });

  final ValueChanged<String> onAction;
  final VoidCallback onCustomize;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xE60A0F0E),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _DockButton(
            label: 'FEED',
            icon: Icons.restaurant,
            onTap: () => onAction('feed'),
          ),
          _DockButton(
            label: 'PET',
            icon: Icons.pan_tool_alt_outlined,
            onTap: () => onAction('pet'),
          ),
          _DockButton(
            label: 'JOURNAL',
            icon: Icons.auto_stories_outlined,
            onTap: () => onAction('journal'),
          ),
          _DockButton(
            label: 'CUSTOMISE',
            icon: Icons.tune,
            onTap: onCustomize,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(letterSpacing: 0.8)),
      ),
    );
  }
}

class _BodycamBadge extends StatelessWidget {
  const _BodycamBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xC90B0E0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: Color(0xFFE2574C)),
          SizedBox(width: 7),
          Text(
            'BODYCAM',
            style: TextStyle(fontSize: 11, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}
