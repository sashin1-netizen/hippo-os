# Hippo OS Coding Standards

## Objective

Write production code that preserves clear ownership, deterministic behaviour, mobile performance and verifiable release evidence. Prefer a small number of authoritative systems over patches that compete for the same state.

## 1. Architecture before implementation

Every change must identify which layer owns it:

- **Presentation** renders state and collects user intent.
- **Domain/simulation** owns companion rules, needs, behaviour and interaction outcomes.
- **Data/persistence** owns durable local state and migrations.
- **Infrastructure/platform** owns assets, Android integration, rendering compatibility and future networking.

If a change needs two layers, define the boundary explicitly rather than letting either side reach through the other.

## 2. Single-writer rule

A mutable concept has one authoritative writer. Other systems may observe it or request an action that changes it.

Current examples:

- Mochi core simulation state: `main.gd`.
- Porky/Bao simulation state: `CompanionRoster`.
- memories/customization: `AppCompleteness`.
- normal camera motion: `HeroCameraDirector`.
- launch composition/visibility/proof readiness: `FinalPresentationDirector`.
- animal visual replacement and authored animation bridging: `ProductionAssetLoader`.
- primary runtime HUD: `SanctuaryHUD`.

Do not create another manager for a responsibility that already has an owner.

## 3. Unidirectional flow

Use this default control flow:

```text
input -> intent/action -> domain mutation -> persistence -> presentation refresh
```

UI code must not maintain a second copy of companion truth. Presentation code must not alter needs or relationship values merely to make a frame look correct.

## 4. Explicit contracts

Use names, constants and narrow public methods that make subsystem contracts obvious. Runtime systems should fail safely when optional dependencies are unavailable and log a useful diagnostic rather than silently degrading into undefined state.

Critical launch markers and release conditions belong in CI contracts as well as runtime code.

## 5. Prefer composition over patch layers

When visual or behavioural fixes accumulate, consolidate them into the existing authority. Do not solve a conflict by adding a later process with a higher priority unless it is a temporary diagnostic measure with a removal plan.

World builders may construct geometry. They must not continue controlling presentation after `FinalPresentationDirector` takes authority.

## 6. Keep domain logic framework-light

Companion rules should be understandable without knowing renderer internals or UI layout. Avoid network, filesystem layout, Android APIs and scene styling inside behaviour decisions unless the dependency is intentionally abstracted.

## 7. Persistence discipline

All durable state must be:

- versioned;
- bounded and validated on load;
- written on relevant lifecycle transitions;
- backward-compatible through migration where practical;
- safe when a file is absent or malformed.

Offline elapsed-time simulation must be capped and humane. Absence must not destroy progress or relationships.

## 8. Mobile-first performance

Assume variable GPU/CPU capability, thermal throttling, interruption and memory pressure.

- Keep the hero animal's face/silhouette/animation quality ahead of background detail.
- Prefer bounded update frequencies for non-frame-critical work.
- Avoid allocations and scene-tree searches in tight per-frame loops when a cached reference is safe.
- Keep compatibility-renderer fallbacks deterministic and visually acceptable.
- Treat touch, tall aspect ratios, safe areas and reduced motion as first-class behaviour.

## 9. Asset and licensing discipline

Every third-party asset or substantial code dependency must have a known compatible licence and provenance. Pin external build-time assets by hash where practical.

Community assets are development fallbacks unless they meet the production-art contract. `mochi.glb`, `porky.glb` and `bao.glb` remain the production animal interface.

## 10. Error handling and diagnostics

Prefer actionable messages:

- what subsystem failed;
- what resource/contract was missing;
- whether fallback behaviour was used;
- whether the condition blocks release.

Do not turn recoverable optional-art absence into a crash. Do turn invalid release evidence into a failing CI gate.

## 11. Security boundary

The personal build is local-first. Do not embed server secrets or introduce direct remote dependencies into core simulation/UI.

Future connectivity must use an infrastructure/data boundary, HTTPS, platform-backed credential storage, explicit authentication, offline outbox semantics and conflict resolution.

## 12. Test the architecture, not only syntax

Repository Quality must reject regressions such as:

- duplicate required autoload authorities;
- reactivated legacy presentation managers;
- stale architecture documentation;
- UI taking ownership of companion persistence;
- launch readiness emitted without renderable animals/world/camera;
- direct network construction in core domain/UI;
- missing production asset interface names.

Android release evidence then validates import, package metadata, renderer behaviour, visual composition, update installation and physical-device acceptance.

## 13. Change checklist

Before merging a non-trivial change:

1. Name the owning layer and subsystem.
2. Confirm no second writer is introduced.
3. Preserve offline behaviour.
4. Check lifecycle and save implications.
5. Check Android performance/render-path implications.
6. Add or strengthen an automated contract when the failure could recur.
7. Keep fallbacks explicit and production claims accurate.
8. Run the full production gate before declaring launch readiness.
