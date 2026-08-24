extends "res://scripts/sanctuary_v3.gd"

const CAMERA_MODES = ["cinematic", "caretaker", "bodycam", "overhead"]

var camera_mode = "cinematic"
var bodycam_phase = 0.0
var device_timezone = "Local"
var device_local_hour = -1
var device_local_minute = 0
var device_utc_offset_minutes = 0
var last_device_clock_sync_ms = 0

func set_camera_mode(value):
    var requested = str(value).to_lower()
    if requested not in CAMERA_MODES:
        return false
    camera_mode = requested
    sanctuary.settings["camera_mode"] = camera_mode
    _reset_camera()
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
    return true

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
    return true

func get_flutter_status():
    var actor = _selected_actor()
    if actor == null:
        return {}
    return {
        "animal_name": actor.display_name(),
        "species_name": actor.species_display_name(),
        "status": actor.status_line(),
        "camera_mode": camera_mode,
        "iana_zone": device_timezone
    }

func _ready():
    super()
    camera_mode = str(sanctuary.settings.get("camera_mode", "cinematic"))
    if camera_mode not in CAMERA_MODES:
        camera_mode = "cinematic"
    device_timezone = str(sanctuary.settings.get("device_timezone", "Local"))

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
        var sway = 0.0 if reduced_motion else 0.018
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
