# Hippo OS Gameplay Acceptance

This document defines the difference between a build that merely launches and a Hippo OS build that is ready to be treated as a finished game candidate.

## 1. Core sanctuary loop

A player can launch directly into the sanctuary, see all three companions, select/interact with them, feed or pet them, observe autonomous behaviour, open the journal/camera/map/customisation surfaces and return to the sanctuary without a dead end or duplicate legacy UI.

The sanctuary remains usable without a network connection. Save data survives app pause, focus loss and normal update installation.

## 2. Companion simulation

### Mochi — baby pygmy hippo

Mochi has persistent hunger, energy, curiosity, cleanliness, bond, wetness and mud state. The utility brain can independently choose idle, wander, approach, explore, play, drink, mud and sleep behaviour. Extremely low energy or cleanliness must resolve into welfare behaviour instead of continuing random play.

### Porky — pig

Porky exists in the shared sanctuary and independently wanders, sniffs/roots, plays, rests, watches and responds to pet/treat/call interactions. Hunger, energy, curiosity, playfulness and bond influence behaviour.

### Bao — Shar-Pei

Bao exists in the shared sanctuary and independently watches, wanders, plays, rests and comes when called. Movement and reactions must read differently from Porky rather than being a reskin of the same behaviour.

### Shared life director

The GameplayDirector runs at a mobile-safe fixed cadence. It provides sanctuary clock/phase state, recognises player interaction from persistent state changes, records meaningful sanctuary events, detects close social encounters and injects occasional ambient behaviour without overriding normal creature personality every frame.

## 3. Animation and creature presentation

Fallback procedural animals may be used for engineering builds only. Final 1.0 requires rigged production GLBs at:

- `godot/assets/animals/mochi.glb`
- `godot/assets/animals/porky.glb`
- `godot/assets/animals/bao.glb`

The production animation bridge must map live game actions to authored clips for idle, walk, run, sleep, wake, eat, drink, play, pet reaction, call/alert reaction and species-specific actions such as sniff/root, mud play, water play, yawn and zoomies where available.

Animation transitions must not visibly snap during normal locomotion/interaction. Foot sliding, floating, ground penetration and broken bind poses are release blockers.

## 4. World and visual presentation

The approved direction is portrait-first cinematic African grasslands. The frame must have foreground, midground and background depth; readable water, mud, vegetation, rocks and trees; a hero view of Mochi; and Porky/Bao staged naturally deeper in the world.

Day, golden-hour and night states must keep the selected animal readable. Night is not allowed to become an almost-black screen.

Final production habitat uses verified high-resolution PBR sources and mobile-appropriate imported textures. The runtime must not pretend a low-resolution/generated fallback is a 4K production asset.

## 5. HUD and interaction

Only one authoritative main HUD may be visible. Legacy stats/feed controls must remain hidden when SanctuaryHUD is active.

Portrait HUD acceptance includes:

- companion identity and needs card;
- sanctuary branding/status;
- live minimap;
- Feed, Pet, Journal and Camera actions;
- orbit/focus control;
- bottom navigation for Map, Customize, Shop, Sanctuary and Social surfaces;
- safe-area-aware layout with no overlap or off-screen controls on the target phone.

## 6. Audio and feedback

Animal voices, footsteps/foley, ambience and UI feedback must use separate controllable buses where implemented. Companion vocalisation should be contextual and varied rather than a constant loop. Haptics respect the user setting.

## 7. Camera and game feel

Camera movement is smooth, predictable and touch-friendly. Focus/orbit does not clip through companions or leave the hero animal unreadably small. Camera/photo mode must have a clean return path to gameplay.

Player interactions produce immediate audiovisual feedback while state changes persist into the simulation.

## 8. Mobile performance

The production phone build targets ARM64 and Godot Mobile/Vulkan. Rendering quality may scale only when necessary to protect playability; the software-emulator renderer must never be allowed to downgrade the actual ARM64 production configuration.

Physical-device acceptance must check sustained gameplay, scene transitions, repeated interactions, pause/resume, thermal behaviour and memory stability rather than judging only a launch screenshot.

## 9. Android update/install gate

Existing-user APK updates preserve package `com.sashin.hippoos`, use a monotonically increasing versionCode and the original expected signing identity. Release APKs use Godot's Gradle packaging path with uncompressed native libraries and 16 KB alignment for current Android requirements.

Before an update APK is published, the equivalent Gradle package must pass Android 16 PackageManager installation in CI (`adb install -r` returns `Success`).

## 10. Definition of done

A build is a **playable candidate** only when repository/gameplay validation, Godot import/parse, Android export, package identity, signing/alignment and Android 16 install gates pass.

A build is **final photorealistic 1.0** only when all of the above passes **and** the three final licensed production animal GLBs, final PBR habitat approval manifest, production animation/rig checks and physical target-phone visual/performance acceptance are complete.

No procedural placeholder or emulator-only green check may be represented as satisfying the final 1.0 art/device gate.
