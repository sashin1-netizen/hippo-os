extends CharacterBody3D

const SpeciesProfiles = preload("res://scripts/species_profiles.gd")
const AnimalState = preload("res://scripts/animal_state.gd")
const AnimalBrain = preload("res://scripts/animal_brain.gd")

var animal_id = ""
var species_id = ""
var profile = {}
var state
var brain
var home_center = Vector3.ZERO
var zone_radius = Vector2(4.0, 3.0)
var current_action = "idle"
var action_timer = 0.0
var move_target = Vector3.ZERO
var visual_root
var head_part
var ear_left
var ear_right
var body_part
var selected = false
var bob_phase = 0.0

func setup(new_id, new_species_id, new_name, new_home, new_zone_radius, saved_state = {}):
    animal_id = str(new_id)
    species_id = str(new_species_id)
    home_center = new_home
    zone_radius = new_zone_radius
    profile = SpeciesProfiles.profile(species_id)

    state = AnimalState.new()
    state.setup(species_id, str(new_name), SpeciesProfiles.default_temperament(species_id))
    if typeof(saved_state) == TYPE_DICTIONARY and not saved_state.is_empty():
        state.from_dict(saved_state)

    brain = AnimalBrain.new(species_id, profile, state.temperament)
    position = home_center
    set_meta("animal_id", animal_id)
    collision_layer = 2
    collision_mask = 1

    _build_collision()
    _build_visual()
    _choose_next_action()

func _physics_process(delta):
    if state == null or brain == null:
        return

    state.tick(delta, profile)
    brain.tick_memory(delta)
    action_timer -= delta
    if action_timer <= 0.0:
        _choose_next_action()

    _update_motion(delta)
    _animate(delta)

func _build_collision():
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    if species_id == SpeciesProfiles.PYGMY_HIPPO:
        capsule.radius = 0.70
        capsule.height = 1.85
    elif species_id == SpeciesProfiles.PIG:
        capsule.radius = 0.50
        capsule.height = 1.45
    else:
        capsule.radius = 0.50
        capsule.height = 1.35
    collision.shape = capsule
    collision.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    add_child(collision)

func _build_visual():
    visual_root = Node3D.new()
    visual_root.name = "Visual"
    add_child(visual_root)

    if species_id == SpeciesProfiles.PYGMY_HIPPO:
        _build_hippo()
    elif species_id == SpeciesProfiles.PIG:
        _build_pig()
    else:
        _build_shar_pei()

func _build_hippo():
    var skin = _material(Color(0.30, 0.22, 0.28), 0.24)
    var wet_skin = _material(Color(0.38, 0.27, 0.34), 0.16)
    var muzzle = _material(Color(0.62, 0.38, 0.46), 0.30)
    var eye = _material(Color(0.012, 0.010, 0.012), 0.08)

    body_part = _sphere("Body", Vector3(-0.20, 0.38, 0.0), Vector3(1.45, 0.90, 0.88), wet_skin)
    _sphere("Chest", Vector3(0.48, 0.47, 0.0), Vector3(0.82, 0.78, 0.76), skin)
    head_part = _sphere("Head", Vector3(1.05, 0.60, 0.0), Vector3(0.82, 0.76, 0.74), skin)
    _sphere("Muzzle", Vector3(1.62, 0.35, 0.0), Vector3(0.68, 0.45, 0.63), muzzle)
    ear_left = _sphere("EarL", Vector3(0.91, 1.04, -0.49), Vector3(0.18, 0.23, 0.14), muzzle)
    ear_right = _sphere("EarR", Vector3(0.91, 1.04, 0.49), Vector3(0.18, 0.23, 0.14), muzzle)
    _sphere("EyeL", Vector3(1.46, 0.80, -0.42), Vector3(0.11, 0.11, 0.08), eye)
    _sphere("EyeR", Vector3(1.46, 0.80, 0.42), Vector3(0.11, 0.11, 0.08), eye)
    _sphere("NostrilL", Vector3(1.94, 0.44, -0.23), Vector3(0.07, 0.045, 0.07), eye)
    _sphere("NostrilR", Vector3(1.94, 0.44, 0.23), Vector3(0.07, 0.045, 0.07), eye)
    _four_legs(skin, 0.62, -0.84, 0.48, 0.28, 0.54)
    _sphere("Tail", Vector3(-1.48, 0.40, 0.0), Vector3(0.16, 0.16, 0.24), skin)

func _build_pig():
    var skin = _material(Color(0.78, 0.50, 0.48), 0.52)
    var light_skin = _material(Color(0.90, 0.62, 0.60), 0.48)
    var eye = _material(Color(0.025, 0.018, 0.014), 0.12)

    body_part = _sphere("Body", Vector3(-0.20, 0.42, 0.0), Vector3(1.20, 0.68, 0.65), skin)
    head_part = _sphere("Head", Vector3(0.88, 0.57, 0.0), Vector3(0.64, 0.58, 0.55), skin)
    _sphere("Snout", Vector3(1.40, 0.48, 0.0), Vector3(0.40, 0.28, 0.40), light_skin)
    _sphere("NostrilL", Vector3(1.61, 0.52, -0.14), Vector3(0.055, 0.035, 0.05), eye)
    _sphere("NostrilR", Vector3(1.61, 0.52, 0.14), Vector3(0.055, 0.035, 0.05), eye)
    _sphere("EyeL", Vector3(1.08, 0.75, -0.34), Vector3(0.075, 0.075, 0.055), eye)
    _sphere("EyeR", Vector3(1.08, 0.75, 0.34), Vector3(0.075, 0.075, 0.055), eye)
    ear_left = _sphere("EarL", Vector3(0.72, 1.00, -0.38), Vector3(0.17, 0.27, 0.12), skin)
    ear_right = _sphere("EarR", Vector3(0.72, 1.00, 0.38), Vector3(0.17, 0.27, 0.12), skin)
    _four_legs(skin, 0.48, -0.75, 0.38, 0.21, 0.50)
    _sphere("TailBase", Vector3(-1.27, 0.58, 0.0), Vector3(0.15, 0.12, 0.12), skin)
    _sphere("TailTip", Vector3(-1.40, 0.70, 0.10), Vector3(0.11, 0.11, 0.11), skin)

func _build_shar_pei():
    var coat = _material(Color(0.62, 0.40, 0.22), 0.76)
    var muzzle = _material(Color(0.50, 0.31, 0.20), 0.70)
    var dark = _material(Color(0.045, 0.032, 0.025), 0.30)

    body_part = _sphere("Body", Vector3(-0.18, 0.55, 0.0), Vector3(1.05, 0.70, 0.62), coat)
    _sphere("Shoulders", Vector3(0.38, 0.66, 0.0), Vector3(0.68, 0.72, 0.64), coat)
    head_part = _sphere("Head", Vector3(0.90, 0.88, 0.0), Vector3(0.64, 0.62, 0.60), coat)
    _sphere("HippoMuzzle", Vector3(1.40, 0.72, 0.0), Vector3(0.49, 0.34, 0.46), muzzle)
    _sphere("Nose", Vector3(1.66, 0.76, 0.0), Vector3(0.18, 0.13, 0.20), dark)
    _sphere("EyeL", Vector3(1.12, 1.02, -0.34), Vector3(0.07, 0.07, 0.055), dark)
    _sphere("EyeR", Vector3(1.12, 1.02, 0.34), Vector3(0.07, 0.07, 0.055), dark)
    ear_left = _sphere("EarL", Vector3(0.72, 1.35, -0.36), Vector3(0.18, 0.22, 0.10), coat)
    ear_right = _sphere("EarR", Vector3(0.72, 1.35, 0.36), Vector3(0.18, 0.22, 0.10), coat)
    _four_legs(coat, 0.48, -0.63, 0.40, 0.22, 0.63)
    _sphere("TailBase", Vector3(-1.12, 0.85, 0.0), Vector3(0.18, 0.22, 0.18), coat)
    _sphere("TailCurl", Vector3(-1.28, 1.05, 0.12), Vector3(0.16, 0.16, 0.16), coat)

func _four_legs(material, front_x, rear_x, z_value, leg_radius, leg_height):
    _sphere("LegFL", Vector3(front_x, -0.02, -z_value), Vector3(leg_radius, leg_height, leg_radius), material)
    _sphere("LegFR", Vector3(front_x, -0.02, z_value), Vector3(leg_radius, leg_height, leg_radius), material)
    _sphere("LegRL", Vector3(rear_x, -0.02, -z_value), Vector3(leg_radius, leg_height, leg_radius), material)
    _sphere("LegRR", Vector3(rear_x, -0.02, z_value), Vector3(leg_radius, leg_height, leg_radius), material)

func _sphere(part_name, local_position, local_scale, material):
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = part_name
    var sphere = SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    mesh_instance.mesh = sphere
    mesh_instance.position = local_position
    mesh_instance.scale = local_scale
    mesh_instance.material_override = material
    visual_root.add_child(mesh_instance)
    return mesh_instance

func _material(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _choose_next_action():
    if state == null or brain == null:
        return
    var hour = int(Time.get_time_dict_from_system().get("hour", 12))
    var context = {
        "owner_near": selected,
        "is_dusk_or_night": hour >= 18 or hour < 6,
        "water_available": species_id == SpeciesProfiles.PYGMY_HIPPO,
        "cover_available": true,
        "enrichment_available": true,
        "mud_available": species_id != SpeciesProfiles.SHAR_PEI,
        "unfamiliar_stimulus": false
    }
    current_action = brain.choose_action(state.needs, context)
    action_timer = randf_range(2.8, 6.0)

    if _action_moves(current_action):
        move_target = _random_point_in_zone()
    elif current_action == "enter_water" and species_id == SpeciesProfiles.PYGMY_HIPPO:
        move_target = home_center + Vector3(2.2, 0.0, 0.8)
    elif current_action == "hide" and species_id == SpeciesProfiles.PYGMY_HIPPO:
        move_target = home_center + Vector3(-2.0, 0.0, -1.5)
    elif current_action == "rest_near_owner" and species_id == SpeciesProfiles.SHAR_PEI:
        move_target = home_center + Vector3(0.8, 0.0, 0.4)

func _action_moves(action):
    return action in ["forage", "investigate", "approach_owner", "wallow", "play", "zoomies", "root", "push_object", "social_contact", "follow_owner", "patrol", "withdraw"]

func _random_point_in_zone():
    return home_center + Vector3(randf_range(-zone_radius.x, zone_radius.x), 0.0, randf_range(-zone_radius.y, zone_radius.y))

func _update_motion(delta):
    var moving = _action_moves(current_action) or current_action in ["enter_water", "hide", "rest_near_owner"]
    if not moving:
        velocity = Vector3(0.0, -0.2, 0.0)
        move_and_slide()
        if current_action == "rest":
            state.apply_rest(delta * 0.012)
        return

    var flat_target = Vector3(move_target.x, global_position.y, move_target.z)
    var distance = global_position.distance_to(flat_target)
    if distance < 0.35:
        velocity = Vector3(0.0, -0.2, 0.0)
        move_and_slide()
        if current_action in ["root", "forage", "investigate", "wallow", "enter_water"]:
            state.remember_zone(current_action, 0.18)
        return

    var direction = (flat_target - global_position).normalized()
    var speed = float(profile.get("base_speed", 0.9))
    if current_action == "zoomies":
        speed = float(profile.get("burst_speed", speed * 2.5))
    elif current_action in ["observe", "hide", "withdraw"]:
        speed *= 0.72

    velocity = Vector3(direction.x * speed, -0.2, direction.z * speed)
    move_and_slide()
    if direction.length_squared() > 0.01:
        look_at(global_position + direction, Vector3.UP)
        rotation.x = 0.0
        rotation.z = 0.0

func _animate(delta):
    if visual_root == null:
        return
    bob_phase += delta
    var moving = Vector2(velocity.x, velocity.z).length() > 0.08
    var breathing = sin(bob_phase * 2.0) * 0.018
    var step_bob = sin(bob_phase * 8.0) * 0.025 if moving else 0.0
    visual_root.position.y = breathing + step_bob

    if ear_left != null and ear_right != null:
        var flick = sin(bob_phase * 5.0 + float(animal_id.length())) * 0.10
        ear_left.rotation.z = flick
        ear_right.rotation.z = -flick

    if head_part != null:
        if current_action in ["root", "forage"]:
            head_part.rotation.z = sin(bob_phase * 4.0) * 0.10
        elif current_action in ["observe", "investigate"]:
            head_part.rotation.y = sin(bob_phase * 1.4) * 0.10
        else:
            head_part.rotation = head_part.rotation.lerp(Vector3.ZERO, min(delta * 4.0, 1.0))

    var selection_scale = 1.035 if selected else 1.0
    visual_root.scale = visual_root.scale.lerp(Vector3.ONE * selection_scale, min(delta * 5.0, 1.0))

func set_selected(value):
    selected = bool(value)

func feed(food_id = "balanced_feed"):
    state.apply_food(food_id, 0.24, 0.75)
    brain.register_owner_interaction("feed", true)
    current_action = "approach_owner"
    action_timer = 3.0

func pet(region = "forehead"):
    var touch_preferences = profile.get("touch_preferences", {})
    var preference = float(touch_preferences.get(region, 0.50))
    var social = float(state.emotion.get("social_motivation", 0.50))
    var annoyed = float(brain.memory.get("recent_annoyance", 0.0))
    var quality = clamp(preference * 0.70 + social * 0.35 - annoyed * 0.45, -1.0, 1.0)
    if quality >= 0.22:
        state.apply_pet(region, quality)
        brain.register_owner_interaction("pet", true)
        current_action = "approach_owner"
    else:
        state.apply_unwanted_interaction(0.65)
        brain.register_owner_interaction("pet", false)
        current_action = "withdraw" if species_id == SpeciesProfiles.SHAR_PEI else "hide"
        move_target = _random_point_in_zone()
    action_timer = 2.8
    return quality

func offline_simulate(minutes):
    state.offline_simulate(minutes)

func to_dict():
    var data = state.to_dict()
    data["brain_memory"] = brain.memory.duplicate(true)
    return data

func load_brain_memory(data):
    if typeof(data) == TYPE_DICTIONARY and brain != null:
        brain.memory = data.duplicate(true)

func display_name():
    return state.animal_name

func species_display_name():
    return str(profile.get("display_name", species_id))

func status_line():
    if current_action == "enter_water":
        return "%s is heading for the water" % state.animal_name
    if current_action == "root":
        return "%s is rooting through the ground" % state.animal_name
    if current_action == "observe":
        return "%s is quietly watching the sanctuary" % state.animal_name
    if current_action == "hide":
        return "%s wants some privacy" % state.animal_name
    if current_action == "withdraw":
        return "%s has decided to move away" % state.animal_name
    if current_action == "rest_near_owner":
        return "%s is resting nearby" % state.animal_name
    if current_action == "forage":
        return "%s is looking for something to eat" % state.animal_name
    if current_action == "play" or current_action == "zoomies":
        return "%s is feeling playful" % state.animal_name
    if current_action == "wallow":
        return "%s is enjoying the mud" % state.animal_name
    if current_action == "rest":
        return "%s is resting" % state.animal_name
    if current_action == "patrol":
        return "%s is checking the grounds" % state.animal_name
    if current_action == "investigate":
        return "%s is investigating something" % state.animal_name
    return "%s is %s" % [state.animal_name, current_action.replace("_", " ")]
