# Hippo OS 1.0 Launch Checklist

Branch: `release/flutter-4k-v1`

## Distribution hold — mandatory
- [x] Internal APK builds may be generated for CI validation only.
- [x] No APK, AAB, store package, or download link is handed to the user while any launch gate remains open.
- [x] The next user-facing APK must be the launch-ready build.
- [x] Placeholder animal geometry and silent placeholder audio are forbidden.
- [x] Final screenshots must come from the final production hybrid build.

## Production architecture
- [x] Flutter 3.44.7 selected as the user-facing application shell.
- [x] Godot 4.7.2 retained as the embedded real-time 3D sanctuary renderer.
- [x] Android PlatformView host implemented for the Godot surface.
- [x] Bidirectional Flutter ↔ Godot bridge implemented.
- [x] Android package remains `com.sashin.hippoos`.
- [x] Android 16 / API 36 target retained.
- [x] Hybrid CI validates animal generation, audio generation, Godot parse/smoke, Flutter analysis/tests and Android build.
- [ ] Hybrid CI fully green on current release head.
- [ ] Release signing key configured outside repository.
- [ ] Release AAB exported and validated in Play Console.

## Camera / POV
- [x] Cinematic view.
- [x] Caretaker view.
- [x] Bodycam view.
- [x] Overhead view.
- [x] Bodycam reduced-motion stabilization behavior.
- [ ] Bodycam camera clipping/occlusion verified on-device in all habitats.
- [ ] Optional device motion/gyro enhancement evaluated after baseline QA.

## Real-world time
- [x] Device IANA timezone source implemented in Flutter.
- [x] Local ISO time, UTC offset, hour/minute and epoch are bridged to Godot.
- [x] Sync occurs at startup.
- [x] Sync occurs on resume.
- [x] Sync refreshes once per minute while active.
- [x] Sanctuary day/night presentation uses bridged local time with device-local fallback.
- [ ] Travel/timezone-change QA completed on-device.

## 4K quality gate
- [x] 4K launch contract documented in `Docs/FLUTTER_4K_LAUNCH_SPEC.md`.
- [x] Godot production base target raised to 3840 × 2160 and fixed 1280 × 720 stretch ceiling removed from the hybrid path.
- [x] Flutter UI is vector/resolution-independent and renders at device-native density.
- [x] Mobile texture master ceiling set at 4096 × 4096 where appropriate.
- [ ] 3840 × 2160 capture/photo path validated.
- [ ] Close Bodycam framing passes asset-quality review at 4K capture resolution.
- [ ] 4K-capable runtime performance verified on appropriate hardware.
- [ ] Dynamic performance fallback verified without visibly degrading launch-quality assets.

## Core sanctuary
- [x] Pygmy hippo, pig and Chinese Shar-Pei are the locked animal roster.
- [x] Species-specific behavior profiles.
- [x] Persistent needs, emotion, bond and preferences.
- [x] Offline progression.
- [x] Journal data foundation.
- [x] Rename support in simulation.
- [x] Persistent settings.
- [x] Independent audio buses.
- [x] Haptics and reduced-motion settings.
- [x] Save/background/corrupt-save handling.
- [ ] Journal UI fully migrated to Flutter.
- [ ] Settings/rename UI fully migrated to Flutter.
- [ ] First-run onboarding fully migrated to Flutter.
- [ ] About/Privacy/Credits fully migrated to Flutter.

## Animals / animation
- [x] Original Hippo OS model specifications for Mochi, Truffle and Bao.
- [x] Strict procedural model compiler/geometry validation in CI.
- [x] 31-joint skinned rigs generated for all three animals.
- [x] Idle/move/eat/rest base animation clips generated for all three animals.
- [ ] Final visual art-direction review in actual Flutter hybrid build.
- [ ] Species-specific signature animation coverage.
- [ ] Body-region interaction animation.
- [ ] Wetness/mud presentation for hippo and pig.
- [ ] Final mobile material/PBR-quality review.

## Audio
- [x] Original sanctuary ambience and interaction foley generation.
- [x] Licensed animal recording acquisition integrated into CI.
- [x] Contextual 3D animal playback architecture.
- [x] Footstep/water/mud/eating/drinking/UI sound architecture.
- [x] Credits/license data present in release source.
- [ ] All audio imports pass the current hybrid gate without warnings/errors.
- [ ] Audio and spatialization verified on-device.

## Environment
- [x] Separate habitat zones.
- [x] Pond, mud, vegetation and dynamic lighting foundation.
- [ ] Production water shader/ripple pass.
- [ ] Splash particles.
- [ ] Mud interaction/tracks.
- [ ] Production foliage/rocks/shelter enrichment.
- [ ] Camera collision/occlusion pass.
- [ ] Final day/night readability review at real device time.

## Store/legal
- [x] Privacy-policy draft.
- [x] Play listing draft.
- [x] Asset provenance register.
- [ ] Final support/privacy contact added.
- [ ] Final 512 × 512 Play icon exported.
- [ ] Google Play 1024 × 500 feature graphic exported from master artwork.
- [ ] Four final production screenshots captured, up to 3840 px on the longest side.
- [ ] Content rating completed in Play Console.
- [ ] Data safety completed in Play Console.
- [ ] Store category/target audience confirmed.

## Physical device QA
- [ ] Flutter hybrid installs without Godot editor.
- [ ] Launches from home-screen icon.
- [ ] Embedded Godot view appears correctly behind Flutter UI.
- [ ] Flutter ↔ Godot camera/action/status bridge passes.
- [ ] Cold launch passes 10 times.
- [ ] Background/foreground passes 10 cycles.
- [ ] Save survives forced app close.
- [ ] Settings survive restart.
- [ ] All three animals remain selectable after restart.
- [ ] Feed/pet/rename/journal pass.
- [ ] Android back navigation pass.
- [ ] Landscape lock pass.
- [ ] No UI overlap/cutoff on target phone.
- [ ] Bodycam/cinematic/caretaker/overhead all pass.
- [ ] Real timezone behavior passes.
- [ ] Performance acceptable in all habitats.
- [ ] Audio/haptics pass.
- [ ] 30-minute soak test without crash.

The app is not declared launch-ready until every applicable unchecked item is passed or explicitly removed from 1.0 scope with a documented reason. No user-facing APK is distributed before that condition is met.
