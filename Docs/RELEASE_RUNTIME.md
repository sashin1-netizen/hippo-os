# Hippo OS Release Runtime

## Authoritative runtime

The **Godot 4.7.x project under `godot/` is the only authoritative Android release runtime for Hippo OS**.

All Android APK/AAB exports, Android 16 compatibility checks, gameplay smoke tests, visual acceptance, persistence checks, and physical-device certification MUST execute against `godot/project.godot` and its exported package `com.sashin.hippoos`.

## Legacy Unreal sources

The top-level Unreal Engine project and `Source/` tree are retained only as historical/prototype reference. They are **not a release implementation**, MUST NOT be used to claim Android readiness, and MUST NOT satisfy any production gate for the current game.

A feature only counts as shipped when it exists in the Godot runtime and is exercised by the Godot release pipeline.

## Release definitions

### CI-ready candidate
A commit is a CI-ready candidate only when all of the following pass on the same commit:

1. repository/architecture contract;
2. Godot import and gameplay smoke;
3. ARM64 Android package contract (application ID, target SDK 36, ABI, signing, 16 KB alignment, SHA-256);
4. Android 16 emulator install/cold-launch/lifecycle proof.

The emulator is an OS/package/lifecycle test. It is not the final graphics authority because current Godot Vulkan Android emulator configurations can fail at presentation even for minimal projects.

### Device-certified release
A candidate becomes a device-certified release only when the **exact ARM64 APK SHA-256** from CI is installed on a physical Android 16 device and passes:

1. package install and cold launch;
2. foreground/resume and process-alive checks;
3. authoritative world-ready marker;
4. screenshot capture from the real device;
5. visual-regression acceptance;
6. no fatal/script/shader/runtime errors during the smoke window;
7. basic interaction/playability smoke;
8. persisted save/relaunch smoke.

The certification evidence must record the APK SHA-256, device model, Android API level, renderer/GPU information, timestamp, screenshot, and logs.

## No mixed-runtime claims

Unreal compile success, prototype code, editor screenshots, emulator-only rendering, or a differently hashed APK can never substitute for physical-device certification of the exact release candidate.
