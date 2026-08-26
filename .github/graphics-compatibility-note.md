# Android 16 Compatibility Graphics Validation

This repair branch validates the Godot Compatibility/OpenGL fallback against the Android 16 SwiftShader stack while preserving the ARM64 Mobile/Vulkan production path.

Release acceptance remains: build -> install -> Android 16 cold launch -> zero fatal shader/runtime errors -> authoritative world marker -> rendered-frame visual regression pass.
