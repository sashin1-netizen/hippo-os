# Hippo OS Architecture

## Purpose

Hippo OS is a portrait-first, offline-first Android companion application built in Godot 4.7. The animal simulation is authoritative. UI, animation, sound, camera, VFX and rendering observe or present simulation state; they must not become competing sources of truth.

The personal build is intentionally local-first. A backend, accounts, push notifications and cloud sync are future capabilities, not hidden dependencies of the current experience.

## High-level design

```text
┌─────────────────────────────────────────────┐
│ Presentation                               │
│ SanctuaryHUD                               │
│ HeroCameraDirector                         │
│ FinalPresentationDirector                  │
│ CompanionAudio / AudioDirector             │
└──────────────────────┬──────────────────────┘
                       │ actions / observed state
                       ▼
┌─────────────────────────────────────────────┐
│ Domain / simulation                         │
│ main.gd - Mochi needs, personality, brain  │
│ CompanionRoster - Porky/Bao state & AI     │
│ GameplayDirector / CompanionLifeMotion      │
│ AppCompleteness - memories/customization    │
└──────────────────────┬──────────────────────┘
                       │ persistence contracts
                       ▼
┌─────────────────────────────────────────────┐
│ Data / persistence                          │
│ user://hippo_save.json                      │
│ user://companion_roster.json                │
│ user://hippo_app_features.json              │
│ SaveMigrator                                │
└──────────────────────┬──────────────────────┘
                       │ resources / device services
                       ▼
┌─────────────────────────────────────────────┐
│ Infrastructure / platform                   │
│ ProductionAssetLoader                       │
│ GrasslandsSanctuary / PBRHabitat            │
│ CompatibilityMobileFallback                 │
│ Android haptics, audio, lifecycle, storage  │
└─────────────────────────────────────────────┘
```

## Architectural rules

### 1. Single source of truth

Persistent companion state belongs to the simulation/data layer. UI controls request actions such as feed, pet, call, customize or camera changes; they do not own the underlying companion values.

For Mochi, `main.gd` currently owns core needs and behaviour state. `CompanionRoster` owns Porky/Bao companion state. `AppCompleteness` owns dated memories and sanctuary customization state. Each persistent field must have exactly one authoritative writer.

### 2. Unidirectional interaction flow

```text
User input
  -> SanctuaryHUD / touch input
  -> domain action
  -> simulation state changes
  -> persistence when required
  -> presentation refreshes from state
```

Presentation code should not directly duplicate or shadow business state. When a screen needs a derived value, derive it from authoritative state rather than storing a second mutable copy.

### 3. Offline-first data model

The app must remain fully usable without network access. Saves are local, versioned and migration-aware. On lifecycle pause/focus loss, important state is persisted. Offline elapsed time may advance needs within a bounded window, but absence must never cause death or catastrophic relationship loss.

Current save domains:

- `hippo_save.json`: Mochi identity, needs, bond, settings and interaction history.
- `companion_roster.json`: selected companion plus Porky/Bao state and position.
- `hippo_app_features.json`: memories and sanctuary customization.

A future cloud-sync layer must sit behind repository-style interfaces and reconcile with these local sources instead of making the UI call a remote API directly.

### 4. Domain behaviour

Needs are normalized values in `[0, 1]`:

- Hunger: `0 = full`, `1 = urgent hunger`
- Energy: `0 = exhausted`, `1 = rested`
- Affection: current social warmth
- Curiosity: stimulation/arousal
- Cleanliness: mud/wet presentation input
- Bond: persistent relationship progression

Personality is persistent and modifies action utility rather than selecting actions directly. Mochi currently uses weighted utility decisions across actions such as idle, wander, approach, explore, play, drink, mud and sleep. Porky and Bao use lighter companion action selection. Behaviour-tree or state-machine frameworks may be introduced only when they reduce complexity without compromising Android stability.

### 5. Presentation ownership

There must be one final visual authority for launch composition. `FinalPresentationDirector` owns final scene visibility, launch staging and proof readiness. `HeroCameraDirector` owns normal cinematic camera movement. `SanctuaryHUD` owns the primary interactive HUD.

World-building systems may construct geometry, but once their useful roots exist they must not continue fighting the final presentation authority for camera, visibility or lighting.

### 6. Asset hierarchy

Animal visual priority:

1. licensed Hippo OS production GLBs (`mochi.glb`, `porky.glb`, `bao.glb`)
2. approved pinned community fallback assets where available
3. procedural emergency visuals

Simulation bodies, collision, save state and behaviour remain stable when visuals are replaced. The production loader swaps only the visual hierarchy and maps live actions to authored animation clips.

Procedural or stylized fallback animals must never be described as final photoreal production art.

### 7. Mobile constraints

Hippo OS targets portrait Android first. Design and implementation must account for:

- device-safe areas and tall phone aspect ratios
- Android lifecycle interruption and process recreation
- intermittent or absent connectivity
- memory and VRAM pressure
- battery/CPU cost of continuous simulation and rendering
- renderer differences between Mobile/Vulkan hardware and Compatibility/OpenGL emulator paths
- touch-first controls, haptics and accessibility/reduced-motion settings

The hero companion receives the highest visual budget. Environment detail should degrade before the hero animal's face, silhouette and animation readability.

### 8. Security boundary

The current personal build has no required remote authentication or backend session. Therefore OAuth, tokens, API secrets and TLS pinning are not part of the current runtime architecture.

If connected features are added later:

- never embed reusable server secrets in the APK
- use HTTPS for all remote traffic
- use platform-backed secure storage for credentials/tokens
- use a standards-based user authentication flow appropriate to the service
- keep remote data behind a data/repository layer
- define conflict resolution and offline outbox semantics before enabling cross-device writes

### 9. Reliability and observability

Release confidence comes from evidence, not startup success alone. The branch requires:

- Godot import/parse/shader validation
- ARM64 Android export and package verification
- Android 16 install/launch proof
- pixel-based visual-regression validation
- installer/update proof for the existing package identity
- manual screenshot inspection
- final physical-device smoke testing before production 1.0

Runtime diagnostics may record renderer, device capability and presentation readiness, but should avoid collecting unnecessary personal data.

## Future connected architecture

Only when cloud features are actually required, extend the HLD as:

```text
Godot client
   │
   ├── Local repositories / offline state  ← authoritative while offline
   │
   └── Sync coordinator / outbox
              │ HTTPS
              ▼
        Mobile API / BFF
              │
        authenticated services
              │
        durable database + media storage
```

Cloud sync must be additive. A temporary network failure must not prevent feeding, petting, viewing the sanctuary, reading local memories or using the camera.

## Production boundaries

Personal-use completion and public production 1.0 are separate gates.

Personal-use completion requires a stable installable APK, correct package/update behaviour, working core interactions, persistent state, acceptable Android render evidence and a physical-device smoke test.

Public production 1.0 additionally requires final licensed photoreal Mochi/Porky/Bao assets, authored rigs/animations, secure production signing/release packaging, accessibility/performance review and final device acceptance.
