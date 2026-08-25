extends Node

# Evidence-driven final presentation cleanup.
# Removes stale startup/legacy overlays, re-clears late-built foreground geometry,
# and applies restrained exposure correction after every visual layer has finished.
# It intentionally does not touch production animal rigs or Android packaging.

var scene_root: Node3D
var world_environment: WorldEnvironment
var cleanup_timer := 0.0
var exposure_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 2400
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(420):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            break
        await get_tree().process_frame
    if scene_root == null:
        push_warning("PresentationCleanup could not bind to the sanctuary")
        return
    _apply_cleanup()

func _process(delta: float) -> void:
    if scene_root == null or not is_instance_valid(scene_root):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
        else:
            return

    cleanup_timer -= delta
    exposure_timer -= delta
    if cleanup_timer <= 0.0:
        cleanup_timer = 0.20
        _remove_stale_overlays()
        _clear_late_foreground_geometry()
        _clear_late_grass_corridor()
    if exposure_timer <= 0.0:
        exposure_timer = 0.40
        _apply_exposure_finish()

func _apply_cleanup() -> void:
    _remove_stale_overlays()
    _clear_late_foreground_geometry()
    _clear_late_grass_corridor()
    _apply_exposure_finish()

func _remove_stale_overlays() -> void:
    # The old personal startup screen was still visible in the accepted Android 16
    # evidence frame long after the sanctuary had rendered. The modern sanctuary HUD
    # is now the authoritative launch presentation, so remove the stale layer entirely.
    var startup := scene_root.find_child("StartupExperience", true, false)
    if startup != null and is_instance_valid(startup):
        startup.queue_free()

    # Legacy personal controls are retained in code for settings/data compatibility,
    # but must never compete with the production sanctuary HUD.
    var personal_ui := scene_root.find_child("PersonalUseUI", true, false)
    if personal_ui is CanvasLayer:
        (personal_ui as CanvasLayer).visible = false

    var stats_variant: Variant = scene_root.get("stats_panel")
    if stats_variant is Control:
        (stats_variant as Control).visible = false

func _clear_late_foreground_geometry() -> void:
    var premium := scene_root.find_child("PremiumExperienceWorld", true, false) as Node3D
    if premium == null:
        return

    # PremiumExperience is assembled asynchronously. Re-run this cleanup after it has
    # finished so the enrichment frame at z~4 cannot sit between camera and Mochi.
    for child in premium.get_children():
        if not (child is GeometryInstance3D and child is Node3D):
            continue
        var visual := child as GeometryInstance3D
        var p := (child as Node3D).position
        var foreground_enrichment := p.z > 2.85 and absf(p.x) < 1.85 and p.y > 0.18 and p.y < 1.95
        if foreground_enrichment:
            visual.visible = false

func _clear_late_grass_corridor() -> void:
    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass == null or grass.multimesh == null:
        return
    if bool(grass.get_meta("hero_corridor_clean", false)):
        return

    var multi := grass.multimesh
    for i in range(multi.instance_count):
        var transform := multi.get_instance_transform(i)
        var p := transform.origin
        var hero_zone := Vector2(p.x, p.z).length() < 3.15
        var camera_lane := absf(p.x) < 2.15 and p.z > 0.65
        if hero_zone or camera_lane:
            transform.basis = transform.basis.scaled(Vector3(0.82, 0.30, 0.82))
            transform.origin.y *= 0.34
            multi.set_instance_transform(i, transform)
    grass.set_meta("hero_corridor_clean", true)

func _apply_exposure_finish() -> void:
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return

    var environment := world_environment.environment
    var daylight := _daylight_factor()

    # Preserve a recognisable night scene while lifting the middle tones that were
    # almost black in the Android 16 evidence frame. This is a small presentation
    # finish on top of the existing physically motivated lights, not a flat emissive hack.
    environment.adjustment_enabled = true
    environment.adjustment_brightness = lerpf(1.08, 1.18, daylight)
    environment.adjustment_contrast = lerpf(1.02, 1.05, daylight)
    environment.adjustment_saturation = lerpf(0.92, 1.04, daylight)
    environment.ambient_light_energy = maxf(environment.ambient_light_energy, lerpf(1.18, 1.24, daylight))

func _daylight_factor() -> float:
    var mode := "auto"
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) == TYPE_DICTIONARY:
        mode = str((settings_variant as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0

    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
