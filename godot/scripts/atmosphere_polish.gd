extends Node

# Mobile-light day/night sky for the personal sanctuary build.

var scene_root: Node = null
var world_environment: WorldEnvironment = null
var environment: Environment = null
var sky: Sky = null
var sky_material: ProceduralSkyMaterial = null
var update_timer: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 70

func _process(delta: float) -> void:
    _ensure_binding()
    if not is_instance_valid(scene_root) or environment == null or sky_material == null:
        return
    update_timer -= delta
    if update_timer <= 0.0:
        update_timer = 8.0
        _apply_atmosphere()

func _ensure_binding() -> void:
    var current_scene: Node = get_tree().current_scene
    if current_scene == null:
        return
    if scene_root == current_scene and is_instance_valid(world_environment):
        return

    scene_root = current_scene
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null:
        return
    environment = world_environment.environment
    if environment == null:
        return

    sky = Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_128
    sky_material = ProceduralSkyMaterial.new()
    sky_material.use_debanding = true
    sky_material.sun_angle_max = 20.0
    sky_material.sun_curve = 0.10
    sky_material.sky_curve = 0.12
    sky_material.ground_curve = 0.08
    sky.sky_material = sky_material
    environment.sky = sky
    environment.background_mode = Environment.BG_SKY
    _apply_atmosphere()

func _apply_atmosphere() -> void:
    var daylight: float = _daylight_factor()
    var twilight: float = _twilight_factor()
    var night_top: Color = Color(0.012, 0.024, 0.070)
    var night_horizon: Color = Color(0.075, 0.095, 0.155)
    var day_top: Color = Color(0.20, 0.48, 0.70)
    var day_horizon: Color = Color(0.72, 0.82, 0.72)
    var dusk_horizon: Color = Color(0.86, 0.42, 0.24)

    sky_material.sky_top_color = night_top.lerp(day_top, daylight)
    var horizon: Color = night_horizon.lerp(day_horizon, daylight)
    horizon = horizon.lerp(dusk_horizon, twilight * 0.55)
    sky_material.sky_horizon_color = horizon
    sky_material.ground_horizon_color = Color(0.08, 0.12, 0.09).lerp(Color(0.38, 0.43, 0.27), daylight)
    sky_material.ground_bottom_color = Color(0.018, 0.030, 0.026).lerp(Color(0.10, 0.18, 0.08), daylight)
    sky_material.sky_energy_multiplier = lerpf(0.34, 0.92, daylight)
    sky_material.ground_energy_multiplier = lerpf(0.20, 0.62, daylight)

func _daylight_factor() -> float:
    var mode: String = _lighting_mode()
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var hour: float = _decimal_hour()
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _twilight_factor() -> float:
    var mode: String = _lighting_mode()
    if mode != "auto":
        return 0.0
    var hour: float = _decimal_hour()
    var dawn: float = maxf(0.0, 1.0 - absf(hour - 6.0) / 1.6)
    var dusk: float = maxf(0.0, 1.0 - absf(hour - 18.0) / 1.6)
    return maxf(dawn, dusk)

func _decimal_hour() -> float:
    var now: Dictionary = Time.get_time_dict_from_system()
    return float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0

func _lighting_mode() -> String:
    if not is_instance_valid(scene_root):
        return "auto"
    var loaded_settings: Variant = scene_root.get("settings")
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        return str((loaded_settings as Dictionary).get("day_night_mode", "auto"))
    return "auto"
