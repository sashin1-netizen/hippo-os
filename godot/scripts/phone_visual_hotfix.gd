extends Node

# Physical-phone hotfix for the production sanctuary.
# Keeps the modern SanctuaryHUD authoritative, removes legacy overlays that are
# re-enabled by the original scene loop, and provides a readable cinematic
# night exposure without changing the ARM64 Mobile/Vulkan renderer.

var scene_root: Node3D = null
var world_environment: WorldEnvironment = null
var sun_light: DirectionalLight3D = null
var fill_light: DirectionalLight3D = null
var update_timer: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 1000

func _process(delta: float) -> void:
    _ensure_binding()
    if not is_instance_valid(scene_root):
        return

    # The legacy scene sets its stats panel visible every frame. Defer the hide
    # so this remains authoritative regardless of process ordering.
    _hide_legacy_overlays()

    update_timer -= delta
    if update_timer <= 0.0:
        update_timer = 0.25
        _apply_phone_lighting()

func _ensure_binding() -> void:
    var current_scene: Node = get_tree().current_scene
    if not (current_scene is Node3D):
        return
    if scene_root == current_scene and is_instance_valid(world_environment):
        return

    scene_root = current_scene as Node3D
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    sun_light = _find_primary_sun(scene_root)
    fill_light = scene_root.find_child("PhoneReadabilityFill", true, false) as DirectionalLight3D
    if fill_light == null:
        fill_light = DirectionalLight3D.new()
        fill_light.name = "PhoneReadabilityFill"
        fill_light.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
        fill_light.shadow_enabled = false
        scene_root.add_child(fill_light)

func _find_primary_sun(root: Node) -> DirectionalLight3D:
    var lights: Array[Node] = root.find_children("*", "DirectionalLight3D", true, false)
    for node: Node in lights:
        if node is DirectionalLight3D and node.name != "PhoneReadabilityFill":
            return node as DirectionalLight3D
    return null

func _hide_legacy_overlays() -> void:
    if not is_instance_valid(scene_root):
        return

    var stats_variant: Variant = scene_root.get("stats_panel")
    if stats_variant is Control:
        var legacy_stats := stats_variant as Control
        if legacy_stats.visible:
            legacy_stats.set_deferred("visible", false)

    var personal_ui: Node = scene_root.find_child("PersonalUseUI", true, false)
    if personal_ui is CanvasLayer:
        var legacy_personal := personal_ui as CanvasLayer
        if legacy_personal.visible:
            legacy_personal.set_deferred("visible", false)

func _apply_phone_lighting() -> void:
    if world_environment == null or world_environment.environment == null:
        return

    var daylight: float = _daylight_factor()
    var environment: Environment = world_environment.environment

    # Keep night visibly nocturnal while ensuring animal skin, eyes, water and
    # terrain remain readable on real OLED/LCD phone panels.
    var night_ambient := Color(0.38, 0.46, 0.64)
    var day_ambient := Color(0.61, 0.75, 0.64)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = night_ambient.lerp(day_ambient, daylight)
    environment.ambient_light_energy = lerpf(1.10, 0.94, daylight)

    if is_instance_valid(sun_light):
        sun_light.light_color = Color(0.62, 0.72, 0.95).lerp(Color(1.0, 0.96, 0.88), daylight)
        sun_light.light_energy = lerpf(0.54, 1.28, daylight)

    if is_instance_valid(fill_light):
        fill_light.light_color = Color(0.55, 0.66, 0.94).lerp(Color(0.86, 0.93, 0.88), daylight)
        fill_light.light_energy = lerpf(0.42, 0.18, daylight)

func _daylight_factor() -> float:
    if not is_instance_valid(scene_root):
        return 1.0
    var mode: String = "auto"
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) == TYPE_DICTIONARY:
        mode = str((settings_variant as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0

    var now: Dictionary = Time.get_time_dict_from_system()
    var hour: float = float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
