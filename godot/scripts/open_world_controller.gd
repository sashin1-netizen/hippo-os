extends Node

const WORLD_HALF_X := 46.0
const WORLD_HALF_Z := 30.0
const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.2
const INTERACT_DISTANCE := 3.4

var host
var environment_builder
var move_input := Vector2.ZERO
var roam_position := Vector3(0.0, 1.7, 10.0)
var roam_yaw := 0.0
var roam_pitch := -0.08
var look_velocity := Vector2.ZERO
var bodycam_phase := 0.0
var initialized := false
var sprinting := false

func _ready():
    process_priority = 80
    for i in range(6):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    environment_builder = host.get_node_or_null("OpenWorldEnvironment")
    var y = _ground_height(roam_position.x, roam_position.z)
    roam_position.y = y + 1.68
    initialized = true

func set_move_input(x: float, y: float):
    move_input = Vector2(clamp(x, -1.0, 1.0), clamp(y, -1.0, 1.0))
    if move_input.length() > 1.0:
        move_input = move_input.normalized()

func add_look_delta(dx: float, dy: float):
    look_velocity += Vector2(clamp(dx, -40.0, 40.0), clamp(dy, -40.0, 40.0))

func set_sprinting(value: bool):
    sprinting = value

func stop_move():
    move_input = Vector2.ZERO

func is_free_roam() -> bool:
    if host == null:
        return false
    return str(host.get("camera_mode")) in ["caretaker", "bodycam"]

func can_interact() -> bool:
    return distance_to_selected() <= INTERACT_DISTANCE

func distance_to_selected() -> float:
    if host == null:
        return 999.0
    var actor = host.call("_selected_actor") if host.has_method("_selected_actor") else null
    if actor == null:
        return 999.0
    return Vector2(actor.global_position.x - roam_position.x, actor.global_position.z - roam_position.z).length()

func player_ground_position() -> Vector3:
    return Vector3(roam_position.x, _ground_height(roam_position.x, roam_position.z), roam_position.z)

func snapshot() -> Dictionary:
    return {
        "roam_x": roam_position.x,
        "roam_z": roam_position.z,
        "roam_yaw": roam_yaw,
        "can_interact": can_interact(),
        "selected_distance": distance_to_selected(),
        "world_half_x": WORLD_HALF_X,
        "world_half_z": WORLD_HALF_Z
    }

func _process(delta):
    if not initialized or host == null:
        return
    _update_owner_context()
    if not is_free_roam():
        return
    _update_look(delta)
    _update_roam_position(delta)
    _apply_camera(delta)

func _update_look(delta):
    if look_velocity.length_squared() > 0.001:
        var sensitivity = 0.0042
        var sanctuary = host.get("sanctuary")
        if sanctuary != null:
            sensitivity *= clamp(float(sanctuary.settings.get("camera_sensitivity", 1.0)), 0.4, 2.0)
        roam_yaw -= look_velocity.x * sensitivity
        roam_pitch = clamp(roam_pitch - look_velocity.y * sensitivity * 0.72, -0.72, 0.55)
    look_velocity = look_velocity.lerp(Vector2.ZERO, min(delta * 16.0, 1.0))

func _update_roam_position(delta):
    if move_input.length_squared() < 0.0005:
        return
    var forward = Vector3(-sin(roam_yaw), 0.0, -cos(roam_yaw)).normalized()
    var right = Vector3(forward.z, 0.0, -forward.x).normalized()
    var direction = (right * move_input.x + forward * -move_input.y)
    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    var speed = SPRINT_SPEED if sprinting else WALK_SPEED
    var next = roam_position + direction * speed * delta
    next.x = clamp(next.x, -WORLD_HALF_X, WORLD_HALF_X)
    next.z = clamp(next.z, -WORLD_HALF_Z, WORLD_HALF_Z)
    var ground = _ground_height(next.x, next.z)
    var eye_height = 1.52 if str(host.get("camera_mode")) == "bodycam" else 1.72
    next.y = ground + eye_height
    roam_position = roam_position.lerp(next, min(delta * 12.0, 1.0))

func _apply_camera(delta):
    var camera = host.get("camera")
    if camera == null or not camera is Camera3D:
        return
    var mode = str(host.get("camera_mode"))
    var reduced_motion = false
    var sanctuary = host.get("sanctuary")
    if sanctuary != null:
        reduced_motion = bool(sanctuary.settings.get("reduced_motion", false))

    bodycam_phase += delta * (7.0 if move_input.length() > 0.08 else 2.1)
    var sway = Vector3.ZERO
    if mode == "bodycam" and not reduced_motion:
        var movement = move_input.length()
        var amp = lerp(0.004, 0.036, movement)
        sway = Vector3(sin(bodycam_phase) * amp, abs(cos(bodycam_phase * 2.0)) * amp * 0.42, 0.0)

    var forward = Vector3(-sin(roam_yaw) * cos(roam_pitch), sin(roam_pitch), -cos(roam_yaw) * cos(roam_pitch)).normalized()
    var right = Vector3(forward.z, 0.0, -forward.x).normalized()
    var desired = roam_position + right * sway.x + Vector3.UP * sway.y
    camera.global_position = camera.global_position.lerp(desired, min(delta * (14.0 if mode == "bodycam" else 10.0), 1.0))
    camera.look_at(camera.global_position + forward * 8.0, Vector3.UP)
    var target_fov = 74.0 if mode == "bodycam" else 60.0
    camera.fov = lerp(camera.fov, target_fov, min(delta * 6.0, 1.0))

func _ground_height(x: float, z: float) -> float:
    if environment_builder != null and environment_builder.has_method("terrain_height"):
        return float(environment_builder.call("terrain_height", x, z))
    return 0.04

func _update_owner_context():
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    var ground_player = player_ground_position()
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor == null:
            continue
        var distance = Vector2(actor.global_position.x - roam_position.x, actor.global_position.z - roam_position.z).length()
        actor.set_meta("owner_distance", distance)
        var selected_id = str(host.get("selected_id"))
        var near = distance < 8.0 and str(animal_id) == selected_id
        actor.set_meta("owner_near", near)
        var action = str(actor.get("current_action"))
        if near and action in ["approach_owner", "follow_owner", "rest_near_owner"]:
            var offset = Vector3(cos(roam_yaw) * 1.25, 0.0, sin(roam_yaw) * 1.25)
            actor.move_target = Vector3(ground_player.x + offset.x, actor.global_position.y, ground_player.z + offset.z)
