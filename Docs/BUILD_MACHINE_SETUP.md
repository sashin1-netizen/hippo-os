# Hippo OS — Android Build Machine Setup

The repository is designed to emit an APK from Unreal Engine 5.8 using `Scripts/Build-Android.ps1`.

## Required host

Windows 11 recommended.

Install:

1. Unreal Engine 5.8 from Epic Games Launcher.
2. Visual Studio 2022 with **Game development with C++**.
3. The Android components required by Unreal 5.8.
4. Git and Git LFS.
5. Android platform tools (`adb`) available on PATH.

Default engine path expected by the scripts:

```text
C:\Program Files\Epic Games\UE_5.8
```

If Unreal is installed elsewhere, pass `-EngineRoot` explicitly.

## Android setup

From Unreal Engine, use the Android/Turnkey setup flow so the engine can detect its supported SDK, NDK and Java toolchain. Do not mix arbitrary Android NDK versions with the engine installation.

Verify:

```powershell
adb version
adb devices
```

For a physical phone, enable Developer Options and USB debugging and accept the RSA prompt on the device.

## Local APK build

Clone the repository with Git LFS enabled, then run:

```powershell
git lfs install
git lfs pull
.\Scripts\Build-Android.ps1
```

For a shipping package:

```powershell
.\Scripts\Build-Android.ps1 -Configuration Shipping
```

The script fails if Unreal Automation Tool is missing, packaging exits non-zero, or no APK is produced.

APK output:

```text
Artifacts/Android/
```

## GitHub Actions self-hosted runner

The workflow `.github/workflows/build-android-apk.yml` intentionally uses a self-hosted Windows runner because GitHub-hosted runners do not include a licensed Unreal Engine 5.8 installation.

Register the build PC as a self-hosted runner for this repository and add these labels:

```text
windows
unreal-5.8
android
```

The runner account must be able to read:

```text
C:\Program Files\Epic Games\UE_5.8
```

and `adb` must be available on PATH.

Once registered, open **Actions → Build Android APK → Run workflow**. A successful run uploads the resulting APK as a GitHub Actions artifact for 14 days.

## Build truth

`APK ready` means the source tree and packaging pipeline are configured to produce an Android package. It does **not** mean an APK binary exists until this build executes successfully on a machine with Unreal Engine and its Android toolchain installed.
