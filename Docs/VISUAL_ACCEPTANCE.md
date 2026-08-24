# Hippo OS — Grasslands Sanctuary Visual & UX Acceptance Contract

This document is a **release requirement**, not a moodboard.

The approved target is the `Grasslands Sanctuary` reference supplied on 2026-08-24. Hippo OS 1.0 must be visually and operationally comparable to that reference on the target Android phone before production release may pass.

## 1. Core visual result

The final app must read immediately as a premium, lifelike animal sanctuary rather than a prototype, low-poly diorama, or collection of primitives.

Required:

- A believable grasslands/savanna sanctuary rendered as real-time 3D.
- Natural sky, sunlight, depth, shadows, terrain, rocks, trees, grasses, water and shoreline detail.
- No flat placeholder ground, primitive-cylinder trees, obvious debug geometry, or toy-like materials in the production build.
- The selected companion must be the clear foreground hero, framed close enough for facial expression and skin/fur detail.
- Other owned companions must remain visibly alive in the habitat when appropriate instead of disappearing from the world.
- Water must visibly react to animals and movement.
- Animal surfaces must react convincingly to wetness, mud and changing light.
- Camera composition must feel intentional and cinematic while remaining interactive.

The reference is a quality target. The production scene must be original Hippo OS artwork and must not copy third-party protected assets or another product's trade dress.

## 2. Animal realism

### Mochi — baby pygmy hippo

Must have a production model with believable pygmy-hippo proportions, face, eyes, ears, nostrils, lips/mouth, feet, folds and skin micro-detail. Wet skin must show physically plausible darkening/specular response without looking plastic.

### Porky — pig

Must have a production pig model with believable body proportions, snout, ears, hooves, coat/skin variation and grounded locomotion.

### Bao — Shar-Pei

Must be recognisably a Shar-Pei through real breed-defining anatomy and folds, with believable coat/skin shading, paws, muzzle, ears, eyes and weight transfer.

All three animals require authored rigs/animation rather than visible procedural body-part wobbling in the final build.

Minimum production animation states:

`idle`, `walk`, `run`, `turn`, `sleep`, `wake`, `eat`, `drink`, `play`, `pet`, `call`, plus species-appropriate sniff/look/reaction states and the existing mud/water/zoomies behaviours where relevant.

## 3. Main-screen layout contract

The production main sanctuary screen must preserve the interaction hierarchy of the approved reference.

### Top-left companion card

Must show the selected companion with:

- portrait/avatar rendered from the real companion identity;
- name;
- life stage/species context;
- compact health/needs indicators;
- readable percentages or equivalent precise state display.

This must update when the selected animal changes.

### Top-centre identity

Hippo OS / Sanctuary branding must remain clearly readable without covering the animal or world.

### Top-right status area

Must provide:

- current sanctuary time;
- current sanctuary/weather condition;
- menu/settings access;
- a live minimap or equivalent spatial companion locator.

The minimap must represent actual in-app companion/world positions, not a decorative static image.

### Right-side action rail

At minimum:

- Feed
- Pet
- Journal
- Camera / Bodycam-style animal view

Each button must execute a real feature. No dead or decorative production controls.

### Lower-left movement/camera control

A touch control must provide intentional movement/orbit/bodycam navigation appropriate to the selected view. It must not conflict with direct petting gestures.

### Bottom navigation

The visual hierarchy must support the approved reference structure:

- Map
- Customize
- Shop or Collection/Inventory equivalent
- Sanctuary
- Social/Companions equivalent

For 1.0, any label shown in production must open a working destination. Features that are not implemented must not be represented as fake active buttons.

## 4. Interaction result

The sanctuary must operate as a living 3D space, not a rendered background.

Required:

- Select Mochi, Porky or Bao and move the camera focus to that animal.
- Pet the selected animal directly.
- Feed with selectable food and visible accept/refuse behaviour.
- Call an animal and receive a contextual response.
- Open the journal and see persistent companion history/memories.
- Enter camera/bodycam view and return safely.
- Open map/minimap and locate companions.
- Open sanctuary/customisation controls that actually affect the environment where exposed.
- Persist all supported changes across restart.
- Other companions continue autonomous behaviour while one companion is selected.

## 5. UI quality

- Premium translucent/dark glass panels similar in density and restraint to the approved reference, while retaining an original Hippo OS visual identity.
- Consistent spacing, radii, icon weight and typography.
- No developer/debug text in normal production UI.
- No oversized desktop-style boxes on phone.
- No obstructed UI under cutouts, status/navigation regions or rounded corners.
- All primary controls comfortably touchable with one hand in landscape/approved production orientation.
- UI must remain legible over bright sky, grass, water and dark animal surfaces.

## 6. Mobile rendering and performance

The target cannot be achieved by using a static screenshot as the world background. The animal and habitat must remain interactive real-time 3D.

Production acceptance requires:

- no black/blank rendered frames after launch;
- no shader compilation/link failures on the target phone;
- no missing textures/materials;
- no obvious geometry pop-in in the normal camera range;
- no sustained frame rate below 30 FPS during normal sanctuary use;
- target of 45–60 FPS during normal interaction on the acceptance phone;
- stable memory use during companion switching, camera mode, water/mud effects and background/resume;
- audio and haptics remain synchronized with interaction.

### Emulator evidence is diagnostic only

GitHub's Android emulator uses a software graphics stack (SwiftShader) and is useful for PackageManager install, launcher, lifecycle and crash testing. It is **not** the final visual authority for Hippo OS 1.0. Godot rendering behavior on software-emulated Android graphics can differ from a physical Vulkan/OpenGL phone.

Therefore:

- emulator screenshots and renderer logs remain CI diagnostic artifacts;
- an emulator black frame must be investigated and may block technical CI if it indicates a real app/runtime error;
- **emulator success cannot satisfy production visual acceptance**;
- production visual acceptance must be performed on the actual target Android phone using the production renderer and production assets.

## 7. Final screenshot comparison

Before 1.0 production approval, capture clean screenshots from the actual target Android phone for:

1. Mochi hero view in/near water.
2. Porky selected in the grasslands habitat.
3. Bao selected in the grasslands habitat.
4. Companion card + live minimap + action rail visible together.
5. Journal screen.
6. Camera/bodycam view.
7. Map screen.
8. Sanctuary/customisation screen.

The production reviewer must explicitly approve that these screenshots are visually comparable to the approved Grasslands Sanctuary reference in:

- animal realism;
- environment realism;
- lighting/material quality;
- camera framing;
- UI hierarchy and finish;
- absence of prototype/placeholder geometry.

## 8. Release rule

Hippo OS is **not launch-ready** simply because it installs, runs, exports an AAB, or passes automated tests.

Production release requires both:

1. automated technical gates; and
2. explicit real-device visual/interaction acceptance against this contract.

If the final phone build still resembles the earlier primitive sanctuary prototype more than the approved Grasslands reference, the release gate fails.