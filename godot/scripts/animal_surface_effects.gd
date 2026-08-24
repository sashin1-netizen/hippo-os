extends Node

const MAX_TRACKS := 72
const TRACK_LIFETIME := 48.0

var host
var environment_builder
var entries := {}
var tracks := []

func _ready():
    process_priority = 45
    for i in range(9):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    environment_builder = host.get_node_or_null("OpenWorldEnvironment")
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        entries[str(animal_id)] = {
            "actor": actor,
            "wet": 0.0,
            "mud": 0.0,
            "last_action": "",
            "last_track": Vector3(actor.global_position.x, actor.global_position.y, actor.global_position.z)
        }

func _process(delta):
    if host == null:
        return
    for animal_id in entries.keys():
        _update_animal(str(animal_id), entries[animal_id], delta)
    _update_tracks(delta)

func _update_animal(animal_id: String, entry: Dictionary, delta: float):
    var actor = entry.get("actor", null)
    if actor == null or not is_instance_valid(actor):
        return
    var action = str(actor.get("current_action"))
    var species = str(actor.get("species_id"))
    var wet = float(entry.get("wet", 0.0))
    var mud = float(entry.get("mud", 0.0))

    if action == "enter_water" and species == "pygmy_hippo":
        wet = 1.0
    elif action == "wallow":
        wet = max(wet, 0.82)
        mud = 1.0
    elif action == "root" and species == "pig":
        mud = max(mud, 0.62)
        wet = max(wet, 0.24)

    wet = max(0.0, wet - delta * 0.010)
    mud = max(0.0, mud - delta * 0.0045)
    entry["wet"] = wet
    entry["mud"] = mud

    var last_action = str(entry.get("last_action", ""))
    if action != last_action:
        if action == "enter_water":
            _spawn_splash(actor.global_position, 1.0)
        elif action == "wallow":
            _spawn_splash(actor.global_position, 0.52)
        entry["last_action"] = action

    _apply_surface_state(actor, species, wet, mud)
    _maybe_track(actor, entry, mud)

func _apply_surface_state(actor, species: String, wet: float, mud: float):
    var model = actor.get("production_model")
    if model == null:
        return
    var base_moisture = 0.10
    if species == "pygmy_hippo":
        base_moisture = 0.46
    elif species == "pig":
        base_moisture = 0.25
    _set_model_surface_state(model, clamp(base_moisture + wet * 0.38, 0.0, 0.92), mud)

func _set_model_surface_state(node, moisture: float, mud: float):
    if node is MeshInstance3D:
        for surface_index in range(node.get_surface_override_material_count()):
            var material = node.get_active_material(surface_index)
            if material is ShaderMaterial:
                material.set_shader_parameter("moisture", moisture)
                material.set_shader_parameter("mud_amount", mud)
    for child in node.get_children():
        _set_model_surface_state(child, moisture, mud)

func _maybe_track(actor, entry: Dictionary, mud: float):
    if mud < 0.16:
        return
    var velocity2 = Vector2(actor.velocity.x, actor.velocity.z).length()
    if velocity2 < 0.12:
        return
    var last: Vector3 = entry.get("last_track", actor.global_position)
    var current = actor.global_position
    if Vector2(current.x - last.x, current.z - last.z).length() < 0.72:
        return
    entry["last_track"] = current
    _spawn_track(current, actor.rotation.y, str(actor.get("species_id")), mud)

func _spawn_track(world_pos: Vector3, yaw: float, species: String, strength: float):
    var mark := MeshInstance3D.new()
    mark.name = "LivingTrack"
    var quad := QuadMesh.new()
    var size = Vector2(0.34, 0.46)
    if species == "pygmy_hippo":
        size = Vector2(0.52, 0.58)
    elif species == "pig":
        size = Vector2(0.36, 0.48)
    quad.size = size
    mark.mesh = quad
    var ground = _ground_height(world_pos.x, world_pos.z)
    mark.position = Vector3(world_pos.x, ground + 0.026, world_pos.z)
    mark.rotation = Vector3(-PI * 0.5, yaw, 0.0)
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.105, 0.060, 0.028, clamp(0.20 + strength * 0.34, 0.20, 0.56))
    material.roughness = 0.66
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    mark.material_override = material
    host.add_child(mark)
    tracks.append({"node": mark, "age": 0.0, "alpha": material.albedo_color.a})
    while tracks.size() > MAX_TRACKS:
        var old = tracks.pop_front()
        var old_node = old.get("node", null)
        if old_node != null and is_instance_valid(old_node):
            old_node.queue_free()

func _update_tracks(delta: float):
    for i in range(tracks.size() - 1, -1, -1):
        var item = tracks[i]
        var node = item.get("node", null)
        if node == null or not is_instance_valid(node):
            tracks.remove_at(i)
            continue
        var age = float(item.get("age", 0.0)) + delta
        item["age"] = age
        if age >= TRACK_LIFETIME:
            node.queue_free()
            tracks.remove_at(i)
            continue
        var fade = 1.0 - smoothstep(TRACK_LIFETIME * 0.55, TRACK_LIFETIME, age)
        var material = node.material_override
        if material is StandardMaterial3D:
            var color = material.albedo_color
            color.a = float(item.get("alpha", 0.4)) * fade
            material.albedo_color = color

func _spawn_splash(world_pos: Vector3, strength: float):
    var particles := CPUParticles3D.new()
    particles.name = "WaterSplash"
    particles.one_shot = true
    particles.amount = int(10 + strength * 14.0)
    particles.lifetime = 0.72
    particles.explosiveness = 0.92
    particles.randomness = 0.44
    particles.direction = Vector3(0.0, 1.0, 0.0)
    particles.spread = 52.0
    particles.gravity = Vector3(0.0, -6.2, 0.0)
    particles.initial_velocity_min = 1.1 * strength
    particles.initial_velocity_max = 2.8 * strength
    particles.scale_amount_min = 0.028
    particles.scale_amount_max = 0.075
    var droplet := SphereMesh.new()
    droplet.radius = 0.035
    droplet.height = 0.07
    droplet.radial_segments = 5
    droplet.rings = 3
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.22, 0.56, 0.62, 0.72)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness = 0.12
    droplet.material = material
    particles.mesh = droplet
    particles.position = Vector3(world_pos.x, _ground_height(world_pos.x, world_pos.z) + 0.20, world_pos.z)
    host.add_child(particles)
    particles.finished.connect(particles.queue_free)
    particles.emitting = true

func _ground_height(x: float, z: float) -> float:
    if environment_builder != null and environment_builder.has_method("terrain_height"):
        return float(environment_builder.call("terrain_height", x, z))
    return 0.04
