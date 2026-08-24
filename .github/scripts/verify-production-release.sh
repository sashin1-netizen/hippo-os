#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$PWD}"
GODOT="$ROOT/godot"

required_files=(
  "$GODOT/assets/animals/mochi.glb"
  "$GODOT/assets/animals/porky.glb"
  "$GODOT/assets/animals/bao.glb"
  "$GODOT/assets/production/release-assets.json"
  "$GODOT/assets/production/habitat-release.json"
  "$GODOT/assets/production/device-acceptance.json"
  "$ROOT/Docs/VISUAL_ACCEPTANCE.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "::error::Production release blocked: missing required file ${file#$ROOT/}" >&2
    exit 1
  fi
done

python3 - "$GODOT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
assets = json.loads((root / 'assets/production/release-assets.json').read_text())
habitat = json.loads((root / 'assets/production/habitat-release.json').read_text())
acceptance = json.loads((root / 'assets/production/device-acceptance.json').read_text())

required_species = {
    'hippo': ('mochi.glb', 90000),
    'pig': ('porky.glb', 70000),
    'dog': ('bao.glb', 85000),
}
required_clips = {'idle','walk','run','turn','sleep','wake','eat','drink','play','pet','call'}
MIN_SOURCE_TEXTURE_PX = 4096

models = assets.get('models', {})
for species, (filename, max_triangles) in required_species.items():
    item = models.get(species)
    if not isinstance(item, dict):
        raise SystemExit(f'Production release blocked: missing {species} model metadata')
    if item.get('file') != f'assets/animals/{filename}':
        raise SystemExit(f'Production release blocked: wrong {species} file path')
    for field in ('source','license','sha256','artist_or_vendor'):
        if not str(item.get(field, '')).strip():
            raise SystemExit(f'Production release blocked: {species}.{field} is empty')
    if item.get('commercial_use_allowed') is not True:
        raise SystemExit(f'Production release blocked: {species} commercial-use permission not affirmed')
    if item.get('original_identity_confirmed') is not True:
        raise SystemExit(f'Production release blocked: {species} original identity not confirmed')
    tri = int(item.get('triangles', 0))
    if tri <= 0 or tri > max_triangles:
        raise SystemExit(f'Production release blocked: {species} triangle count {tri} exceeds mobile budget {max_triangles}')
    if item.get('rigged') is not True:
        raise SystemExit(f'Production release blocked: {species} is not marked rigged')
    source_px = int(item.get('texture_source_px', 0))
    if source_px < MIN_SOURCE_TEXTURE_PX:
        raise SystemExit(
            f'Production release blocked: {species} texture_source_px={source_px}; '
            f'{MIN_SOURCE_TEXTURE_PX}px genuine PBR source art is required'
        )
    clips = {str(x).lower() for x in item.get('animations', [])}
    missing = sorted(required_clips - clips)
    if missing:
        raise SystemExit(f'Production release blocked: {species} missing authored animation metadata: {missing}')
    for texture in ('base_color','normal','roughness'):
        if not str(item.get('textures', {}).get(texture, '')).strip():
            raise SystemExit(f'Production release blocked: {species} missing {texture} texture metadata')

for field in ('ground','water','rocks','vegetation'):
    item = habitat.get(field)
    if not isinstance(item, dict) or item.get('production_ready') is not True:
        raise SystemExit(f'Production release blocked: habitat {field} not approved')
    for meta in ('source','license'):
        if not str(item.get(meta, '')).strip():
            raise SystemExit(f'Production release blocked: habitat {field}.{meta} empty')
    source_px = int(item.get('texture_source_px', 0))
    if source_px < MIN_SOURCE_TEXTURE_PX:
        raise SystemExit(
            f'Production release blocked: habitat {field}.texture_source_px={source_px}; '
            f'{MIN_SOURCE_TEXTURE_PX}px source art is required for the 4K production master'
        )

required_device_checks = [
    'installs_on_target_phone','launches_from_home_screen','device_check_passes',
    'speaker_audio_passes','bluetooth_audio_passes','save_restart_passes',
    'background_resume_passes','offline_progression_passes','safe_area_passes',
    'vfx_passes','ui_visual_acceptance_passes','performance_passes',
    'production_visual_acceptance_passes','no_blank_or_black_render_passes',
    'no_runtime_shader_errors_passes','reference_layout_match_passes',
    'reference_interaction_match_passes','all_exposed_controls_functional_passes',
    'no_placeholder_geometry_passes','animal_realism_approved',
    'habitat_realism_approved','camera_framing_approved','ui_finish_approved'
]
for key in required_device_checks:
    if acceptance.get(key) is not True:
        raise SystemExit(f'Production release blocked: device acceptance {key}=true is required')

if acceptance.get('visual_reference_id') != 'grasslands-sanctuary-v1':
    raise SystemExit('Production release blocked: visual_reference_id must be grasslands-sanctuary-v1')

screens = acceptance.get('accepted_phone_screenshots', [])
required_screens = {
    'mochi_hero','porky_selected','bao_selected','main_hud','journal',
    'camera_bodycam','map','sanctuary_customize'
}
if not isinstance(screens, list) or not required_screens.issubset({str(x) for x in screens}):
    missing = sorted(required_screens - {str(x) for x in screens}) if isinstance(screens, list) else sorted(required_screens)
    raise SystemExit(f'Production release blocked: missing accepted real-phone screenshot evidence: {missing}')

reviewer = str(acceptance.get('visual_acceptance_reviewer', '')).strip()
reviewed_at = str(acceptance.get('visual_acceptance_reviewed_at', '')).strip()
if not reviewer or not reviewed_at:
    raise SystemExit('Production release blocked: final visual acceptance reviewer and review timestamp are required')

print('Production release asset + 4K source-art + device + Grasslands visual acceptance gate passed.')
PY

for model in mochi porky bao; do
  sha256sum "$GODOT/assets/animals/$model.glb"
done
