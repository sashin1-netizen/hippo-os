extends Node

# Mobile-light day/night sky for the personal sanctuary build.
# ProceduralSkyMaterial is intentionally used instead of PhysicalSkyMaterial so the
# Compatibility-renderer build keeps a modest mobile cost while gaining a real sky.

var scene_root
var world_environment
var environment: Environment
var sky: Sky
var sky_material: ProceduralSkyMaterial
var update_timer := 0.0

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 70

func _process(delta):
    _ensure_binding()
    if not is_instance_valid(scene_root) or not environment or not sky_material:
        return

    update_timer -= delta
    if update_timer <= 0.0:
        update_timer = 8.0
        _apply_atmosphere()

func _ensure_binding():
    var current_scene := get_tree().current_scene
    if not current_scene:
        return
    if scene_root == current_scene and is_instance_valid(world_environment):
        return

    scene_root = current_scene
    world_environment = scene_root.find_child("WorldEnvironment", true, false)
    if not world_environment:
        # The core main scene creates the WorldEnvironment at runtime, so wait until it exists.
        return
    environment = world_environment.environment
    if not environment:
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

func _apply_atmosphere():
    var daylight := _daylight_factor()
    var twilight := _twilight_factor()

    var night_top := Color(0.012, 0.024, 0.070)
    var night_horizon := Color(0.075, 0.095, 0.155)
    var day_top := Color(0.20, 0.48, 0.70)
    var day_horizon := Color(0.72, 0.82, 0.72)
    var dusk_horizon := Color(0.86, 0.42, 0.24)

    sky_material.sky_top_color = night_top.lerp(day_top, daylight)
    var horizon := night_horizon.lerp(day_horizon, daylight)
    horizon = horizon.lerp(dusk_horizon, twilight * 0.55)
    sky_material.sky_horizon_color = horizon
    sky_material.ground_horizon_color = Color(0.08, 0.12, 0.09).lerp(Color(0.38, 0.43, 0.27), daylight)
    sky_material.ground_bottom_color = Color(0.018, 0.030, 0.026).lerp(Color(0.10, 0.18, 0.08), daylight)
    sky_material.sky_energy_multiplier = lerp(0.34, 0.92, daylight)
    sky_material.ground_energy_multiplier = lerp(0.20, 0.62, daylight)

func _daylight_factor():
    var mode := _lighting_mode()
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var hour := _decimal_hour()
    return clamp(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _twilight_factor():
    var mode := _lighting_mode()
    if mode != "auto":
        return 0.0
    var hour := _decimal_hour()
    var dawn := max(0.0, 1.0 - abs(hour - 6.0) / 1.6)
    var dusk := max(0.0, 1.0 - abs(hour - 18.0) / 1.6)
    return max(dawn, dusk)

func _decimal_hour():
    var now := Time.get_time_dict_from_system()
    return float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0

func _lighting_mode():
    if not is_instance_valid(scene_root):
        return "auto"
    var settings = scene_root.get("settings")
    if typeof(settings) == TYPE_DICTIONARY:
        return str(settings.get("day_night_mode", "auto"))
    return "auto"
