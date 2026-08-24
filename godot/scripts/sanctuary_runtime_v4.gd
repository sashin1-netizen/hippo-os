extends "res://scripts/sanctuary_v3.gd"

const LivingWorld = preload("res://scripts/living_world.gd")
const CAMERA_MODES = ["cinematic", "caretaker", "bodycam", "overhead"]
const FLUTTER_BRIDGE_NAME = "HippoFlutterBridge"

var camera_mode = "cinematic"
var bodycam_phase = 0.0
var device_timezone = "Local"
var device_local_hour = -1
var device_local_minute = 0
var device_utc_offset_minutes = 0
var last_device_clock_sync_ms = 0
var flutter_bridge = null
var flutter_status_timer = null
var living_world = null

func set_camera_mode(value):
    var requested = str(value).to_lower()
    if requested not in CAMERA_MODES:
        return false
    camera_mode = requested
    sanctuary.settings["camera_mode"] = camera_mode
    _reset_camera()
    _save_sanctuary()
    _push_flutter_status()
    return true

func sync_device_time(payload):
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    device_timezone = str(payload.get("iana_zone", device_timezone))
    device_local_hour = clamp(int(payload.get("local_hour", device_local_hour)), 0, 23)
    device_local_minute = clamp(int(payload.get("local_minute", device_local_minute)), 0, 59)
    device_utc_offset_minutes = int(payload.get("utc_offset_minutes", device_utc_offset_minutes))
    last_device_clock_sync_ms = int(payload.get("epoch_milliseconds", Time.get_unix_time_from_system() * 1000.0))
    sanctuary.settings["device_timezone"] = device_timezone
    sanctuary.settings["device_utc_offset_minutes"] = device_utc_offset_minutes
    sanctuary.settings["time_mode"] = "automatic"
    _push_flutter_status()
    return true

func apply_customization(payload):
    if living_world == null or typeof(payload) != TYPE_DICTIONARY:
        return false

    var settings_payload = payload.get("settings", {})
    if typeof(settings_payload) == TYPE_DICTIONARY:
        _apply_custom_settings(settings_payload)

    var living_payload = payload.duplicate(true)
    living_payload.erase("settings")
    if not living_world.apply_customization(living_payload):
        return false

    sanctuary.set_customization(living_world.customization)
    sanctuary.add_journal_event("customization", "sanctuary", "The sanctuary evolved with your latest customisation.", 0.25)
    _save_sanctuary()
    _push_flutter_status()
    return true

func _apply_custom_settings(settings_payload):
    sanctuary.settings["master_volume"] = clamp(float(settings_payload.get("master_volume", sanctuary.settings.get("master_volume", 1.0))), 0.0, 1.0)
    sanctuary.settings["animal_volume"] = clamp(float(settings_payload.get("animal_volume", sanctuary.settings.get("animal_volume", 1.0))), 0.0, 1.0)
    sanctuary.settings["ambience_volume"] = clamp(float(settings_payload.get("ambience_volume", sanctuary.settings.get("ambience_volume", 0.85))), 0.0, 1.0)
    sanctuary.settings["ui_volume"] = clamp(float(settings_payload.get("ui_volume", sanctuary.settings.get("ui_volume", 0.85))), 0.0, 1.0)
    sanctuary.settings["haptics"] = bool(settings_payload.get("haptics", sanctuary.settings.get("haptics", true)))
    sanctuary.settings["show_stats"] = bool(settings_payload.get("show_stats", sanctuary.settings.get("show_stats", true)))
    sanctuary.settings["reduced_motion"] = bool(settings_payload.get("reduced_motion", sanctuary.settings.get("reduced_motion", false)))
    sanctuary.settings["camera_sensitivity"] = clamp(float(settings_payload.get("camera_sensitivity", sanctuary.settings.get("camera_sensitivity", 1.0))), 0.40, 2.0)
    sanctuary.settings["text_scale"] = clamp(float(settings_payload.get("text_scale", sanctuary.settings.get("text_scale", 1.0))), 0.85, 1.35)
    _apply_settings()
    if animal_stats_label != null:
        animal_stats_label.visible = bool(sanctuary.settings.get("show_stats", true))

func flutter_action(action_name):
    match str(action_name):
        "feed":
            _feed_selected()
        "pet":
            _pet_selected()
        "journal":
            _toggle_journal()
        "settings":
            _toggle_settings()
        _:
            return false
    _push_flutter_status()
    return true

func get_flutter_status():
    var actor = _selected_actor()
    if actor == null or actor.state == null:
        return {}
    var needs = actor.state.needs
    var payload = {
        "animal_name": actor.display_name(),
        "species_name": actor.species_display_name(),
        "status": actor.status_line(),
        "camera_mode": camera_mode,
        "iana_zone": device_timezone,
        "bond": float(actor.state.bond),
        "hunger": float(needs.get("hunger", 0.0)),
        "energy": float(needs.get("energy", 0.0)),
        "security": float(actor.state.emotion.get("security", 0.0))
    }
    if living_world != null:
        var climate = living_world.climate
        payload["wind"] = float(climate.get("wind", 0.0))
        payload["humidity"] = float(climate.get("humidity", 0.0))
        payload["cloudiness"] = float(climate.get("cloudiness", 0.0))
        payload["ground_dampness"] = float(climate.get("ground_dampness", 0.0))
        payload["water_activity"] = float(climate.get("water_activity", 0.0))
        payload["world_age_seconds"] = float(living_world.world_age_seconds)
        var full_customization = living_world.customization.duplicate(true)
        full_customization["settings"] = sanctuary.settings.duplicate(true)
        payload["customization_json"] = JSON.stringify(full_customization)
    return payload

func _ready():
    super()
    camera_mode = str(sanctuary.settings.get("camera_mode", "cinematic"))
    if camera_mode not in CAMERA_MODES:
        camera_mode = "cinematic"
    device_timezone = str(sanctuary.settings.get("device_timezone", "Local"))
    living_world = LivingWorld.new()
    living_world.name = "LivingWorld"
    add_child(living_world)
    living_world.setup(environment, sun, animals, sanctuary.customization_snapshot())
    _setup_flutter_bridge()

func _process(delta):
    super(delta)
    if living_world != null:
        living_world.tick(delta, _effective_local_hour())

func _setup_flutter_bridge():
    if not Engine.has_singleton(FLUTTER_BRIDGE_NAME):
        return
    flutter_bridge = Engine.get_singleton(FLUTTER_BRIDGE_NAME)
    if flutter_bridge.has_signal("camera_mode_requested"):
        flutter_bridge.camera_mode_requested.connect(set_camera_mode)
    if flutter_bridge.has_signal("device_time_synced"):
        flutter_bridge.device_time_synced.connect(_on_flutter_time_json)
    if flutter_bridge.has_signal("animal_action_requested"):
        flutter_bridge.animal_action_requested.connect(flutter_action)
    if flutter_bridge.has_signal("customization_requested"):
        flutter_bridge.customization_requested.connect(_on_flutter_customization_json)

    flutter_status_timer = Timer.new()
    flutter_status_timer.wait_time = 0.5
    flutter_status_timer.one_shot = false
    flutter_status_timer.autostart = true
    flutter_status_timer.timeout.connect(_push_flutter_status)
    add_child(flutter_status_timer)
    call_deferred("_push_flutter_status")

func _on_flutter_time_json(payload_json):
    var payload = JSON.parse_string(str(payload_json))
    if typeof(payload) == TYPE_DICTIONARY:
        sync_device_time(payload)

func _on_flutter_customization_json(payload_json):
    var payload = JSON.parse_string(str(payload_json))
    if typeof(payload) == TYPE_DICTIONARY:
        apply_customization(payload)

func _push_flutter_status():
    if flutter_bridge == null:
        return
    var payload = get_flutter_status()
    if payload.is_empty():
        return
    flutter_bridge.pushStatus(JSON.stringify(payload))

func _update_camera(delta):
    var actor = _selected_actor()
    if actor == null or camera == null:
        return

    var pivot = actor.global_position + Vector3(0.0, 0.76, 0.0)
    var reduced_motion = bool(sanctuary.settings.get("reduced_motion", false))
    var smoothing = 3.0 if reduced_motion else 6.0
    var desired = camera.global_position
    var target = pivot

    if camera_mode == "bodycam":
        bodycam_phase += delta * 5.2
        var forward = Vector3(sin(orbit_yaw), 0.0, cos(orbit_yaw)).normalized()
        var side = Vector3(forward.z, 0.0, -forward.x)
        var base_position = pivot - forward * 2.55 + Vector3(0.0, 0.88, 0.0)
        var bodycam_motion = living_world.bodycam_motion() if living_world != null else 0.45
        var sway = 0.0 if reduced_motion else lerp(0.0, 0.032, bodycam_motion)
        desired = base_position + side * sin(bodycam_phase) * sway + Vector3(0.0, cos(bodycam_phase * 2.0) * sway * 0.55, 0.0)
        target = pivot + Vector3(0.0, 0.18 + sin(orbit_pitch) * 0.35, 0.0)
        camera.fov = lerp(camera.fov, 74.0, min(delta * 5.0, 1.0))
        smoothing = 8.5 if not reduced_motion else 4.0
    elif camera_mode == "caretaker":
        var horizontal = cos(orbit_pitch) * 4.6
        desired = pivot + Vector3(sin(orbit_yaw) * horizontal, -sin(orbit_pitch) * 4.6 + 1.35, cos(orbit_yaw) * horizontal)
        camera.fov = lerp(camera.fov, 58.0, min(delta * 4.0, 1.0))
    elif camera_mode == "overhead":
        desired = pivot + Vector3(0.2, 9.2, 0.8)
        target = pivot
        camera.fov = lerp(camera.fov, 50.0, min(delta * 4.0, 1.0))
        smoothing = 4.0
    else:
        var horizontal = cos(orbit_pitch) * orbit_distance
        desired = pivot + Vector3(sin(orbit_yaw) * horizontal, -sin(orbit_pitch) * orbit_distance + 1.2, cos(orbit_yaw) * horizontal)
        camera.fov = lerp(camera.fov, 48.0, min(delta * 4.0, 1.0))
        smoothing = 2.2 if reduced_motion else 4.2

    camera.global_position = camera.global_position.lerp(desired, min(delta * smoothing, 1.0))
    camera.look_at(target, Vector3.UP)

func _effective_local_hour():
    if device_local_hour >= 0:
        return device_local_hour
    return int(Time.get_time_dict_from_system().get("hour", 12))

func _update_day_night():
    if environment == null or sun == null:
        return
    if str(sanctuary.settings.get("time_mode", "automatic")) != "automatic":
        return

    var hour = _effective_local_hour()
    if hour >= 19 or hour < 6:
        environment.background_color = environment.background_color.lerp(Color(0.008, 0.016, 0.032), 0.02)
        environment.ambient_light_color = environment.ambient_light_color.lerp(Color(0.20, 0.27, 0.40), 0.02)
        sun.light_energy = lerp(sun.light_energy, 0.18, 0.02)
        sun.light_color = sun.light_color.lerp(Color(0.48, 0.56, 0.78), 0.02)
    elif hour >= 17:
        environment.background_color = environment.background_color.lerp(Color(0.16, 0.11, 0.08), 0.02)
        environment.ambient_light_color = environment.ambient_light_color.lerp(Color(0.66, 0.47, 0.33), 0.02)
        sun.light_energy = lerp(sun.light_energy, 0.72, 0.02)
        sun.light_color = sun.light_color.lerp(Color(1.0, 0.58, 0.30), 0.02)
    else:
        environment.background_color = environment.background_color.lerp(Color(0.025, 0.055, 0.045), 0.02)
        environment.ambient_light_color = environment.ambient_light_color.lerp(Color(0.46, 0.58, 0.50), 0.02)
        sun.light_energy = lerp(sun.light_energy, 1.40, 0.02)
        sun.light_color = sun.light_color.lerp(Color(1.0, 0.90, 0.76), 0.02)
