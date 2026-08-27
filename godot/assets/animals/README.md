# Hippo OS production animal asset contract

Hippo OS keeps animal simulation, collision, saving, audio and interaction logic separate from the final rendered meshes. The `ProductionAssetLoader` automatically hot-swaps the procedural visuals when production GLB files exist at these exact paths:

- `res://assets/animals/mochi.glb` — original baby pygmy hippo
- `res://assets/animals/porky.glb` — pig
- `res://assets/animals/bao.glb` — Shar-Pei

## Required delivery standard

Final files must be production, mobile/game-ready characters rather than raw sculpts, photogrammetry dumps, low-poly placeholders or visibly procedural primitive assemblies.

### Geometry

- one clean skinned character per GLB
- correct species/breed proportions and a believable silhouette at close hero-camera distance
- no visible self-intersections, detached anatomy or collapsed joints
- approximately 20k–55k triangles per animal at the main mobile LOD
- no more than the release-gate species budget unless profiling proves the cost is acceptable
- sensible material count, ideally 1–3 materials per animal
- UV unwrapped with enough texel density for close facial shots
- normals/tangents exported
- mesh origin and forward direction consistent across all three animals

### 4K PBR source standard

The production art master for each animal must contain genuine 4096×4096 source maps for the hero skin/coat material. Upscaling a smaller image to 4K does not satisfy this requirement.

Required source maps:

- 4K base colour/albedo
- 4K tangent-space normal map
- 4K roughness map or a documented 4K packed ORM equivalent
- AO where it materially improves folds/crevices
- no baked scene lighting in albedo

The Android build may use GPU mip levels automatically at distance and may package optimized ASTC/ETC2 texture data. That is intentional: a 4K source texture should not be sampled at full resolution for a distant animal. The selected hero animal must retain enough texture detail for close-up facial/skin/fold shots without visible blur or blockiness.

Eyes, nose and mouth may use dedicated smaller maps when physically appropriate, but the main skin/coat set must originate at 4K.

### Rig

- production skeleton with stable bone names
- weighted deformation tested at extreme poses
- head/neck, spine, four legs, feet/paws, ears and tail independently controllable
- jaw/mouth controls where applicable
- additional face/nostril controls are encouraged
- grounded foot placement without visible skating during authored locomotion

### Animation naming

The loader understands common idle names automatically. Final animation delivery should use these canonical clips where possible:

- `idle`
- `walk`
- `run`
- `turn_left`
- `turn_right`
- `sleep`
- `wake`
- `eat`
- `drink`
- `play`
- `pet_react`
- `call_react`

Mochi should additionally include `mud`, `water_play`, `yawn` and `zoomies`. Bao should include a restrained alert/watch animation; Porky should include sniff/root behaviour.

## Identity and licensing

Mochi must be an original baby pygmy-hippo identity. Do not directly copy Moo Deng or another identifiable zoo animal. Any third-party base mesh must have a licence compatible with the intended distribution and must retain required attribution/source records in the repository.

The current procedural animals remain a fallback so the project always opens and the Android build remains testable while final production art is being authored. They are not sufficient for a public 1.0 release.