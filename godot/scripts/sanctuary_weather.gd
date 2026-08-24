extends Node

# Offline-first sanctuary climate simulation. This is intentionally a simulated
# sanctuary weather system, not live meteorological data. It persists across
# restarts and drives HUD, atmosphere, wind feel and lightweight rain VFX.

const SAVE_PATH := "user://hippo_sanctuary_weather.json"
const CONDITIONS := ["clear", "partly_cloudy", "overcast", "drizzle", "rain", "breezy"]
const MIN_DURATION := 18 * 60
const MAX_DURATION := 42 * 60

var scene_root: Node3D
var hud: Node
var grasslands: Node
var world_environment: WorldEnvironment
var rain: GPUParticles3D
var state: Dictionary = {}
var update_timer := 0.0
var bound := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 345
    _load_state()
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        var hud_candidate := get_node_or_null("/root/SanctuaryHUD")
        var grass_candidate := get_node_or_null("/root/GrasslandsSanctuary")
        if candidate is Node3D and hud_candidate != null and grass_candidate != null:
            scene_root = candidate as Node3D
            hud = hud_candidate
            grasslands = grass_candidate
            break
        await get_tree().process_frame

    if scene_root == null:
        push_warning("SanctuaryWeather could not bind to the sanctuary")
        return

    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    _build_rain_vfx()
    _refresh_weather_if_needed(true)
    bound = true
    set_process(true)

func _process(delta: float) -> void:
    if not bound:
        return
    update_timer -= delta
    if update_timer > 0.0:
        return
    update_timer = 0.75
    _refresh_weather_if_needed(false)
    _apply_weather()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_state()

func _load_state() -> void:
    state = {
        "version": 1,
        "condition": "clear",
        "next_change_unix": 0,
        "temperature_offset": 0.0,
        "wind_kmh": 7.0
    }
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var loaded := parsed as Dictionary
    var condition := str(loaded.get("condition", "clear"))
    if condition in CONDITIONS:
        state["condition"] = condition
    state["next_change_unix"] = int(loaded.get("next_change_unix", 0))
    state["temperature_offset"] = clampf(float(loaded.get("temperature_offset", 0.0)), -3.0, 3.0)
    state["wind_kmh"] = clampf(float(loaded.get("wind_kmh", 7.0)), 2.0, 28.0)

func _save_state() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(state, "  "))

func _refresh_weather_if_needed(force_apply: bool) -> void:
    var now := int(Time.get_unix_time_from_system())
    if now >= int(state.get("next_change_unix", 0)):
        _advance_weather(now)
    elif force_apply:
        _apply_weather()

func _advance_weather(now: int) -> void:
    var previous := str(state.get("condition", "clear"))
    var slot := int(floor(float(now) / 900.0))
    var rng := RandomNumberGenerator.new()
    rng.seed = int(slot * 7919 + 608241)

    var roll := rng.randf()
    var next := "clear"
    match previous:
        "clear":
            next = "clear" if roll < 0.42 else ("partly_cloudy" if roll < 0.72 else ("breezy" if roll < 0.88 else "overcast"))
        "partly_cloudy":
            next = "clear" if roll < 0.28 else ("partly_cloudy" if roll < 0.58 else ("overcast" if roll < 0.84 else "drizzle"))
        "overcast":
            next = "partly_cloudy" if roll < 0.28 else ("overcast" if roll < 0.54 else ("drizzle" if roll < 0.82 else "rain"))
        "drizzle":
            next = "overcast" if roll < 0.34 else ("drizzle" if roll < 0.62 else ("rain" if roll < 0.75 else "partly_cloudy"))
        "rain":
            next = "drizzle" if roll < 0.48 else ("overcast" if roll < 0.76 else "partly_cloudy")
        "breezy":
            next = "clear" if roll < 0.44 else ("partly_cloudy" if roll < 0.78 else "overcast")

    state["condition"] = next
    state["temperature_offset"] = rng.randf_range(-1.8, 1.8)
    var wind_base := 7.0
    if next == "breezy":
        wind_base = 19.0
    elif next in ["drizzle", "rain"]:
        wind_base = 13.0
    elif next == "overcast":
        wind_base = 10.0
    state["wind_kmh"] = clampf(wind_base + rng.randf_range(-2.5, 3.5), 2.0, 28.0)
    state["next_change_unix"] = now + rng.randi_range(MIN_DURATION, MAX_DURATION)
    _save_state()

func _apply_weather() -> void:
    if scene_root == null:
        return
    var condition := str(state.get("condition", "clear"))
    var hour := _clock_hour()
    var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) == TYPE_DICTIONARY:
        var mode := str((settings_variant as Dictionary).get("day_night_mode", "auto"))
        if mode == "day":
            daylight = 1.0
        elif mode == "night":
            daylight = 0.0

    var cloud := 0.0
    var rain_strength := 0.0
    match condition:
        "partly_cloudy": cloud = 0.26
        "overcast": cloud = 0.58
        "drizzle":
            cloud = 0.72
            rain_strength = 0.42
        "rain":
            cloud = 0.84
            rain_strength = 0.82
        "breezy": cloud = 0.10

    var sky_material_variant: Variant = grasslands.get("sky_material") if grasslands != null else null
    if sky_material_variant is ProceduralSkyMaterial:
        var sky_material := sky_material_variant as ProceduralSkyMaterial
        var day_top := Color(0.10, 0.35, 0.70).lerp(Color(0.24, 0.31, 0.34), cloud)
        var night_top := Color(0.018, 0.035, 0.095).lerp(Color(0.035, 0.045, 0.055), cloud)
        var day_horizon := Color(0.83, 0.79, 0.62).lerp(Color(0.52, 0.57, 0.56), cloud)
        var night_horizon := Color(0.12, 0.13, 0.19).lerp(Color(0.09, 0.10, 0.12), cloud)
        sky_material.sky_top_color = night_top.lerp(day_top, daylight)
        sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight)
        sky_material.ground_horizon_color = Color(0.055, 0.070, 0.060).lerp(Color(0.37, 0.43, 0.28), daylight).lerp(Color(0.18, 0.20, 0.17), cloud * 0.72)

    var sun_variant: Variant = grasslands.get("sun_light") if grasslands != null else null
    if sun_variant is DirectionalLight3D:
        var sun := sun_variant as DirectionalLight3D
        var base_energy := lerpf(0.20, 1.55, daylight)
        sun.light_energy = base_energy * lerpf(1.0, 0.52, cloud)
        sun.light_color = Color(0.32, 0.42, 0.76).lerp(Color(1.0, 0.82, 0.58), daylight).lerp(Color(0.72, 0.78, 0.80), cloud * 0.62)

    if world_environment == null or not is_instance_valid(world_environment):
        world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment != null and world_environment.environment != null:
        var environment := world_environment.environment
        environment.fog_density = 0.012 + cloud * 0.015 + rain_strength * 0.007
        environment.fog_light_energy = 0.44 + cloud * 0.12
        environment.fog_sky_affect = 0.38 + cloud * 0.30
        environment.ambient_light_energy = lerpf(0.62, 0.49, cloud)
        environment.fog_light_color = Color(0.68, 0.74, 0.66).lerp(Color(0.56, 0.63, 0.64), cloud)

    if rain != null:
        rain.emitting = rain_strength > 0.05
        rain.amount = int(lerpf(100.0, 420.0, rain_strength))
        var reduced := false
        if typeof(settings_variant) == TYPE_DICTIONARY:
            reduced = bool((settings_variant as Dictionary).get("reduced_motion", false))
        if reduced:
            rain.amount = maxi(60, int(float(rain.amount) * 0.45))

    _update_hud(condition)

func _update_hud(condition: String) -> void:
    if hud == null:
        hud = get_node_or_null("/root/SanctuaryHUD")
    if hud == null:
        return
    var label_variant: Variant = hud.get("weather_label")
    if not (label_variant is Label):
        return
    var label := label_variant as Label
    var title := {
        "clear": "CLEAR",
        "partly_cloudy": "PARTLY CLOUDY",
        "overcast": "OVERCAST",
        "drizzle": "DRIZZLE",
        "rain": "LIGHT RAIN",
        "breezy": "WARM BREEZE"
    }.get(condition, "CLEAR")
    label.text = "%s  •  %d°C  •  %d km/h" % [str(title), int(round(_temperature_c())), int(round(float(state.get("wind_kmh", 7.0))))]
    label.tooltip_text = "Simulated offline sanctuary weather"

func _temperature_c() -> float:
    var hour := _clock_hour()
    var daily := sin((hour - 8.0) / 24.0 * TAU)
    var temp := 23.0 + daily * 4.6 + float(state.get("temperature_offset", 0.0))
    var condition := str(state.get("condition", "clear"))
    if condition == "overcast":
        temp -= 0.8
    elif condition in ["drizzle", "rain"]:
        temp -= 1.8
    return clampf(temp, 14.0, 32.0)

func _clock_hour() -> float:
    var time := Time.get_time_dict_from_system()
    return float(time.get("hour", 12)) + float(time.get("minute", 0)) / 60.0

func _build_rain_vfx() -> void:
    var old := scene_root.find_child("SanctuaryRain", true, false)
    if is_instance_valid(old):
        old.queue_free()

    rain = GPUParticles3D.new()
    rain.name = "SanctuaryRain"
    rain.amount = 220
    rain.lifetime = 1.45
    rain.randomness = 0.35
    rain.visibility_aabb = AABB(Vector3(-10.0, -1.0, -8.0), Vector3(20.0, 13.0, 16.0))
    rain.position = Vector3(0.0, 7.5, 0.0)
    rain.emitting = false

    var particles := ParticleProcessMaterial.new()
    particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    particles.emission_box_extents = Vector3(8.5, 0.35, 6.4)
    particles.direction = Vector3(0.12, -1.0, 0.04)
    particles.spread = 5.0
    particles.initial_velocity_min = 7.0
    particles.initial_velocity_max = 10.0
    particles.gravity = Vector3(0.0, -5.0, 0.0)
    rain.process_material = particles

    var drop_mesh := QuadMesh.new()
    drop_mesh.size = Vector2(0.018, 0.34)
    var drop_material := StandardMaterial3D.new()
    drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    drop_material.albedo_color = Color(0.68, 0.80, 0.92, 0.54)
    drop_material.vertex_color_use_as_albedo = true
    drop_mesh.material = drop_material
    rain.draw_pass_1 = drop_mesh
    scene_root.add_child(rain)

func get_weather_snapshot() -> Dictionary:
    return {
        "condition": str(state.get("condition", "clear")),
        "temperature_c": _temperature_c(),
        "wind_kmh": float(state.get("wind_kmh", 7.0)),
        "next_change_unix": int(state.get("next_change_unix", 0)),
        "simulated_offline": true
    }
