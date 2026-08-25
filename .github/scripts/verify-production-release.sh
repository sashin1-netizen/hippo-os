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
  "$GODOT/assets/production/technical-acceptance.json"
  "$ROOT/Docs/VISUAL_ACCEPTANCE.md"
  "$ROOT/Docs/ASSET_TIERS.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "::error::Production release blocked: missing required file ${file#$ROOT/}" >&2
    exit 1
  fi
done

python3 - "$GODOT" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
assets = json.loads((root / 'assets/production/release-assets.json').read_text())
habitat = json.loads((root / 'assets/production/habitat-release.json').read_text())
acceptance = json.loads((root / 'assets/production/device-acceptance.json').read_text())
technical = json.loads((root / 'assets/production/technical-acceptance.json').read_text())

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
    if item.get('asset_tier') != 'production':
        raise SystemExit(f'Production release blocked: {species}.asset_tier must be production')
    if item.get('development_fallback') is not False:
        raise SystemExit(f'Production release blocked: {species} is still marked as a development fallback')
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

# Lock the technical release sequence. Every machine/device gate must refer to the same
# candidate commit and the same APK checksum before the Play AAB workflow is eligible.
expected_order = [
    'repository_quality', 'godot_import', 'arm64_apk', 'x86_emulator_apk',
    'android16_authoritative_frame', 'apk_sha256', 'existing_app_update',
    'physical_android_install_smoke'
]
if technical.get('gate_order') != expected_order:
    raise SystemExit('Production release blocked: technical gate_order does not match the locked release sequence')

required_technical_checks = [
    'repository_quality_passes', 'godot_import_passes', 'arm64_apk_passes',
    'x86_emulator_apk_passes', 'android16_authoritative_frame_passes',
    'apk_sha256_verified', 'existing_app_update_passes',
    'physical_android_install_smoke_passes'
]
for key in required_technical_checks:
    if technical.get(key) is not True:
        raise SystemExit(f'Production release blocked: technical acceptance {key}=true is required')

source_commit = str(technical.get('source_commit_sha', '')).strip().lower()
apk_sha = str(technical.get('apk_sha256', '')).strip().lower()
if not re.fullmatch(r'[0-9a-f]{40}', source_commit):
    raise SystemExit('Production release blocked: technical source_commit_sha must be a 40-character Git SHA')
if not re.fullmatch(r'[0-9a-f]{64}', apk_sha):
    raise SystemExit('Production release blocked: technical apk_sha256 must be a 64-character SHA-256')
if technical.get('visual_reference_id') != 'grasslands-sanctuary-v1':
    raise SystemExit('Production release blocked: technical visual_reference_id must be grasslands-sanctuary-v1')
if float(technical.get('visual_regression_score', 0)) < 85.0:
    raise SystemExit('Production release blocked: automated visual_regression_score must be >= 85')

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

accepted_commit = str(acceptance.get('tested_commit_sha', '')).strip().lower()
accepted_apk_sha = str(acceptance.get('tested_apk_sha256', '')).strip().lower()
if accepted_commit != source_commit:
    raise SystemExit('Production release blocked: physical-device acceptance commit does not match technical gate commit')
if accepted_apk_sha != apk_sha:
    raise SystemExit('Production release blocked: physical-device APK SHA-256 does not match technical gate APK')

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

print('Production release asset + technical sequence + 4K source-art + physical-device Grasslands acceptance gate passed.')
PY

for model in mochi porky bao; do
  sha256sum "$GODOT/assets/animals/$model.glb"
done
