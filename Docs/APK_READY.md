# Hippo OS — APK Readiness Runbook

## Current candidate

The repository contains a self-bootstrapping playable candidate that does not require imported project assets to launch:

- generated sanctuary ground, pond, mud patch and rocks
- generated baby-hippo fallback character from Unreal Engine primitives
- autonomous utility-based behaviour
- breathing and ear motion
- direct touch petting
- drag-to-orbit habitat camera
- persistent personality
- persistent bond and interaction memory
- needs simulation
- offline progression
- automatic save/load and autosave

The procedural character is a technical fallback. A production skeletal baby pygmy hippo can replace the visuals later without replacing the simulation systems.

## Required build machine

- Windows
- Unreal Engine 5.8
- Visual Studio C++ toolchain required by UE 5.8
- Android SDK/NDK configured through Unreal Turnkey
- Java/JDK version required by the installed UE 5.8 Android toolchain
- Git LFS

## One-command package

From the repository root in PowerShell:

```powershell
.\Scripts\Build-Android.ps1
```

For a shipping build:

```powershell
.\Scripts\Build-Android.ps1 -Configuration Shipping
```

If Unreal is installed elsewhere:

```powershell
.\Scripts\Build-Android.ps1 -EngineRoot "D:\Epic\UE_5.8"
```

Successful packaging places the APK below:

```text
Artifacts/Android/
```

## GitHub Actions

Workflow:

```text
.github/workflows/android-apk.yml
```

It intentionally targets a self-hosted Windows runner carrying these labels:

```text
self-hosted
Windows
unreal-5.8
android
```

This avoids pretending that a normal GitHub-hosted runner already includes the licensed Unreal Engine editor and Android toolchain.

## Install to phone

After the APK is produced, either copy it to the phone and install it with permission for unknown apps, or use Android Debug Bridge:

```powershell
adb install -r path\to\HippoOS.apk
```

## Definition of APK-ready

Repository APK-ready means:

- source project is configured for Android ARM64
- startup game mode and map are defined
- runtime gameplay does not require missing custom assets
- packaging command is committed
- CI packaging workflow is committed
- APK output path is deterministic

It does **not** mean an APK binary has been compiled until the build command completes successfully on a machine with Unreal Engine 5.8 and the Android toolchain.
