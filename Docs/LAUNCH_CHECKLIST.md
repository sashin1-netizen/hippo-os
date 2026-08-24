# Hippo OS 1.0 Personal Production Launch Checklist

Branch: `release/flutter-4k-v1`

## Release definition — mandatory
- [x] Hippo OS 1.0 is for personal/private use, not public app-store distribution.
- [x] Personal use changes distribution only; production quality, security, stability and release engineering requirements remain mandatory.
- [x] Internal APK builds may be generated for CI validation only.
- [x] No APK or download link is handed to the user while any launch gate remains open.
- [x] The next user-facing APK must be the finished production launch build.
- [x] Placeholder animal geometry, placeholder UI, silent placeholder audio and debug-only presentation are forbidden.
- [x] Google Play closed testing, Play Console production access, store listing, feature graphic, content rating and Data Safety submission are distribution-only requirements and are out of scope for personal launch.

## Production architecture
- [x] Flutter 3.44.7 selected as the user-facing application shell.
- [x] Godot 4.7.2 retained as the embedded real-time 3D sanctuary renderer.
- [x] Android PlatformView host implemented for the Godot surface.
- [x] Bidirectional Flutter ↔ Godot bridge implemented.
- [x] Android package remains `com.sashin.hippoos`.
- [x] Android 16 / API 36 target retained.
- [x] Hybrid CI validates animal generation, audio generation, Godot parse/smoke, Flutter analysis/tests and Android build.
- [ ] Hybrid CI fully green on current release head.
- [ ] Zero release-blocking compiler, analyzer, parser, import or runtime errors.
- [ ] No debug flags, development menus, temporary labels or test credentials in final build.
- [ ] Final release build generated in release mode, not debug/profile mode.

## Android production packaging
- [ ] Final APK is signed with a stable private production signing key.
- [ ] Signing key is backed up securely outside the repository.
- [ ] Final signed APK installs cleanly on the target Android device.
- [ ] Final signed APK installs as an update over the previous personal build where package/signing compatibility applies.
- [ ] Version name and monotonically increasing version code are locked.
- [ ] 64-bit ARM build support verified.
- [ ] Minimum/target SDK values are documented and verified.
- [ ] Requested Android permissions are reduced to the minimum actually required.
- [ ] App operates correctly with optional permissions denied where applicable.
- [ ] Release APK checksum recorded.
- [ ] Rollback copy of the previous known-good build retained.

## Security / privacy / data integrity
- [x] Local-first architecture; no account requirement.
- [x] No analytics or advertising in the intended 1.0 personal build.
- [ ] No secrets, API keys, signing material or private credentials are bundled in source/assets/APK.
- [ ] Network access is absent unless a feature explicitly requires it; any required endpoints are documented.
- [ ] Save files validate expected schema/version before use.
- [ ] Corrupt-save recovery tested.
- [ ] Atomic save/backup behavior tested under forced-close conditions.
- [ ] Save migration from the prior Hippo OS format tested.
- [ ] Reset action requires explicit confirmation and does not leave partial state.
- [ ] Privacy/About/Credits accurately describe actual runtime behavior.

## Camera / POV
- [x] Cinematic view.
- [x] Caretaker view.
- [x] Bodycam view.
- [x] Overhead view.
- [x] Bodycam reduced-motion stabilization behavior.
- [ ] Bodycam camera clipping/occlusion verified on-device in all habitats.
- [ ] Camera collision prevents entering animal/environment geometry.
- [ ] Camera transitions do not cause nausea-inducing jumps or flashes.
- [ ] Optional device motion/gyro enhancement evaluated after baseline QA.

## Real-world time
- [x] Device IANA timezone source implemented in Flutter.
- [x] Local ISO time, UTC offset, hour/minute and epoch are bridged to Godot.
- [x] Sync occurs at startup.
- [x] Sync occurs on resume.
- [x] Sync refreshes once per minute while active.
- [x] Sanctuary day/night presentation uses bridged local time with device-local fallback.
- [ ] Timezone-change QA completed on-device.
- [ ] Manual clock/date changes do not corrupt progression.
- [ ] Large offline gaps are bounded safely and cannot create impossible needs/state values.

## 4K quality gate
- [x] 4K launch contract documented in `Docs/FLUTTER_4K_LAUNCH_SPEC.md`.
- [x] Godot production base target raised to 3840 × 2160 and fixed 1280 × 720 stretch ceiling removed from the hybrid path.
- [x] Flutter UI is vector/resolution-independent and renders at device-native density.
- [x] Mobile texture master ceiling set at 4096 × 4096 where appropriate.
- [ ] 3840 × 2160 capture/photo path validated.
- [ ] Close Bodycam framing passes asset-quality review at 4K capture resolution.
- [ ] 4K-capable runtime performance verified on appropriate hardware when available.
- [ ] Dynamic performance fallback verified without visibly degrading launch-quality assets on the target phone.
- [ ] No obviously upscaled, pixelated or low-resolution production asset remains visible at close range.

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
- [x] Save/background/corrupt-save handling foundation.
- [x] Living-world/customisation state foundation.
- [ ] Journal UI fully migrated to Flutter.
- [ ] Settings/rename UI fully migrated to Flutter.
- [ ] First-run onboarding fully migrated to Flutter.
- [ ] About/Privacy/Credits fully migrated to Flutter.
- [ ] Full customisation UI is persisted and restored correctly.
- [ ] Every visible setting has a working effect or is removed before release.

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
- [ ] Animals continue autonomous routines when the user does nothing.
- [ ] Animals can refuse/withdraw from interaction where state/personality warrants it.
- [ ] No impossible locomotion, hovering, foot sliding or mesh penetration during normal play.

## Audio
- [x] Original sanctuary ambience and interaction foley generation.
- [x] Licensed animal recording acquisition integrated into CI.
- [x] Contextual 3D animal playback architecture.
- [x] Footstep/water/mud/eating/drinking/UI sound architecture.
- [x] Credits/license data present in release source.
- [ ] All audio imports pass the current hybrid gate without warnings/errors.
- [ ] Audio and spatialization verified on-device.
- [ ] Master/animal/ambience/UI volume controls work independently.
- [ ] No clipping, excessive loudness, constant looping or obvious audio repetition during normal use.

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
- [ ] No visible z-fighting, broken normals, missing materials, black textures or obvious placeholder geometry.

## Accessibility / UX
- [x] Reduced-motion setting exists.
- [x] Haptics setting exists.
- [ ] Text size/accessibility scaling works throughout Flutter UI.
- [ ] Touch targets remain usable at supported interface scales.
- [ ] Important actions have clear labels/icons and do not rely on colour alone.
- [ ] Destructive reset is clearly separated from normal controls.
- [ ] Android back behavior is consistent across overlays/screens.
- [ ] First-run experience explains controls without forcing a long tutorial.
- [ ] UI remains readable in bright daytime and dark nighttime sanctuary states.

## Performance / reliability
- [ ] No sustained thermal runaway during normal use on target device.
- [ ] Frame pacing remains acceptable in all habitats and POV modes.
- [ ] Memory usage remains stable during a 30-minute soak test.
- [ ] No progressive audio-player, node, texture or resource leaks during the soak test.
- [ ] Cold start time is acceptable on target device.
- [ ] Background/resume does not duplicate simulation timers, audio or UI listeners.
- [ ] App survives low-memory/background lifecycle behavior without corrupting saves.
- [ ] No crash, freeze or ANR during required QA sequence.

## Production visual identity / legal
- [x] Asset provenance register retained.
- [x] Credits/license data retained even for private use.
- [ ] Final launcher icon and splash are production quality.
- [ ] Final visual identity is consistent across splash, Flutter shell and sanctuary.
- [ ] All third-party assets have verified licenses compatible with the intended use.
- [ ] Required attribution is included where applicable.
- [ ] No unverified copyrighted media remains in the production package.

## Physical device QA — mandatory
- [ ] Flutter hybrid installs without Godot editor.
- [ ] Launches from home-screen icon.
- [ ] Embedded Godot view appears correctly behind Flutter UI.
- [ ] Flutter ↔ Godot camera/action/status/customisation bridge passes.
- [ ] Cold launch passes 10 consecutive times.
- [ ] Background/foreground passes 10 consecutive cycles.
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
- [ ] 30-minute soak test without crash, freeze or state corruption.
- [ ] Final signed production APK is tested after signing, not only an unsigned/internal build.

Hippo OS is not declared launch-ready until every applicable production gate above is passed or explicitly removed from 1.0 scope with a documented technical reason. Personal use removes store-submission bureaucracy only; it does not reduce the production standard. No user-facing APK is distributed before that condition is met.
