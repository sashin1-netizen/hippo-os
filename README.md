# Hippo OS 🦛

**A personal, offline-first virtual baby pygmy hippo companion for Android.**

> The hippo must feel like a living animal, not a menu-driven virtual pet.

## Active build path

The active Android build is **Godot 4.7.2 + GitHub Actions**, targeting **Android 16 / API 36** on ARM64. The personal build is offline-first and does not request Internet permission.

The earlier Unreal Engine prototype remains in the repository as a preserved reference. It is not the active Android build path.

## Current personal build

The current Godot build includes:

- original procedural baby pygmy hippo placeholder with persistent name, bond, personality and interaction history
- hunger, energy, affection, curiosity, cleanliness, wetness and mud state
- autonomous idle, wander, approach, explore, play, water, mud and rest behaviour
- food selection, persistent food preferences and variable willingness to eat
- head/body petting with variable reactions
- time-of-day-aware routine nudges and non-punitive offline progression
- autosave, pause/focus/exit persistence, corrupted-save recovery, migration and backup of older save payloads
- breathing, blinking, ear flicks, stride, tail and sleep motion
- additional procedural mouth opening/chewing, yawn/wake, sniffing/nostril flare, gaze/head motion and body lean
- generated sanctuary with pond, mud/rest/feed zones, rocks, vegetation, trees, shrubs and lily pads
- animated water and mud surfaces with interaction ripple VFX
- mobile-light procedural day/night/dawn/dusk sky and adaptive fill lighting
- orbit/zoom camera with sensitivity, reset, smoothing and basic collision protection
- responsive safe-area-aware Android UI with immersive and edge-to-edge display
- original standard/adaptive/themed Android launcher identity and a short startup experience
- Settings, rename/reset flows, HUD visibility, reduced motion and text-size controls
- About/version/privacy information
- in-app **DEVICE CHECK** for storage, system, audio-bus, safe-area and FPS diagnostics

## Immersive audio

Hippo OS has a working **cinematic 3D / immersive spatial-audio** system:

- 3D hippo voice, breathing, mouth, Foley and pond emitters
- layered forest, bird and water ambience from checksum-verified public-domain/CC0 sources
- original procedural grunts/chuffs, species-aware huffs, rare squeaks and restrained hisses
- breathing, chewing, footsteps, splash, mud and UI Foley
- sparse pygmy-hippo vocal cadence based on documented species behaviour
- day/night adaptive ambience and pond-specific animal timbre filtering
- Master, Animal, Foley, Ambience and UI buses
- EQ, compression, environmental reverb, dynamic ambience ducking and a Master hard limiter
- persistent one-tap SOUND/MUTED control plus detailed category volumes

The project does **not** claim Dolby Atmos certification or Dolby licensing. The architecture is designed to deliver an immersive spatial experience without misusing Dolby branding.

A professionally recorded, legally licensed pygmy-hippo field/studio vocal pack remains a future premium realism upgrade.

## Android build validation

Every relevant pull request runs the Android build gate. It currently verifies:

1. Java 17 and the Android API 36 toolchain
2. Godot 4.7.2 plus Android export templates
3. checksum-approved sanctuary ambience
4. required launch/autoload systems and branding assets
5. Godot headless import and runtime parsing
6. ETC2/ASTC mobile texture support
7. immersive/edge-to-edge Android export configuration
8. ARM64 APK export
9. package ID `com.sashin.hippoos`
10. target SDK 36
11. app versionCode 2 / version `0.2.0-personal`
12. APK signature verification and SHA-256 generation
13. upload of the verified build artifact

Successful pushes to `main` are configured to publish the verified APK to GitHub Releases. Pull-request builds intentionally do not publish a release.

## Repository layout

```text
hippo-os/
├── godot/                         # ACTIVE Android app
│   ├── assets/audio/              # audio provenance + fetched ambience
│   ├── assets/branding/           # original Android launcher identity
│   ├── project.godot
│   ├── export_presets.cfg
│   ├── main.tscn
│   └── scripts/
│       ├── main.gd
│       ├── audio_director.gd
│       ├── bioacoustic_director.gd
│       ├── adaptive_soundscape.gd
│       ├── visual_sanctuary_polish.gd
│       ├── character_motion_polish.gd
│       ├── atmosphere_polish.gd
│       ├── save_migrator.gd
│       ├── personal_use_polish.gd
│       └── device_diagnostics.gd
├── .github/scripts/
│   └── fetch-audio-assets.sh
├── .github/workflows/
│   └── build-android-apk.yml
├── Docs/
├── Config/                        # preserved Unreal prototype
├── Source/                        # preserved Unreal prototype
└── HippoOS.uproject
```

## Personal-device acceptance

The repository build gate proves the project parses, imports and exports successfully. It cannot prove what a physical phone speaker, Bluetooth headset, launcher cutout, GPU or touch screen actually does.

On the target Android device, open **Settings → DEVICE CHECK** and then complete the manual acceptance items tracked in issue #2: install/launch, icon rendering, touch/feed behaviour, speaker/headphone audio, save/restart/background/offline progression, safe-area layout, water/mud/sky rendering and sustained mobile performance.

## Play Store release gate

The verified APK is a **personal/test sideload build**, not the final Google Play artifact. A Play release still requires a persistent production signing key and a release-signed Android App Bundle (AAB). Production credentials must never be committed to this repository.

## Product rule

Moo Deng may be used only as broad behavioural inspiration. Hippo OS uses its own companion identity and must not directly copy a real individual animal.

## Current launch status

**Mechanically healthy personal-use candidate; not yet final-release complete.**

The software-side Android, persistence, UX, audio, behaviour and procedural sanctuary foundations are substantially implemented and repeatedly validated through the Android pipeline.

The remaining hard gates are intentionally visible in issue #2:

- production-quality original pygmy hippo model with final proportions/skin/detail
- production skeleton and authored animation set
- final production habitat art quality
- optional professional pygmy-hippo recording pack for maximum realism
- successful acceptance on at least one real Android device, including speaker/headphone listening and sustained performance

Do not describe Hippo OS as fully launch-ready until those required acceptance gates are complete.
