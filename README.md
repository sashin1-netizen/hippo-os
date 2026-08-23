# Hippo OS 🦛

**A personal, offline-first virtual baby pygmy hippo companion for Android.**

> The hippo must feel like a living animal, not a menu-driven virtual pet.

## Active build path

The active APK build is now **Godot 4.4.1 + GitHub Actions** so the project can be built with **no PC and no paid cloud builder**.

The earlier Unreal Engine 5.8 prototype remains in the repository as a preserved reference, but it is **not** the active Android build path because Unreal requires a build machine with the engine installed.

## What the current Godot APK candidate contains

- procedural 3D baby pygmy hippo made from engine primitives
- original hippo identity and persistent personality
- autonomous utility-based behaviour
- direct touch petting
- feeding
- hunger, energy, affection, curiosity and cleanliness
- bond and interaction memory
- offline progression
- autosave/load
- generated sanctuary with grass, pond, mud, rocks and vegetation
- orbit camera
- mobile HUD
- Android ARM64 export
- fully free GitHub-hosted APK workflow

## Repository layout

```text
hippo-os/
├── godot/                         # ACTIVE Android app
│   ├── project.godot
│   ├── export_presets.cfg
│   ├── main.tscn
│   └── scripts/
├── .github/workflows/
│   └── build-android-apk.yml      # FREE hosted APK build
├── Config/                        # Unreal prototype
├── Source/                        # Unreal prototype
├── HippoOS.uproject               # Unreal prototype
└── Docs/
```

## Free APK build

Open **Actions → Build Android APK → Run workflow**.

GitHub automatically:

1. starts a hosted Ubuntu runner
2. installs Java 17
3. installs Android SDK 35
4. downloads Godot 4.4.1
5. installs Godot Android export templates
6. generates a free Android debug signing key
7. exports `HippoOS.apk`
8. uploads it as the `HippoOS-Android-APK` artifact

No self-hosted runner is required.

## Product rule

Moo Deng is behavioural inspiration only. Hippo OS uses an original virtual baby pygmy hippo and can later replace the procedural character with a premium custom 3D model without changing the underlying pet systems.

## Status

**Playable pre-alpha / free APK pipeline.** The current goal is to prove the complete pet loop on Android first, then upgrade character art, animation, water, mud, sound and interaction quality while keeping the build completely free.
