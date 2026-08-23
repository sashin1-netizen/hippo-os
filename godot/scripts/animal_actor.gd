extends CharacterBody3D

const SpeciesProfiles = preload("res://scripts/species_profiles.gd")
const AnimalState = preload("res://scripts/animal_state.gd")
const AnimalBrain = preload("res://scripts/animal_brain.gd")

const MODEL_PATHS = {
    SpeciesProfiles.PYGMY_HIPPO: "res://assets/models/mochi_pygmy_hippo.glb",
    SpeciesProfiles.PIG: "res://assets/models/truffle_pig.glb",
    SpeciesProfiles.SHAR_PEI: "res://assets/models/bao_shar_pei.glb"
}
const VOCAL_PATHS = {
    SpeciesProfiles.PYGMY_HIPPO: "res://assets/audio/hippo_grunts.mp3",
    SpeciesProfiles.PIG: "res://assets/audio/pig_grunt.ogg",
    SpeciesProfiles.SHAR_PEI: "res://assets/audio/dog_bark.ogg"
}
const STEP_PATHS = {
    SpeciesProfiles.PYGMY_HIPPO: "res://assets/audio/hippo_step.wav",
    SpeciesProfiles.PIG: "res://assets/audio/pig_step.wav",
    SpeciesProfiles.SHAR_PEI: "res://assets/audio/dog_step.wav"
}
const MODEL_Y_OFFSETS = {
    SpeciesProfiles.PYGMY_HIPPO: -0.76,
    SpeciesProfiles.PIG: -0.54,
    SpeciesProfiles.SHAR_PEI: -0.61
}
const MODEL_SCALES = {
    SpeciesProfiles.PYGMY_HIPPO: 1.08,
    SpeciesProfiles.PIG: 0.98,
    SpeciesProfiles.SHAR_PEI: 1.00
}

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
var production_model
var animation_player
var active_animation = ""
var selected = false
var vocal_player
var step_player
var action_player
var footstep_timer = 0.0
var vocal_timer = 4.0
var action_effect_played = false

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
    _build_audio()
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
    _update_audio(delta)

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
    var model_path = str(MODEL_PATHS.get(species_id, ""))
    if model_path.is_empty() or not ResourceLoader.exists(model_path):
        push_error("Production animal model missing for %s: %s" % [species_id, model_path])
        return
    var packed = load(model_path)
    if packed == null or not packed is PackedScene:
        push_error("Production animal model failed to load for %s" % species_id)
        return
    production_model = packed.instantiate()
    production_model.name = "ProductionModel"
    if production_model is Node3D:
        production_model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
        production_model.position.y = float(MODEL_Y_OFFSETS.get(species_id, -0.6))
        var model_scale = float(MODEL_SCALES.get(species_id, 1.0))
        production_model.scale = Vector3.ONE * model_scale
    visual_root.add_child(production_model)
    animation_player = _find_animation_player(production_model)
    if animation_player == null:
        push_error("Production animal model has no AnimationPlayer: %s" % model_path)
        return
    for required_clip in ["idle", "move", "eat", "rest"]:
        if not animation_player.has_animation(required_clip):
            push_error("Production model %s is missing animation: %s" % [species_id, required_clip])
    _play_animation("idle")

func _build_audio():
    vocal_player = AudioStreamPlayer3D.new()
    vocal_player.name = "VocalAudio"
    vocal_player.bus = "Animal"
    vocal_player.max_distance = 20.0
    vocal_player.unit_size = 3.0
    var vocal_path = str(VOCAL_PATHS.get(species_id, ""))
    if ResourceLoader.exists(vocal_path):
        vocal_player.stream = load(vocal_path)
    else:
        push_error("Animal vocal audio missing: %s" % vocal_path)
    add_child(vocal_player)

    step_player = AudioStreamPlayer3D.new()
    step_player.name = "StepAudio"
    step_player.bus = "Animal"
    step_player.max_distance = 14.0
    step_player.unit_size = 2.0
    var step_path = str(STEP_PATHS.get(species_id, ""))
    if ResourceLoader.exists(step_path):
        step_player.stream = load(step_path)
    else:
        push_error("Animal step audio missing: %s" % step_path)
    add_child(step_player)

    action_player = AudioStreamPlayer3D.new()
    action_player.name = "ActionAudio"
    action_player.bus = "Animal"
    action_player.max_distance = 16.0
    action_player.unit_size = 2.5
    add_child(action_player)
    vocal_timer = randf_range(4.5, 12.0)

func _find_animation_player(node):
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found = _find_animation_player(child)
        if found != null:
            return found
    return null

func _play_animation(clip_name):
    if animation_player == null or active_animation == clip_name:
        return
    if not animation_player.has_animation(clip_name):
        return
    animation_player.play(clip_name, 0.18)
    active_animation = clip_name

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
    action_effect_played = false
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
        if not action_effect_played:
            if current_action == "enter_water":
                _play_action_sound("res://assets/audio/water_splash.wav")
            elif current_action in ["wallow", "root"]:
                _play_action_sound("res://assets/audio/mud_squelch.wav")
            action_effect_played = true
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
    var is_moving = Vector2(velocity.x, velocity.z).length() > 0.08
    var desired_clip = "idle"
    if is_moving:
        desired_clip = "move"
    elif current_action in ["eat", "forage", "root"]:
        desired_clip = "eat"
    elif current_action in ["rest", "sleep", "rest_near_owner"]:
        desired_clip = "rest"
    _play_animation(desired_clip)
    var selection_scale = 1.025 if selected else 1.0
    visual_root.scale = visual_root.scale.lerp(Vector3.ONE * selection_scale, min(delta * 5.0, 1.0))

func _update_audio(delta):
    footstep_timer -= delta
    vocal_timer -= delta
    var is_moving = Vector2(velocity.x, velocity.z).length() > 0.08
    if is_moving and footstep_timer <= 0.0 and step_player != null and step_player.stream != null:
        step_player.pitch_scale = randf_range(0.94, 1.06)
        step_player.play()
        if species_id == SpeciesProfiles.PYGMY_HIPPO:
            footstep_timer = 0.52
        elif species_id == SpeciesProfiles.PIG:
            footstep_timer = 0.38
        else:
            footstep_timer = 0.32
    if vocal_timer <= 0.0:
        _maybe_vocalize()
        vocal_timer = randf_range(8.0, 19.0)

func _maybe_vocalize():
    if vocal_player == null or vocal_player.stream == null or vocal_player.playing:
        return
    var social = float(state.emotion.get("social_motivation", 0.5))
    var arousal = float(state.emotion.get("arousal", 0.4))
    var chance = 0.12 + arousal * 0.18 + (0.12 if selected else 0.0) + social * 0.06
    if randf() > chance:
        return
    vocal_player.pitch_scale = randf_range(0.95, 1.05)
    vocal_player.play()

func _play_action_sound(path):
    if action_player == null or not ResourceLoader.exists(path):
        return
    action_player.stream = load(path)
    action_player.pitch_scale = randf_range(0.96, 1.04)
    action_player.play()

func set_selected(value):
    selected = bool(value)

func feed(food_id = "balanced_feed"):
    state.apply_food(food_id, 0.24, 0.75)
    brain.register_owner_interaction("feed", true)
    current_action = "eat"
    action_timer = 2.4
    _play_action_sound("res://assets/audio/eat_crunch.wav")

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
    if current_action == "enter_water": return "%s is heading for the water" % state.animal_name
    if current_action == "root": return "%s is rooting through the ground" % state.animal_name
    if current_action == "observe": return "%s is quietly watching the sanctuary" % state.animal_name
    if current_action == "hide": return "%s wants some privacy" % state.animal_name
    if current_action == "withdraw": return "%s has decided to move away" % state.animal_name
    if current_action == "rest_near_owner": return "%s is resting nearby" % state.animal_name
    if current_action == "forage": return "%s is looking for something to eat" % state.animal_name
    if current_action == "eat": return "%s is eating" % state.animal_name
    if current_action in ["play", "zoomies"]: return "%s is feeling playful" % state.animal_name
    if current_action == "wallow": return "%s is enjoying the mud" % state.animal_name
    if current_action == "rest": return "%s is resting" % state.animal_name
    if current_action == "patrol": return "%s is checking the grounds" % state.animal_name
    if current_action == "investigate": return "%s is investigating something" % state.animal_name
    return "%s is %s" % [state.animal_name, current_action.replace("_", " ")]
