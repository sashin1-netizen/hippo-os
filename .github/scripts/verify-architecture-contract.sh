#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

fail() {
  echo "Architecture contract failed: $*" >&2
  exit 1
}

require_file() {
  test -s "$1" || fail "missing required file $1"
}

require_text() {
  grep -Fq "$2" "$1" || fail "$1 is missing required contract: $2"
}

require_file Docs/ARCHITECTURE.md
require_file Docs/CODING_STANDARDS.md
require_file godot/project.godot
require_file godot/scripts/main.gd
require_file godot/scripts/companion_roster.gd
require_file godot/scripts/gameplay_director.gd
require_file godot/scripts/sanctuary_hud.gd
require_file godot/scripts/hero_camera_director.gd
require_file godot/scripts/production_asset_loader.gd
require_file godot/scripts/final_presentation_director.gd

require_text Docs/ARCHITECTURE.md 'Hippo OS is a portrait-first, offline-first Android companion application built in Godot 4.7.'
require_text Docs/ARCHITECTURE.md 'FinalPresentationDirector'
require_text Docs/ARCHITECTURE.md 'Unidirectional interaction flow'
require_text Docs/ARCHITECTURE.md 'Offline-first data model'
if grep -Eq 'AHippoCharacter|UHippoNeedsComponent|AHippoAIController|AHippoPlayerController' Docs/ARCHITECTURE.md; then
  fail 'ARCHITECTURE.md has regressed to the obsolete Unreal runtime model'
fi

for service in GameplayDirector SanctuaryHUD HeroCameraDirector ProductionAssetLoader FinalPresentationDirector; do
  count="$(grep -Ec "^${service}=" godot/project.godot || true)"
  [[ "$count" == "1" ]] || fail "$service must appear exactly once as an autoload (found $count)"
done

for legacy in \
  AtmospherePolish VisualSanctuaryPolish AnimalArtPolish PremiumExperience \
  LifelikeRendering CinematicQuality PhoneVisualHotfix ProductionQualityPass \
  PresentationCleanup ReferenceFidelityFinish OpenWorldReferenceFinish \
  EarlyReferenceGate CommunityShowcaseAuthority; do
  if grep -q "^${legacy}=" godot/project.godot; then
    fail "legacy presentation authority is active: ${legacy}"
  fi
done

require_text godot/scripts/main.gd 'const SAVE_PATH = "user://hippo_save.json"'
require_text godot/scripts/companion_roster.gd 'const SAVE_PATH = "user://companion_roster.json"'
require_text godot/scripts/app_completeness.gd 'const SAVE_PATH := "user://hippo_app_features.json"'

require_text godot/scripts/final_presentation_director.gd '_authoritative_animals_ready()'
require_text godot/scripts/final_presentation_director.gd '_authoritative_world_ready()'
require_text godot/scripts/final_presentation_director.gd '_camera_frames_hero()'
require_text godot/scripts/final_presentation_director.gd 'HippoOS community showcase ready'

require_text godot/scripts/hero_camera_director.gd 'camera.global_position = camera.global_position.lerp'
require_text godot/scripts/final_presentation_director.gd '_quarantine_legacy_builders'

if grep -Eq 'user://(hippo_save|companion_roster)\.json' godot/scripts/sanctuary_hud.gd; then
  fail 'SanctuaryHUD must not directly own core companion persistence'
fi

for model in mochi.glb porky.glb bao.glb; do
  require_text godot/scripts/production_asset_loader.gd "$model"
done

if grep -Eq 'HTTPRequest\.new\(\)|WebSocketPeer\.new\(\)' godot/scripts/main.gd godot/scripts/companion_roster.gd godot/scripts/sanctuary_hud.gd; then
  fail 'core domain/UI directly creates network clients; move connectivity behind an infrastructure boundary'
fi

echo 'Architecture contract: PASS'
