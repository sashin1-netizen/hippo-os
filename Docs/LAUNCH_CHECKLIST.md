# Hippo OS 1.0 Personal Launch Checklist

Branch: `release/flutter-4k-v1`

## Release definition — mandatory
- [x] Hippo OS 1.0 is for personal/private use, not public app-store distribution.
- [x] Internal APK builds may be generated for CI validation only.
- [x] No APK or download link is handed to the user while any personal-launch gate remains open.
- [x] The next user-facing APK must be the finished personal launch build.
- [x] Placeholder animal geometry and silent placeholder audio are forbidden.
- [x] Google Play closed testing, Play Console production access, AAB publication, store listing, content rating and Data Safety are out of scope for 1.0 personal launch.

## Production architecture
- [x] Flutter 3.44.7 selected as the user-facing application shell.
- [x] Godot 4.7.2 retained as the embedded real-time 3D sanctuary renderer.
- [x] Android PlatformView host implemented for the Godot surface.
- [x] Bidirectional Flutter ↔ Godot bridge implemented.
- [x] Android package remains `com.sashin.hippoos`.
- [x] Android 16 / API 36 target retained.
- [x] Hybrid CI validates animal generation, audio generation, Godot parse/smoke, Flutter analysis/tests and Android build.
- [ ] Hybrid CI fully green on current release head.
- [ ] Final personal release APK is signed with a stable private signing key.
- [ ] Final signed APK installs as an update over the previous personal build where applicable.

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
- [ ] Timezone-change QA completed on-device.

## 4K quality gate
- [x] 4K launch contract documented in `Docs/FLUTTER_4K_LAUNCH_SPEC.md`.
- [x] Godot production base target raised to 3840 × 2160 and fixed 1280 × 720 stretch ceiling removed from the hybrid path.
- [x] Flutter UI is vector/resolution-independent and renders at device-native density.
- [x] Mobile texture master ceiling set at 4096 × 4096 where appropriate.
- [ ] 3840 × 2160 capture/photo path validated.
- [ ] Close Bodycam framing passes asset-quality review at 4K capture resolution.
- [ ] 4K-capable runtime performance verified on appropriate hardware when available.
- [ ] Dynamic performance fallback verified without visibly degrading launch-quality assets on the target phone.

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
- [x] Living-world/customisation state foundation.
- [ ] Journal UI fully migrated to Flutter.
- [ ] Settings/rename UI fully migrated to Flutter.
- [ ] First-run onboarding fully migrated to Flutter.
- [ ] About/Privacy/Credits fully migrated to Flutter.
- [ ] Full customisation UI is persisted and restored correctly.

## Animals / animation / living behaviour
- [x] Original Hippo OS model specifications for Mochi, Truffle and Bao.
- [x] Strict procedural model compiler/geometry validation in CI.
- [x] 31-joint skinned rigs generated for all three animals.
- [x] Idle/move/eat/rest base animation clips generated for all three animals.
- [x] Persistent memory, preferences, relationship/bond state and autonomous decisions.
- [ ] Final visual art-direction review in actual Flutter hybrid build.
- [ ] Species-specific signature animation coverage.
- [ ] Body-region interaction animation.
- [ ] Wetness/mud presentation for hippo and pig.
- [ ] Final mobile material/PBR-quality review.
- [ ] Custom animal appearance and baseline temperament changes visibly apply without erasing learned memory.

## Audio
- [x] Original sanctuary ambience and interaction foley generation.
- [x] Licensed animal recording acquisition integrated into CI.
- [x] Contextual 3D animal playback architecture.
- [x] Footstep/water/mud/eating/drinking/UI sound architecture.
- [x] Credits/license data present in release source.
- [ ] All audio imports pass the current hybrid gate without warnings/errors.
- [ ] Audio and spatialization verified on-device.

## Living environment
- [x] Separate habitat zones.
- [x] Pond, mud, vegetation and dynamic lighting foundation.
- [x] Real-time living-world state for wind, humidity, cloudiness, dampness, water activity and world age.
- [x] Customisation architecture for vegetation, water, mud, light warmth, weather, wind and world motion.
- [ ] Production water shader/ripple pass.
- [ ] Splash particles.
- [ ] Mud interaction/tracks.
- [ ] Production foliage/rocks/shelter enrichment.
- [ ] Camera collision/occlusion pass.
- [ ] Final day/night readability review at real device time.
- [ ] Living-world customisation visibly changes the rendered sanctuary in real time.

## Personal-use packaging/legal
- [x] Asset provenance register retained.
- [x] Credits/license data retained even for private use.
- [x] Privacy behavior remains local-first/no account/no analytics unless intentionally changed later.
- [ ] Final launcher icon and splash are production quality.
- [ ] Final APK version name/code locked.
- [ ] Private signing key backed up securely outside the repository.
- [ ] Final release APK checksum recorded.

## Physical device QA — mandatory
- [ ] Flutter hybrid installs without Godot editor.
- [ ] Launches from home-screen icon.
- [ ] Embedded Godot view appears correctly behind Flutter UI.
- [ ] Flutter ↔ Godot camera/action/status/customisation bridge passes.
- [ ] Cold launch passes 10 times.
- [ ] Background/foreground passes 10 cycles.
- [ ] Save survives forced app close.
- [ ] Settings and customisation survive restart.
- [ ] All three animals remain selectable after restart.
- [ ] Feed/pet/rename/journal/customise pass.
- [ ] Android back navigation pass.
- [ ] Landscape lock pass.
- [ ] No UI overlap/cutoff on target phone.
- [ ] Bodycam/cinematic/caretaker/overhead all pass.
- [ ] Real timezone behavior passes.
- [ ] Performance acceptable in all habitats.
- [ ] Audio/haptics pass.
- [ ] 30-minute soak test without crash.

Hippo OS is not declared personally launch-ready until every applicable unchecked item above is passed or explicitly removed from 1.0 scope with a documented reason. No user-facing APK is distributed before that condition is met.
