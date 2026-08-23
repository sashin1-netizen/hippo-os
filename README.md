# Hippo OS 🦛

**A personal, offline-first virtual baby pygmy hippo companion built with Unreal Engine 5.8 for Android.**

> The hippo must feel like a living animal, not a menu-driven virtual pet.

## Mission

Hippo OS is designed around one highly believable original baby pygmy hippo: autonomous behaviour, touch interaction, persistent personality, memory, feeding, sleep, play, water, mud, zoomies and an evolving bond with its owner.

Moo Deng is behavioural inspiration only. The playable animal will have its own identity, model and personality.

## First playable

- autonomous needs and utility-based behaviour
- persistent personality and memory
- direct touch/petting input
- hunger, energy, affection, curiosity and cleanliness
- offline progression without punitive mechanics
- save/load
- Android-first controls
- sanctuary environment
- original high-fidelity baby pygmy hippo character

## Architecture

```text
HippoOS
├── Config/
├── Content/
├── Docs/
├── Source/HippoOS/
│   ├── Public/
│   └── Private/
├── .github/
├── .gitattributes
├── .gitignore
└── HippoOS.uproject
```

## Engineering principles

1. Simulation state is the source of truth; animation observes it.
2. The animal continues to have intent when the player does nothing.
3. Personality modifies decisions instead of merely changing cosmetic labels.
4. Touch is spatial and physical rather than a PET button.
5. The animal does not perfectly obey every interaction.
6. Offline absence never causes death or catastrophic bond loss.
7. Mobile performance is treated as a feature.
8. No multiplayer, ads, currencies, backend or account system until the core animal is convincing.

## Technology

- Unreal Engine 5.8
- C++ + Blueprints
- StateTree / utility AI hybrid
- Enhanced Input
- Android ARM64
- Vulkan/mobile renderer where supported
- Git LFS for Unreal binary assets

## Status

**Pre-alpha / foundation.** Core simulation architecture is being established before production character and environment assets are integrated.
