extends Node

const DAY_SKY_PATH = "res://assets/textures/kloofendal_38d_partly_cloudy_puresky.jpg"

var host
var environment
var day_sky
var day_material
var dusk_sky
var night_sky
var active_period = ""

func _ready():
    for i in range(6):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    environment = host.get("environment")
    if environment == null:
        return
    _build_skies()
    _apply_period(true)

func _process(_delta):
    if environment == null:
        return
    _apply_period(false)

func _build_skies():
    if ResourceLoader.exists(DAY_SKY_PATH):
        var panorama = load(DAY_SKY_PATH)
        if panorama is Texture2D:
            day_material = PanoramaSkyMaterial.new()
            day_material.panorama = panorama
            day_material.filter = true
            day_material.energy_multiplier = 0.92
            day_sky = Sky.new()
            day_sky.radiance_size = Sky.RADIANCE_SIZE_1024
            day_sky.sky_material = day_material

    var dusk_material = ProceduralSkyMaterial.new()
    dusk_material.sky_top_color = Color(0.08, 0.11, 0.20)
    dusk_material.sky_horizon_color = Color(0.72, 0.32, 0.16)
    dusk_material.ground_bottom_color = Color(0.025, 0.030, 0.026)
    dusk_material.ground_horizon_color = Color(0.22, 0.15, 0.10)
    dusk_material.sun_angle_max = 14.0
    dusk_material.sun_curve = 0.08
    dusk_sky = Sky.new()
    dusk_sky.radiance_size = Sky.RADIANCE_SIZE_512
    dusk_sky.sky_material = dusk_material

    var night_material = ProceduralSkyMaterial.new()
    night_material.sky_top_color = Color(0.004, 0.010, 0.035)
    night_material.sky_horizon_color = Color(0.025, 0.055, 0.095)
    night_material.ground_bottom_color = Color(0.003, 0.007, 0.008)
    night_material.ground_horizon_color = Color(0.010, 0.025, 0.026)
    night_material.sun_angle_max = 0.0
    night_sky = Sky.new()
    night_sky.radiance_size = Sky.RADIANCE_SIZE_512
    night_sky.sky_material = night_material

func _apply_period(force):
    var hour = _local_hour()
    var period = "day"
    if hour >= 19 or hour < 6:
        period = "night"
    elif hour >= 17 or hour < 7:
        period = "dusk"
    if not force and period == active_period:
        return
    active_period = period

    environment.background_mode = Environment.BG_SKY
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    if period == "day" and day_sky != null:
        environment.sky = day_sky
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        environment.ambient_light_energy = 0.78
    elif period == "dusk":
        environment.sky = dusk_sky
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        environment.ambient_light_color = Color(0.64, 0.46, 0.34)
        environment.ambient_light_energy = 0.78
    else:
        environment.sky = night_sky
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        environment.ambient_light_color = Color(0.18, 0.25, 0.38)
        environment.ambient_light_energy = 0.68

func _local_hour():
    if host != null and host.has_method("_effective_local_hour"):
        return int(host.call("_effective_local_hour"))
    return int(Time.get_time_dict_from_system().get("hour", 12))
