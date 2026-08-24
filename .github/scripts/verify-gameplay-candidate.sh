#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

require_file() {
  test -s "$1" || { echo "Missing required file: $1" >&2; exit 1; }
}

require_text() {
  local file="$1"
  local text="$2"
  grep -Fq "$text" "$file" || { echo "Missing contract in $file: $text" >&2; exit 1; }
}

require_file godot/project.godot
require_file godot/scripts/main.gd
require_file godot/scripts/companion_roster.gd
require_file godot/scripts/gameplay_director.gd
require_file godot/scripts/production_asset_loader.gd
require_file godot/scripts/grasslands_sanctuary.gd
require_file godot/scripts/sanctuary_hud.gd
require_file godot/scripts/hero_camera_director.gd
require_file godot/scripts/companion_audio.gd
require_file godot/scripts/lifelike_rendering.gd
require_file godot/scripts/cinematic_quality.gd
require_file godot/export_presets.cfg
require_file Docs/VISUAL_ACCEPTANCE.md
require_file Docs/GAMEPLAY_ACCEPTANCE.md

# Phone-first presentation contract.
require_text godot/project.godot 'size/viewport_width=720'
require_text godot/project.godot 'size/viewport_height=1280'
require_text godot/project.godot 'handheld/orientation=1'
require_text godot/project.godot 'GameplayDirector="*res://scripts/gameplay_director.gd"'
require_text godot/project.godot 'SanctuaryHUD="*res://scripts/sanctuary_hud.gd"'
require_text godot/project.godot 'HeroCameraDirector="*res://scripts/hero_camera_director.gd"'
require_text godot/project.godot 'ProductionAssetLoader="*res://scripts/production_asset_loader.gd"'

# Autonomous pygmy-hippo simulation contract.
for action in idle wander approach explore play drink mud sleep; do
  require_text godot/scripts/main.gd "\"$action\""
done
for need in hunger energy curiosity cleanliness bond wetness mud_coat; do
  require_text godot/scripts/main.gd "var $need"
done
require_text godot/scripts/main.gd '_update_brain(delta)'
require_text godot/scripts/main.gd '_update_surface_state(delta)'

# Pig + Shar-Pei must exist as autonomous sanctuary companions.
require_text godot/scripts/companion_roster.gd 'SPECIES_PIG = "pig"'
require_text godot/scripts/companion_roster.gd 'SPECIES_SHARPEI = "sharpei"'
for action in wander sniff play rest watch coming happy; do
  require_text godot/scripts/companion_roster.gd "\"$action\""
done

# Cross-creature director: low-cost simulation, welfare priorities, social encounters,
# ambient life and player-interaction recognition.
require_text godot/scripts/gameplay_director.gd 'TICK_INTERVAL := 0.25'
require_text godot/scripts/gameplay_director.gd '_recognize_player_interactions'
require_text godot/scripts/gameplay_director.gd '_recognize_social_encounters'
require_text godot/scripts/gameplay_director.gd '_enforce_welfare_priorities'
require_text godot/scripts/gameplay_director.gd '_inject_ambient_life'
require_text godot/scripts/gameplay_director.gd 'get_companion_mood'

# Production art/animation bridge must be ready for final rigged GLBs.
for model in mochi.glb porky.glb bao.glb; do
  require_text godot/scripts/production_asset_loader.gd "$model"
done
for animation in idle walk run sleep wake eat drink play pet_react call_react sniff mud water_play yawn zoomies; do
  require_text godot/scripts/production_asset_loader.gd "\"$animation\""
done

# Reference UI/gameplay controls must be present.
for control in FEED PET JOURNAL CAMERA MAP CUSTOMIZE SANCTUARY; do
  require_text godot/scripts/sanctuary_hud.gd "\"$control\""
done

# Android updater must use modern Gradle packaging and preserve installed identity.
require_text godot/export_presets.cfg 'name="Android Existing App Update"'
require_text godot/export_presets.cfg 'gradle_build/use_gradle_build=true'
require_text godot/export_presets.cfg 'gradle_build/compress_native_libraries=false'
require_text godot/export_presets.cfg 'package/unique_name="com.sashin.hippoos"'
require_text godot/export_presets.cfg 'version/code=104'

# Final 1.0 production art remains a separate hard release gate. Make its status explicit
# instead of silently treating procedural development visuals as final assets.
missing=0
for model in mochi.glb porky.glb bao.glb; do
  if [[ ! -s "godot/assets/animals/$model" ]]; then
    echo "NOTICE: final production model not present yet: godot/assets/animals/$model"
    missing=$((missing + 1))
  fi
done
if (( missing > 0 )); then
  echo "Gameplay candidate architecture: PASS. Final photorealistic 1.0 art gate: BLOCKED ($missing production GLBs missing)."
else
  echo "Gameplay candidate architecture: PASS. Production GLBs present; run verify-production-release.sh for final acceptance."
fi
