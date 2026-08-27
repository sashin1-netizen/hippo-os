# Hippo OS — Android APK Readiness Runbook

## Active build path

Hippo OS is currently built with **Godot 4.7.2** for **Android 16 / API 36**. The active phone target is ARM64. The Unreal Engine files remain historical prototype material only and are not used to produce the current Android APK.

## Existing-app update identity

The update intended to install over the original Hippo OS app uses:

- package: `com.sashin.hippoos`
- versionCode: `104`
- versionName: `0.2.6-package-fix`
- Android target SDK: `36`
- ABI: `arm64-v8a`
- 16 KB ZIP alignment
- APK Signature Scheme v2
- expected personal/test certificate SHA-256: `3f19983ae8a86f7f7b20fa6be17b69882879c76a747f5d7744a6b063717f1dc2`

Do not uninstall the existing app merely to apply an update: uninstalling can remove local app data. If Android refuses an in-place update despite the package/version checks above, compare the signing certificate of the installed historical build before changing anything on the device.

## CI gates

The repository carries two complementary Android workflows:

- `.github/workflows/build-android-apk.yml` — validates the project, ARM64 build, x86_64 evidence twin and a real non-flat Android 16 rendered frame.
- `.github/workflows/build-existing-app-update-v026.yml` — builds the exact `com.sashin.hippoos` update through Godot's Gradle path, verifies ABI/metadata/signing/alignment, then proves Android 16 PackageManager accepts the package with `adb install -r`.

The visual evidence gate uses an Android 16 x86_64 emulator with ANGLE/Swangle only because software GLES/SwiftShader has renderer limitations that are not representative of the physical ARM64 Mobile/Vulkan path. The phone APK remains Mobile/Vulkan.

A screenshot is not accepted merely because it is a non-empty PNG. CI checks pixel spread and standard deviation and rejects flat/dark frames as well as crash, shader, script and parse failures.

## Runtime assets

The personal candidate is self-contained and can boot without the final licensed animal GLBs. It currently includes procedural fallbacks for Mochi, Porky and Bao plus the persistent gameplay, behaviour, audio, UI and sanctuary systems.

The habitat source set contains checksum-verified genuine 4096×4096 PBR masters. Those 4K source assets do not make the procedural animal fallbacks final production models.

## Install

For the canonical existing-app update, use the APK published by the installer-proven workflow/release and keep the existing Hippo OS installation in place. Android should present an **Update** flow when package identity and signing lineage match the installed app.

ADB equivalent:

```bash
adb install -r HippoOS-v0.2.6-UPDATE.apk
```

## Definition of personal APK-ready

A personal build is APK-ready only when all of these are true:

- repository quality checks pass
- Godot import/smoke checks have no script, parse or shader errors
- ARM64 APK exports successfully
- package metadata and target SDK are correct
- native ABI is correct
- APK is 16 KB aligned
- APK Signature Scheme v2 and expected certificate are verified
- Android 16 PackageManager installation succeeds
- Android 16 evidence produces a real non-flat Hippo OS frame
- the resulting frame is manually inspected
- a direct-download release asset is published

## Production 1.0 is a separate gate

A successful personal APK does **not** close the production-release gate. Issue #2 remains open until the final licensed Mochi/Porky/Bao GLBs, authored rigs/animations, secure production signing, release AAB and target-phone visual/audio/performance acceptance are completed.
