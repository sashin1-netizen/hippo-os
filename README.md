# Hippo OS 🦛

**A personal, offline-first virtual baby pygmy hippo companion for Android.**

> The hippo must feel like a living animal, not a menu-driven virtual pet.

## Active build path

The active Android build is **Godot 4.7.2 + GitHub Actions**, targeting **Android 16 / API 36**. The project is intentionally structured so its test APK can be built on GitHub-hosted infrastructure without requiring a local PC or a paid cloud builder.

The earlier Unreal Engine prototype remains in the repository as a preserved reference, but it is **not** the active Android build path because Unreal requires a suitable build machine with the engine installed.

## What the current Godot build contains

- original procedural 3D baby pygmy hippo companion
- persistent hippo name, bond, personality and interaction history
- personality traits that influence autonomous behaviour
- autonomous idle, wandering, approach, exploration, play, water, mud and rest routines
- direct head/body petting with different bond response
- feeding
- hunger, energy, affection, curiosity and cleanliness state
- wetness and mud-coat state with visible surface changes
- breathing, blinking, ear flicks, stride, tail and sleep motion foundation
- non-punitive offline progression
- autosave plus pause/focus/exit persistence
- invalid-save recovery fallback
- generated sanctuary with grass, pond, mud, rest area, rocks and vegetation
- orbit camera, zoom, sensitivity and reset controls
- rename flow and destructive-reset confirmation
- persisted settings for volume categories, haptics, stats visibility, reduced motion, text size and day/night lighting
- Android back handling
- Android ARM64 export
- ETC2/ASTC mobile texture import support
- Android 16 / API 36 package verification
- APK signature verification and SHA-256 output in CI
- pull-request Android build gate before changes reach `main`

## Repository layout

```text
hippo-os/
├── godot/                         # ACTIVE Android app
│   ├── project.godot
│   ├── export_presets.cfg
│   ├── main.tscn
│   └── scripts/
├── .github/workflows/
│   └── build-android-apk.yml      # hosted Android validation/build pipeline
├── Config/                        # Unreal prototype
├── Source/                        # Unreal prototype
├── HippoOS.uproject               # Unreal prototype
└── Docs/
```

## Android test build

Open **Actions → Build Android APK → Run workflow**.

GitHub automatically:

1. starts a hosted Ubuntu runner
2. installs Java 17
3. installs the Android API 36 toolchain
4. downloads Godot 4.7.2 and Android export templates
5. validates the Godot project headlessly
6. generates a debug signing key for test builds
7. exports `HippoOS.apk`
8. verifies package ID `com.sashin.hippoos`, target SDK 36 and APK signature
9. writes a SHA-256 checksum
10. uploads the verified build artifact
11. publishes the verified APK to GitHub Releases only for successful pushes to `main`

## Play Store release gate

The verified GitHub APK is a **test/sideload build**, not the final Google Play artifact. A Play release still requires a persistent production signing key and a release-signed **Android App Bundle (AAB)**. Those credentials must never be committed to this repository.

## Product rule

Moo Deng is behavioural inspiration only. Hippo OS uses an original virtual baby pygmy hippo and can later replace the procedural character with a premium custom 3D model without changing the underlying pet systems.

## Launch status

**Playable pre-alpha with a verified Android 16/API 36 test-build pipeline.**

The project must **not** be described as launch-ready yet. Remaining release-gate work includes a production-quality rigged pygmy hippo model, authored animation set, legally reusable animal/ambience/UI audio, spatial sound, final sanctuary art and water/mud effects, complete responsive-device QA, accessibility review, production signing/AAB packaging and successful on-device acceptance testing.
