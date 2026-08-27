# Hippo OS Asset Tiers

Hippo OS deliberately separates development/community assets from production 1.0 art.

## Tier A — Production 1.0

Only these paths satisfy the public-release animal gate:

- `godot/assets/animals/mochi.glb`
- `godot/assets/animals/porky.glb`
- `godot/assets/animals/bao.glb`

Each production animal must be a properly licensed, high-detail, rigged mobile-ready GLB with genuine PBR source art and authored animation metadata. `release-assets.json` must record source/vendor, licence, SHA-256, commercial-use permission, triangle count, 4K-or-better source texture resolution and animation coverage.

Required production animation coverage is enforced by `.github/scripts/verify-production-release.sh`. Community fallbacks, procedural anatomy and generated development rigs cannot satisfy this tier.

## Tier B — Community development fallback

These assets exist to keep personal/dev builds playable while production art is unfinished:

- pinned CC0 Gobkit hippo/scenery;
- pinned MIT anyCreature-generated quadrupeds;
- other explicitly documented permissive assets under `godot/assets/animals/community/` or `godot/assets/community/`.

`ProductionAssetLoader` may use these only when the Tier A file for that species is absent. They must never be represented as final photoreal production art.

## Tier C — Procedural emergency fallback

Primitive/procedural companion geometry is an emergency development path only. It is allowed to keep the simulation functional when no authored asset exists, but is prohibited from satisfying visual or production acceptance.

## Source priority

Runtime model priority is fixed:

1. Tier A production GLB;
2. exact-species pinned permissive authored asset;
3. pinned generated development GLB;
4. procedural emergency fallback.

## Release rule

The Play Store/public 1.0 gate fails unless all three Tier A animals exist and `.github/scripts/verify-production-release.sh` passes. Automated emulator visual evidence is diagnostic; final realism approval still requires the physical target Android phone and the `Grasslands Sanctuary` acceptance contract in `Docs/VISUAL_ACCEPTANCE.md`.
