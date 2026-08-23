# Hippo OS 1.0 Launch Checklist

Branch: `release/android-v1-rc`

## Distribution hold — mandatory
- [x] Internal APK builds may be generated for CI validation only.
- [x] No APK, AAB, store package, or download link is to be handed to the user as a release candidate while any launch gate below remains open.
- [x] The next user-facing APK must be the launch-ready build after all applicable product, content, legal, store, and device-QA gates are green.
- [x] Placeholder / primitive animal models are explicitly disallowed from the launch build.
- [x] Placeholder / silent audio systems are explicitly disallowed from the launch build.
- [x] Store-facing screenshots and marketing assets must be captured from the final production build, not a prototype or internal RC.

## Build / platform
- [x] Dedicated release-candidate branch
- [x] Godot 4.7.2 project target
- [x] Google Play AAB targets Android 16 / API 36
- [x] ARM64 APK preset
- [x] Google Play AAB preset scaffold
- [x] Android CI import/parser/smoke-test workflow
- [x] Android ETC2/ASTC texture import enabled
- [x] Android-compatible PNG boot splash
- [x] App icon and branded startup assets
- [x] CI APK artifact confirmed green — run `32673021892`
- [x] Godot import/parser gate passed
- [x] Release self-test passed
- [x] Sanctuary headless smoke-launch passed
- [x] Standalone APK export passed
- [ ] Release signing key configured outside repository
- [ ] Release AAB exported and validated in Play Console

## Core app
- [x] Three selectable animals
- [x] Species-specific behaviour profiles
- [x] Persistent needs, emotion, bond and preferences
- [x] Offline progression
- [x] Journal foundation
- [x] Rename animals
- [x] Settings persistence
- [x] Master / animal / ambience / UI volume buses
- [x] Haptics toggle
- [x] Reduced-motion option
- [x] Dynamic day/night presentation
- [x] Android background / close saving
- [x] Corrupt-save recovery
- [x] First-run onboarding
- [x] Destructive reset flow with confirmation
- [x] Accessibility text-size control
- [x] About / Privacy screen in app
- [x] Version display

## Production animal quality
- [ ] Original production-quality baby pygmy hippo model
- [ ] Production pig model
- [ ] Production Chinese Shar-Pei model
- [ ] Mobile-optimised PBR materials
- [ ] Proper skeletons / rigs
- [ ] Walk / turn / idle / rest / eat animation coverage
- [ ] Species-specific signature animation coverage
- [ ] Body-region interaction animation
- [ ] Wetness / mud presentation for hippo and pig

## Audio
- [x] Independent audio buses and settings architecture
- [ ] Licensed production animal audio files bundled
- [ ] Sanctuary ambience bundled
- [ ] Contextual 3D spatial playback
- [ ] Footsteps, splashes, mud, eating, drinking and UI sounds verified
- [ ] Attribution screen for CC BY audio where required

## Environment
- [x] Separate habitat zones
- [x] Pond, mud and basic vegetation
- [x] Dynamic lighting
- [ ] Production water shader / ripples
- [ ] Splash particles
- [ ] Mud interaction / tracks
- [ ] Production foliage / rocks / shelter enrichment
- [ ] Camera collision / occlusion pass

## Legal / store
- [x] Privacy-policy draft
- [x] Play listing draft
- [x] Asset provenance register
- [ ] Final support/privacy contact added
- [ ] Final icon exported to 512x512 PNG
- [ ] 1280x720 feature graphic from final app art
- [ ] Four real 1920x1080 screenshots captured from final production build
- [ ] Content rating completed in Play Console
- [ ] Data safety completed in Play Console
- [ ] Store category / target audience confirmed

## Device QA
- [ ] Installs as standalone APK without Godot
- [ ] Launches from home-screen icon
- [ ] Cold launch passes 10 times
- [ ] Background / foreground passes 10 cycles
- [ ] Save survives forced app close
- [ ] Settings survive restart
- [ ] All three animals remain selectable after restart
- [ ] Feed / pet / rename / journal pass
- [ ] Back button pass
- [ ] Rotation / landscape lock pass
- [ ] No overlapping UI on target phone
- [ ] Performance acceptable in all three habitats
- [ ] Audio and haptics pass
- [ ] 30-minute soak test without crash

## Public Google Play gate
For a new personal Play Console account created after 13 November 2023, production access may require a closed test with at least 12 opted-in testers continuously for 14 days. This is an external store requirement and cannot be completed by source-code changes alone.

The app is not declared production-ready until every applicable unchecked item above is either passed or explicitly removed from version 1.0 scope with a documented reason. No user-facing APK is distributed before that condition is met.
