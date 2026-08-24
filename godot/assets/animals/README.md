# Hippo OS production animal asset contract

Hippo OS keeps animal simulation, collision, saving, audio and interaction logic separate from the final rendered meshes. The `ProductionAssetLoader` automatically hot-swaps the procedural visuals when production GLB files exist at these exact paths:

- `res://assets/animals/mochi.glb` — original baby pygmy hippo
- `res://assets/animals/porky.glb` — pig
- `res://assets/animals/bao.glb` — Shar-Pei

## Required delivery standard

Final files should be mobile/game-ready rather than raw sculpt or photogrammetry exports.

### Geometry

- one clean skinned character per GLB
- correct real-world proportions and readable silhouette on a phone screen
- no visible self-intersections or detached anatomy
- approximately 15k–45k triangles per animal at the main mobile LOD
- no more than 65k triangles unless device profiling proves the cost is acceptable
- sensible material count (ideally 1–3 per animal)
- UV unwrapped
- normals/tangents exported
- mesh origin and forward direction consistent across all three animals

### Materials

- PBR base colour/albedo
- normal map for skin/fold/fur detail
- roughness map or sensible packed ORM texture
- no baked scene lighting in the albedo
- 1K–2K textures for the mobile build; 4K source art may be archived separately
- eye/nose/mouth materials may use separate roughness where needed

### Rig

- production skeleton with stable bone names
- weighted deformation tested at extreme poses
- head/neck, spine, four legs, feet/paws, ears and tail independently controllable
- jaw/mouth controls where applicable
- additional face/nostril controls are welcome but must not be required for basic playback

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

The current procedural animals remain a fallback so the project always opens and the Android build remains testable while final production art is being authored.