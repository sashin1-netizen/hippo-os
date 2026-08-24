# Hippo OS — Flutter / Bodycam / Real-Time / 4K Launch Specification

Branch: `release/flutter-4k-v1`
Status: mandatory launch contract

## Architecture
- Flutter 3.44.7 is the production application shell and all user-facing application chrome/UI.
- Godot 4.7.2 remains the embedded real-time 3D sanctuary/simulation renderer on Android.
- Flutter and Godot communicate through an Android bridge using method/event channels and a Godot Android plugin.
- The legacy Godot-only UI must not be the final user-facing shell.

## Required viewpoints
The production sanctuary must expose these camera modes:
1. Cinematic — composed third-person sanctuary view.
2. Caretaker — closer human-height observational view.
3. Bodycam — caretaker chest-height POV, wider field of view, subtle natural movement and optional stabilization/reduced-motion behavior.
4. Overhead — high sanctuary overview.

Bodycam is a simulated in-world POV. It does not access or record the phone camera.

## Real-world time and timezone
- Time comes from the Android device, not a hard-coded timezone or server assumption.
- Flutter obtains the platform-reported IANA timezone identifier and current local DateTime/UTC offset.
- The bridge sends IANA zone, local hour/minute, ISO-8601 local time, UTC offset and epoch time into the sanctuary.
- Time is synchronized at launch, on application resume and once per minute while the app remains active.
- Day/night lighting and animal circadian behavior must use the synchronized local time.
- Changing timezone while travelling must be picked up after resume or the next synchronization cycle.

## 4K quality contract
`4K` means a true high-resolution production pipeline, not fake upscaling.

### Master assets
- Final raster source artwork and environmental texture masters: up to 4096 × 4096 where the asset benefits from that resolution and the target mobile GPU supports it.
- Vector Flutter UI remains vector/resolution-independent wherever practical.
- Icons/logos are maintained as vector masters and exported to each Android/store-required size.
- 3D meshes must have enough geometry and material detail to hold up under a 3840 × 2160 capture without exposing primitive placeholder construction.

### Live rendering
- The embedded 3D surface renders at the actual physical surface resolution supplied by the device.
- A device with a 4K render surface may render natively at 4K where performance gates pass.
- Devices below 4K are not artificially forced to render a 3840 × 2160 off-screen buffer continuously; doing so would waste GPU/battery without creating extra display detail.
- Live rendering must never use the previous fixed 1280 × 720 output as the final quality ceiling.
- Runtime quality may dynamically protect frame pacing, but the visual master/capture standard remains 4K.

### 4K capture / marketing
- Production photo/capture target: 3840 × 2160 where supported.
- Final marketing master screenshots are captured from the production build at up to 3840 px on the longest side.
- Store assets that Google Play mandates at a fixed non-4K size are exported to Google's exact required dimensions from the 4K/vector master; this is not considered a quality downgrade.

## Launch gate additions
The application cannot be declared launch-ready until all of the following are proven:
- Flutter shell builds and runs around the embedded Godot surface.
- Flutter ↔ Godot camera/action/status bridge works on-device.
- Bodycam, caretaker, cinematic and overhead modes all work without camera clipping or nausea-inducing motion.
- Real IANA timezone synchronization updates lighting and routines correctly.
- No hard-coded 1280 × 720 visual ceiling remains in the production hybrid path.
- 4K capture is verified on a capable build/device or CI render path.
- 4K-quality assets do not break mobile memory/performance budgets.
- All three animals remain visually production-ready in every camera mode, including close Bodycam framing.
- Final APK/AAB is not distributed to the user until the full launch checklist is green.
