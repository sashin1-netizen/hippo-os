extends Node

var customization = {
    "interface": {
        "accent_hue": 0.39,
        "glass": 0.82,
        "scale": 1.0
    },
    "world": {
        "vegetation_density": 0.72,
        "water_clarity": 0.72,
        "mud_amount": 0.55,
        "light_warmth": 0.58,
        "weather_life": 0.65,
        "wind_life": 0.55,
        "world_motion": 0.62,
        "auto_living_world": true
    },
    "camera": {
        "bodycam_motion": 0.45
    },
    "animals": {}
}

var climate = {
    "wind": 0.25,
    "humidity": 0.58,
    "cloudiness": 0.22,
    "ground_dampness": 0.35,
    "water_activity": 0.30,
    "wildlife_activity": 0.45
}

var world_age_seconds = 0.0
var weather_phase = 0.0
var wind_phase = 0.0
var water_phase = 0.0
var _environment
var _sun
var _animals = {}

func setup(environment, sun, animals, saved_customization = {}):
    _environment = environment
    _sun = sun
    _animals = animals
    if typeof(saved_customization) == TYPE_DICTIONARY and not saved_customization.is_empty():
        apply_customization(saved_customization)
    else:
        _apply_animal_customization()

func apply_customization(payload):
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    _deep_merge(customization, payload)
    _sanitize()
    _apply_animal_customization()
    return true

func tick(delta, local_hour):
    var dt = max(float(delta), 0.0)
    world_age_seconds += dt
    var world = customization.get("world", {})
    var motion = clamp(float(world.get("world_motion", 0.62)), 0.0, 1.0)
    var weather_life = clamp(float(world.get("weather_life", 0.65)), 0.0, 1.0)
    var wind_life = clamp(float(world.get("wind_life", 0.55)), 0.0, 1.0)
    var auto_living = bool(world.get("auto_living_world", true))

    wind_phase += dt * lerp(0.05, 0.22, wind_life)
    water_phase += dt * lerp(0.08, 0.28, motion)
    if auto_living:
        weather_phase += dt * lerp(0.006, 0.035, weather_life)

    var day_factor = _day_factor(int(local_hour))
    var evolving_cloud = 0.22
    var evolving_humidity = 0.58
    if auto_living:
        evolving_cloud = clamp(0.34 + sin(weather_phase) * 0.22 + sin(weather_phase * 0.37 + 1.8) * 0.12, 0.04, 0.86)
        evolving_humidity = clamp(0.55 + cos(weather_phase * 0.71) * 0.18, 0.25, 0.92)

    climate["wind"] = clamp(0.20 + abs(sin(wind_phase)) * 0.55 * wind_life, 0.0, 1.0)
    climate["humidity"] = evolving_humidity
    climate["cloudiness"] = evolving_cloud
    climate["ground_dampness"] = clamp(0.20 + evolving_humidity * 0.55 + float(customization["world"].get("mud_amount", 0.55)) * 0.20, 0.0, 1.0)
    climate["water_activity"] = clamp(0.18 + abs(sin(water_phase)) * 0.42 * motion + float(climate["wind"]) * 0.20, 0.0, 1.0)
    climate["wildlife_activity"] = clamp(0.22 + day_factor * 0.48 + (1.0 - evolving_cloud) * 0.12, 0.0, 1.0)

    _apply_lighting(day_factor)

func snapshot():
    return {
        "customization": customization.duplicate(true),
        "climate": climate.duplicate(true),
        "world_age_seconds": world_age_seconds
    }

func bodycam_motion():
    return clamp(float(customization.get("camera", {}).get("bodycam_motion", 0.45)), 0.0, 1.0)

func _apply_lighting(day_factor):
    if _environment == null or _sun == null:
        return
    var world = customization.get("world", {})
    var warmth = clamp(float(world.get("light_warmth", 0.58)), 0.0, 1.0)
    var cloudiness = float(climate.get("cloudiness", 0.22))
    var cloud_dim = lerp(1.0, 0.72, cloudiness)
    var warm_color = Color(1.0, lerp(0.80, 0.94, warmth), lerp(0.66, 0.86, warmth))
    var target_energy = lerp(0.22, 1.45, day_factor) * cloud_dim
    _sun.light_energy = lerp(_sun.light_energy, target_energy, 0.012)
    _sun.light_color = _sun.light_color.lerp(warm_color, 0.008)
    var ambient_target = lerp(0.48, 0.88, day_factor) * lerp(1.0, 0.82, cloudiness)
    _environment.ambient_light_energy = lerp(_environment.ambient_light_energy, ambient_target, 0.01)

func _apply_animal_customization():
    var all_animals = customization.get("animals", {})
    if typeof(all_animals) != TYPE_DICTIONARY:
        return
    for animal_id in all_animals.keys():
        var actor = _animals.get(str(animal_id), null)
        if actor != null and actor.has_method("apply_customization"):
            actor.apply_customization(all_animals[animal_id])

func _sanitize():
    var world = customization.get("world", {})
    for key in ["vegetation_density", "water_clarity", "mud_amount", "light_warmth", "weather_life", "wind_life", "world_motion"]:
        world[key] = clamp(float(world.get(key, 0.5)), 0.0, 1.0)
    world["auto_living_world"] = bool(world.get("auto_living_world", true))
    customization["world"] = world

    var camera = customization.get("camera", {})
    camera["bodycam_motion"] = clamp(float(camera.get("bodycam_motion", 0.45)), 0.0, 1.0)
    customization["camera"] = camera

    var ui = customization.get("interface", {})
    ui["accent_hue"] = clamp(float(ui.get("accent_hue", 0.39)), 0.0, 1.0)
    ui["glass"] = clamp(float(ui.get("glass", 0.82)), 0.25, 1.0)
    ui["scale"] = clamp(float(ui.get("scale", 1.0)), 0.85, 1.25)
    customization["interface"] = ui

func _day_factor(hour):
    if hour >= 7 and hour < 17:
        return 1.0
    if hour >= 17 and hour < 19:
        return 0.65
    if hour >= 5 and hour < 7:
        return 0.55
    return 0.12

func _deep_merge(target, incoming):
    for key in incoming.keys():
        var value = incoming[key]
        if typeof(value) == TYPE_DICTIONARY and typeof(target.get(key, null)) == TYPE_DICTIONARY:
            var nested = target[key]
            _deep_merge(nested, value)
            target[key] = nested
        else:
            target[key] = value
