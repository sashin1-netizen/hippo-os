import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'open_world_app.dart';

const _control = MethodChannel('hippo_os/control');
const _onboardingKey = 'hippo_os_onboarding_v1_complete';

Future<void> runProductionApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const HippoOsProductionApp());
}

class HippoOsProductionApp extends StatelessWidget {
  const HippoOsProductionApp({super.key});

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
      home: const _ProductionShell(),
    );
  }
}

class _ProductionShell extends StatefulWidget {
  const _ProductionShell();

  @override
  State<_ProductionShell> createState() => _ProductionShellState();
}

class _ProductionShellState extends State<_ProductionShell>
    with WidgetsBindingObserver {
  bool _preferencesLoaded = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFirstRunState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _loadFirstRunState() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool(_onboardingKey) ?? false;
    if (!mounted) return;
    setState(() {
      _preferencesLoaded = true;
      _showOnboarding = !complete;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  Future<void> _showSystemMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SystemSheet(
        onControls: () {
          Navigator.of(sheetContext).pop();
          setState(() => _showOnboarding = true);
        },
        onAbout: () {
          Navigator.of(sheetContext).pop();
          _showTextPanel(
            'ABOUT HIPPO OS',
            'Hippo OS 1.0 is a private, local-first living sanctuary for Mochi, Truffle and Bao. '
                'The Flutter interface hosts an embedded Godot 4.7.2 open-world simulation. '
                'The animals keep needs, temperament, learned preferences, memories and relationship state between sessions.',
          );
        },
        onPrivacy: () {
          Navigator.of(sheetContext).pop();
          _showTextPanel(
            'PRIVACY',
            'Sanctuary progress and customisation are stored locally on this device. '
                'Hippo OS 1.0 has no account requirement, advertising or analytics. '
                'The personal launch build does not intentionally transmit sanctuary or personal data to a remote service.',
          );
        },
        onCredits: () {
          Navigator.of(sheetContext).pop();
          _showTextPanel(
            'CREDITS & LICENCES',
            'Animal models are generated from original Hippo OS creature specifications using the MIT-licensed anyCreature compiler.\n\n'
                'Habitat textures and South African daylight panorama: Poly Haven, CC0.\n'
                'Hippo field ambience: toadie / Freesound, CC0.\n'
                'Pig grunt: erdie, CC BY 3.0.\n'
                'Natural dog recording: soerena, Public Domain.\n'
                'Dog bark: Edo.pt2, CC0.\n\n'
                'Footsteps, splashes, mud, eating, drinking, interface sounds and sanctuary ambience are original Hippo OS generated audio.',
          );
        },
        onReset: () {
          Navigator.of(sheetContext).pop();
          _confirmReset();
        },
      ),
    );
  }

  Future<void> _showTextPanel(String title, String body) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PanelCard(
        heightFactor: 0.68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFFC6D2CB),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset sanctuary?'),
        content: const Text(
          'This permanently clears animal progress, learned preferences, relationships, journal entries and customisation on this device. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('RESET EVERYTHING'),
          ),
        ],
      ),
    );
    if (reset != true) return;
    try {
      await _control.invokeMethod<void>('animalAction', 'reset_sanctuary');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sanctuary reset complete.')),
        );
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset could not be completed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const OpenWorldSanctuaryScreen(),
        Positioned(
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: _MenuButton(onPressed: _showSystemMenu),
          ),
        ),
        if (_preferencesLoaded && _showOnboarding)
          Positioned.fill(
            child: _OnboardingOverlay(onEnter: _completeOnboarding),
          ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xA6070E0B),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Hippo OS menu',
        onPressed: onPressed,
        icon: const Icon(Icons.menu_rounded, size: 20),
        color: const Color(0xFFDDE7E1),
      ),
    );
  }
}

class _OnboardingOverlay extends StatelessWidget {
  const _OnboardingOverlay({required this.onEnter});
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2050907),
      child: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'HIPPO OS',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'YOUR LIVING SANCTUARY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.4,
                    color: Color(0xFFA6B9AE),
                  ),
                ),
                const SizedBox(height: 28),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: <Widget>[
                    _ControlCard(
                      icon: Icons.control_camera_rounded,
                      title: 'MOVE',
                      text: 'Use the left joystick in Caretaker or Bodycam mode.',
                    ),
                    _ControlCard(
                      icon: Icons.swipe_rounded,
                      title: 'LOOK',
                      text: 'Swipe the open world to turn and look around.',
                    ),
                    _ControlCard(
                      icon: Icons.explore_outlined,
                      title: 'EXPLORE',
                      text: 'Use the minimap to find Mochi, Truffle and Bao.',
                    ),
                    _ControlCard(
                      icon: Icons.favorite_border_rounded,
                      title: 'BUILD TRUST',
                      text: 'Move close before feeding or touching. Animals can refuse.',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'The sanctuary follows your real local time. The animals continue developing needs, routines, memories and relationships even when you are not directing them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFFAFC0B7),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onEnter,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('ENTER SANCTUARY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1511),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 24, color: const Color(0xFFC7D9CE)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.35,
              color: Color(0xFF9DADA4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemSheet extends StatelessWidget {
  const _SystemSheet({
    required this.onControls,
    required this.onAbout,
    required this.onPrivacy,
    required this.onCredits,
    required this.onReset,
  });

  final VoidCallback onControls;
  final VoidCallback onAbout;
  final VoidCallback onPrivacy;
  final VoidCallback onCredits;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'HIPPO OS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _MenuRow(icon: Icons.help_outline_rounded, label: 'Controls', onTap: onControls),
          _MenuRow(icon: Icons.info_outline_rounded, label: 'About', onTap: onAbout),
          _MenuRow(icon: Icons.privacy_tip_outlined, label: 'Privacy', onTap: onPrivacy),
          _MenuRow(icon: Icons.article_outlined, label: 'Credits & licences', onTap: onCredits),
          const Divider(color: Colors.white12),
          _MenuRow(
            icon: Icons.restart_alt_rounded,
            label: 'Reset sanctuary',
            onTap: onReset,
            destructive: true,
          ),
          const SizedBox(height: 4),
          const Text(
            'Hippo OS 1.0 · Personal production build',
            style: TextStyle(fontSize: 9, color: Color(0xFF73847B)),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE6A09B) : const Color(0xFFD5DFD9);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, size: 19, color: color),
      title: Text(label, style: TextStyle(color: color, fontSize: 13)),
      onTap: onTap,
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child, this.heightFactor});
  final Widget child;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    final height = heightFactor == null
        ? null
        : MediaQuery.sizeOf(context).height * heightFactor!;
    return Container(
      height: height,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xF5070E0C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xAA000000), blurRadius: 28),
        ],
      ),
      child: child,
    );
  }
}
