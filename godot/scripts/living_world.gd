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
var _vegetation_nodes = []
var _water_nodes = []
var _mud_nodes = []

func setup(environment, sun, animals, saved_customization = {}):
    _environment = environment
    _sun = sun
    _animals = animals
    _scan_world_nodes(get_parent())
    if typeof(saved_customization) == TYPE_DICTIONARY and not saved_customization.is_empty():
        apply_customization(saved_customization)
    else:
        _apply_world_customization()
        _apply_animal_customization()

func apply_customization(payload):
    if typeof(payload) != TYPE_DICTIONARY:
        return false
    _deep_merge(customization, payload)
    _sanitize()
    _apply_world_customization()
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
    _animate_vegetation(motion)
    _animate_water(motion)
    _update_mud_dampness()

func snapshot():
    return {
        "customization": customization.duplicate(true),
        "climate": climate.duplicate(true),
        "world_age_seconds": world_age_seconds
    }

func bodycam_motion():
    return clamp(float(customization.get("camera", {}).get("bodycam_motion", 0.45)), 0.0, 1.0)

func _scan_world_nodes(node):
    if node == self:
        return
    if node is MeshInstance3D:
        var source_mesh = node.mesh
        if source_mesh is CylinderMesh:
            var top_radius = float(source_mesh.top_radius)
            if top_radius < 0.20:
                _vegetation_nodes.append(node)
            elif top_radius >= 2.0:
                _water_nodes.append(node)
            elif top_radius >= 1.3:
                _mud_nodes.append(node)
    for child in node.get_children():
        _scan_world_nodes(child)

func _apply_world_customization():
    var world = customization.get("world", {})
    var density = clamp(float(world.get("vegetation_density", 0.72)), 0.0, 1.0)
    var visible_count = int(round(float(_vegetation_nodes.size()) * density))
    for i in range(_vegetation_nodes.size()):
        var plant = _vegetation_nodes[i]
        plant.visible = i < visible_count
        if not plant.has_meta("living_base_rotation_z"):
            plant.set_meta("living_base_rotation_z", float(plant.rotation.z))

    var clarity = clamp(float(world.get("water_clarity", 0.72)), 0.0, 1.0)
    for water in _water_nodes:
        if not water.has_meta("living_base_scale"):
            water.set_meta("living_base_scale", water.scale)
        _style_water(water, clarity)

    var mud_amount = clamp(float(world.get("mud_amount", 0.55)), 0.0, 1.0)
    for mud in _mud_nodes:
        if not mud.has_meta("living_base_scale"):
            mud.set_meta("living_base_scale", mud.scale)
        var base_scale = mud.get_meta("living_base_scale")
        if base_scale is Vector3:
            var spread = lerp(0.52, 1.28, mud_amount)
            mud.scale = Vector3(base_scale.x * spread, base_scale.y, base_scale.z * spread)

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

func _animate_vegetation(motion):
    var wind = float(climate.get("wind", 0.25))
    for i in range(_vegetation_nodes.size()):
        var plant = _vegetation_nodes[i]
        if not plant.visible:
            continue
        var base_rotation = float(plant.get_meta("living_base_rotation_z", 0.0))
        var sway = sin(wind_phase + float(i) * 0.63) * 0.055 * wind * motion
        plant.rotation.z = lerp(plant.rotation.z, base_rotation + sway, 0.10)

func _animate_water(motion):
    var activity = float(climate.get("water_activity", 0.3))
    for i in range(_water_nodes.size()):
        var water = _water_nodes[i]
        var base_scale = water.get_meta("living_base_scale", water.scale)
        if base_scale is Vector3:
            var pulse = 1.0 + sin(water_phase + float(i)) * 0.006 * activity * motion
            water.scale = Vector3(base_scale.x * pulse, base_scale.y, base_scale.z * pulse)

func _style_water(water, clarity):
    if not water is MeshInstance3D:
        return
    if not water.has_meta("living_base_material"):
        var initial = water.material_override
        if initial != null:
            water.set_meta("living_base_material", initial.duplicate(true))
    var base = water.get_meta("living_base_material", null)
    if base is StandardMaterial3D:
        var material = base.duplicate(true)
        material.albedo_color = Color(
            lerp(0.035, 0.075, clarity),
            lerp(0.22, 0.42, clarity),
            lerp(0.29, 0.56, clarity),
            1.0
        )
        material.roughness = lerp(0.34, 0.08, clarity)
        material.metallic = lerp(0.02, 0.10, clarity)
        water.material_override = material

func _update_mud_dampness():
    var damp = float(climate.get("ground_dampness", 0.35))
    for mud in _mud_nodes:
        if not mud is MeshInstance3D:
            continue
        if not mud.has_meta("living_base_material"):
            var initial = mud.material_override
            if initial != null:
                mud.set_meta("living_base_material", initial.duplicate(true))
        var base = mud.get_meta("living_base_material", null)
        if base is StandardMaterial3D:
            var material = base.duplicate(true)
            material.albedo_color = Color(
                lerp(0.30, 0.18, damp),
                lerp(0.20, 0.11, damp),
                lerp(0.11, 0.06, damp),
                1.0
            )
            material.roughness = lerp(1.0, 0.58, damp)
            mud.material_override = material

func _apply_animal_customization():
    var all_animals = customization.get("animals", {})
    if typeof(all_animals) != TYPE_DICTIONARY:
        return
    for animal_id in all_animals.keys():
        var actor = _animals.get(str(animal_id), null)
        var data = all_animals[animal_id]
        if actor != null and typeof(data) == TYPE_DICTIONARY:
            _apply_actor_customization(actor, data)

func _apply_actor_customization(actor, data):
    var model = actor.get("production_model")
    if model is Node3D:
        if not model.has_meta("living_base_scale"):
            model.set_meta("living_base_scale", float(model.scale.x))
        var base_scale = float(model.get_meta("living_base_scale"))
        var requested_scale = clamp(float(data.get("body_scale", 1.0)), 0.88, 1.12)
        model.scale = Vector3.ONE * base_scale * requested_scale
        _style_animal_meshes(model, data)

    var state = actor.get("state")
    if state == null:
        return
    var temperament = state.temperament
    if typeof(temperament) != TYPE_DICTIONARY:
        return

    if not actor.has_meta("living_base_temperament"):
        actor.set_meta("living_base_temperament", temperament.duplicate(true))
    var base_temperament = actor.get_meta("living_base_temperament")
    if typeof(base_temperament) != TYPE_DICTIONARY:
        return

    var curiosity_bias = clamp(float(data.get("curiosity_bias", 0.5)), 0.0, 1.0)
    var social_bias = clamp(float(data.get("social_bias", 0.5)), 0.0, 1.0)
    var energy_bias = clamp(float(data.get("energy_bias", 0.5)), 0.0, 1.0)

    if base_temperament.has("curiosity"):
        temperament["curiosity"] = clamp(float(base_temperament["curiosity"]) + (curiosity_bias - 0.5) * 0.35, 0.05, 0.98)
    if base_temperament.has("social_tolerance"):
        temperament["social_tolerance"] = clamp(float(base_temperament["social_tolerance"]) + (social_bias - 0.5) * 0.35, 0.05, 0.98)
    if base_temperament.has("playfulness"):
        temperament["playfulness"] = clamp(float(base_temperament["playfulness"]) + (energy_bias - 0.5) * 0.32, 0.05, 0.98)
    state.temperament = temperament

func _style_animal_meshes(node, data):
    if node is MeshInstance3D:
        var warmth = clamp(float(data.get("skin_warmth", 0.5)), 0.0, 1.0)
        var pattern = clamp(float(data.get("pattern_strength", 0.25)), 0.0, 1.0)
        var eye_presence = clamp(float(data.get("eye_brightness", 0.5)), 0.0, 1.0)
        for surface_index in range(node.get_surface_override_material_count()):
            var active = node.get_active_material(surface_index)
            if active == null:
                continue
            var key = "living_base_surface_%d" % surface_index
            if not node.has_meta(key):
                node.set_meta(key, active.duplicate(true))
            var base = node.get_meta(key)
            if base is StandardMaterial3D:
                var material = base.duplicate(true)
                var base_color = base.albedo_color
                var warm_tint = Color(lerp(0.90, 1.10, warmth), lerp(0.94, 1.02, warmth), lerp(1.04, 0.86, warmth), 1.0)
                var variation = 1.0 + sin(float(surface_index + 1) * 2.17) * 0.10 * pattern
                material.albedo_color = Color(
                    clamp(base_color.r * warm_tint.r * variation, 0.0, 1.0),
                    clamp(base_color.g * warm_tint.g * variation, 0.0, 1.0),
                    clamp(base_color.b * warm_tint.b * variation, 0.0, 1.0),
                    base_color.a
                )
                if "eye" in str(node.name).to_lower():
                    material.emission_enabled = true
                    material.emission = material.albedo_color.lightened(0.22)
                    material.emission_energy_multiplier = lerp(0.0, 0.45, eye_presence)
                node.set_surface_override_material(surface_index, material)
    for child in node.get_children():
        _style_animal_meshes(child, data)

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
