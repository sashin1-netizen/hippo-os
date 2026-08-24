extends Node

const SAVE_PATH = "user://companion_roster.json"
const SAVE_VERSION = 1
const SPECIES_HIPPO = "hippo"
const SPECIES_PIG = "pig"
const SPECIES_SHARPEI = "sharpei"
const ROAM_MIN_X = -5.4
const ROAM_MAX_X = 5.4
const ROAM_MIN_Z = -4.1
const ROAM_MAX_Z = 4.1

var main_scene: Node3D
var roster_root: Node3D
var companions = {}
var selected_species = SPECIES_HIPPO
var panel_open = false
var ui_refresh_timer = 0.0
var saved_data = {}

var animals_button: Button
var roster_panel: ColorRect
var roster_title: Label
var selected_name_label: Label
var selected_species_label: Label
var selected_stats_label: Label
var selected_action_label: Label
var hippo_button: Button
var pig_button: Button
var sharpei_button: Button
var pet_button: Button
var treat_button: Button
var call_button: Button

func _ready():
    randomize()
    set_process(false)
    call_deferred("_attach_when_scene_ready")

func _attach_when_scene_ready():
    for _attempt in range(180):
        var candidate = get_tree().current_scene
        if candidate and candidate is Node3D:
            main_scene = candidate
            break
        await get_tree().process_frame

    if not main_scene:
        push_warning("CompanionRoster could not find the active 3D scene")
        return

    await get_tree().process_frame

    roster_root = Node3D.new()
    roster_root.name = "CompanionRosterWorld"
    main_scene.add_child(roster_root)

    _load_state()
    _register_hippo()
    _spawn_pig()
    _spawn_sharpei()
    _build_roster_ui()
    _apply_loaded_state()
    _update_roster_ui()
    set_process(true)

func _process(delta):
    if not main_scene:
        return

    _update_companion(SPECIES_PIG, delta)
    _update_companion(SPECIES_SHARPEI, delta)

    ui_refresh_timer += delta
    if ui_refresh_timer >= 0.20:
        ui_refresh_timer = 0.0
        _update_roster_ui()

func _register_hippo():
    var hippo_node = main_scene.get_node_or_null("BabyHippo")
    companions[SPECIES_HIPPO] = {
        "node": hippo_node,
        "name": _main_value("hippo_name", "Mochi"),
        "species_label": "Baby pygmy hippo",
        "tagline": "Water-loving, curious and social",
        "accent": Color(0.72, 0.47, 0.68),
    }

func _spawn_pig():
    var pig = CharacterBody3D.new()
    pig.name = "PorkyPig"
    pig.position = Vector3(-2.6, 0.72, -1.7)
    pig.collision_layer = 4
    pig.collision_mask = 1
    roster_root.add_child(pig)
    _add_horizontal_collision(pig, 0.52, 1.45)

    var visual = Node3D.new()
    visual.name = "Visual"
    pig.add_child(visual)

    var pink = _material(Color(0.76, 0.47, 0.46), 0.62)
    var light_pink = _material(Color(0.88, 0.61, 0.59), 0.54)
    var dark = _material(Color(0.08, 0.055, 0.05), 0.36)

    _sphere(visual, "Body", Vector3(-0.05, 0.34, 0.0), Vector3(1.18, 0.70, 0.70), pink)
    _sphere(visual, "Shoulders", Vector3(0.62, 0.43, 0.0), Vector3(0.70, 0.66, 0.66), pink)
    var head = _sphere(visual, "Head", Vector3(0.96, 0.60, 0.0), Vector3(0.62, 0.62, 0.60), pink)
    _sphere(visual, "Snout", Vector3(1.45, 0.43, 0.0), Vector3(0.46, 0.30, 0.38), light_pink)
    _sphere(visual, "NostrilL", Vector3(1.66, 0.48, -0.14), Vector3(0.055, 0.045, 0.045), dark)
    _sphere(visual, "NostrilR", Vector3(1.66, 0.48, 0.14), Vector3(0.055, 0.045, 0.045), dark)
    var ear_l = _sphere(visual, "EarL", Vector3(0.92, 1.02, -0.43), Vector3(0.22, 0.34, 0.13), pink)
    var ear_r = _sphere(visual, "EarR", Vector3(0.92, 1.02, 0.43), Vector3(0.22, 0.34, 0.13), pink)
    ear_l.rotation.z = -0.34
    ear_r.rotation.z = 0.34
    _sphere(visual, "EyeL", Vector3(1.28, 0.75, -0.39), Vector3(0.075, 0.075, 0.06), dark)
    _sphere(visual, "EyeR", Vector3(1.28, 0.75, 0.39), Vector3(0.075, 0.075, 0.06), dark)

    var legs = []
    legs.append(_sphere(visual, "LegFL", Vector3(0.62, -0.18, -0.43), Vector3(0.25, 0.55, 0.25), pink))
    legs.append(_sphere(visual, "LegFR", Vector3(0.62, -0.18, 0.43), Vector3(0.25, 0.55, 0.25), pink))
    legs.append(_sphere(visual, "LegRL", Vector3(-0.72, -0.18, -0.43), Vector3(0.25, 0.55, 0.25), pink))
    legs.append(_sphere(visual, "LegRR", Vector3(-0.72, -0.18, 0.43), Vector3(0.25, 0.55, 0.25), pink))

    var tail_parts = _build_curled_tail(visual, Vector3(-1.18, 0.58, 0.0), pink, 0.32, 0.085)

    companions[SPECIES_PIG] = {
        "node": pig,
        "visual": visual,
        "head": head,
        "ears": [ear_l, ear_r],
        "legs": legs,
        "tail_parts": tail_parts,
        "name": "Porky",
        "species_label": "Pig",
        "tagline": "Food-motivated, clever and playful",
        "accent": Color(0.95, 0.61, 0.58),
        "bond": 0.30,
        "hunger": 0.24,
        "energy": 0.84,
        "curiosity": 0.78,
        "playfulness": 0.74,
        "action": "sniff",
        "action_timer": 1.0,
        "target": Vector3(-1.5, 0.72, -0.5),
        "call_until": 0.0,
        "pet_pulse": 0.0,
    }

func _spawn_sharpei():
    var dog = CharacterBody3D.new()
    dog.name = "BaoSharPei"
    dog.position = Vector3(2.5, 0.75, -1.8)
    dog.collision_layer = 8
    dog.collision_mask = 1
    roster_root.add_child(dog)
    _add_horizontal_collision(dog, 0.55, 1.55)

    var visual = Node3D.new()
    visual.name = "Visual"
    dog.add_child(visual)

    var coat = _material(Color(0.68, 0.43, 0.24), 0.78)
    var fold = _material(Color(0.60, 0.35, 0.19), 0.82)
    var muzzle = _material(Color(0.49, 0.29, 0.18), 0.74)
    var dark = _material(Color(0.045, 0.035, 0.03), 0.42)

    _sphere(visual, "Body", Vector3(-0.08, 0.42, 0.0), Vector3(1.15, 0.70, 0.66), coat)
    _sphere(visual, "Chest", Vector3(0.60, 0.48, 0.0), Vector3(0.68, 0.72, 0.64), coat)
    _sphere(visual, "NeckFoldA", Vector3(0.69, 0.69, 0.0), Vector3(0.56, 0.20, 0.62), fold)
    _sphere(visual, "NeckFoldB", Vector3(0.76, 0.82, 0.0), Vector3(0.52, 0.18, 0.59), fold)
    var head = _sphere(visual, "Head", Vector3(1.02, 0.78, 0.0), Vector3(0.68, 0.67, 0.63), coat)
    _sphere(visual, "BrowFold", Vector3(1.16, 1.02, 0.0), Vector3(0.52, 0.17, 0.56), fold)
    _sphere(visual, "Muzzle", Vector3(1.49, 0.58, 0.0), Vector3(0.50, 0.37, 0.43), muzzle)
    _sphere(visual, "Nose", Vector3(1.78, 0.65, 0.0), Vector3(0.20, 0.14, 0.18), dark)
    var ear_l = _sphere(visual, "EarL", Vector3(0.93, 1.20, -0.43), Vector3(0.18, 0.28, 0.11), coat)
    var ear_r = _sphere(visual, "EarR", Vector3(0.93, 1.20, 0.43), Vector3(0.18, 0.28, 0.11), coat)
    ear_l.rotation.z = -0.45
    ear_r.rotation.z = 0.45
    _sphere(visual, "EyeL", Vector3(1.31, 0.92, -0.40), Vector3(0.07, 0.065, 0.055), dark)
    _sphere(visual, "EyeR", Vector3(1.31, 0.92, 0.40), Vector3(0.07, 0.065, 0.055), dark)

    var legs = []
    legs.append(_sphere(visual, "LegFL", Vector3(0.58, -0.12, -0.43), Vector3(0.25, 0.62, 0.25), coat))
    legs.append(_sphere(visual, "LegFR", Vector3(0.58, -0.12, 0.43), Vector3(0.25, 0.62, 0.25), coat))
    legs.append(_sphere(visual, "LegRL", Vector3(-0.70, -0.12, -0.43), Vector3(0.26, 0.64, 0.26), coat))
    legs.append(_sphere(visual, "LegRR", Vector3(-0.70, -0.12, 0.43), Vector3(0.26, 0.64, 0.26), coat))

    var tail_parts = _build_curled_tail(visual, Vector3(-1.17, 0.72, 0.0), coat, 0.46, 0.10)

    companions[SPECIES_SHARPEI] = {
        "node": dog,
        "visual": visual,
        "head": head,
        "ears": [ear_l, ear_r],
        "legs": legs,
        "tail_parts": tail_parts,
        "name": "Bao",
        "species_label": "Shar-Pei",
        "tagline": "Loyal, observant and quietly affectionate",
        "accent": Color(0.84, 0.58, 0.34),
        "bond": 0.34,
        "hunger": 0.20,
        "energy": 0.80,
        "curiosity": 0.60,
        "playfulness": 0.58,
        "action": "watch",
        "action_timer": 1.4,
        "target": Vector3(1.3, 0.75, -0.4),
        "call_until": 0.0,
        "pet_pulse": 0.0,
    }

func _add_horizontal_collision(body: CharacterBody3D, radius: float, height: float):
    var collision = CollisionShape3D.new()
    var shape = CapsuleShape3D.new()
    shape.radius = radius
    shape.height = height
    collision.shape = shape
    collision.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    body.add_child(collision)

func _sphere(parent: Node3D, part_name: String, local_position: Vector3, local_scale: Vector3, material: Material):
    var part = MeshInstance3D.new()
    part.name = part_name
    var mesh = SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    part.mesh = mesh
    part.position = local_position
    part.scale = local_scale
    part.material_override = material
    parent.add_child(part)
    return part

func _build_curled_tail(parent: Node3D, origin: Vector3, material: Material, curl_radius: float, bead_size: float):
    var parts = []
    for i in range(7):
        var t = float(i) / 6.0
        var angle = t * PI * 1.65
        var bead = _sphere(
            parent,
            "Tail%02d" % i,
            origin + Vector3(-0.05 * t, cos(angle) * curl_radius * 0.55, sin(angle) * curl_radius),
            Vector3(bead_size, bead_size, bead_size),
            material
        )
        parts.append(bead)
    return parts

func _material(color: Color, roughness: float):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _update_companion(species: String, delta: float):
    if not companions.has(species):
        return
    var data = companions[species]
    var body = data.get("node") as CharacterBody3D
    if not body or not is_instance_valid(body):
        return

    data["hunger"] = clamp(float(data.get("hunger", 0.2)) + delta * 0.000055, 0.0, 0.94)
    data["energy"] = clamp(float(data.get("energy", 0.8)) - delta * 0.000040, 0.10, 1.0)
    data["curiosity"] = clamp(float(data.get("curiosity", 0.6)) - delta * 0.000025, 0.12, 1.0)
    data["action_timer"] = float(data.get("action_timer", 0.0)) - delta
    data["pet_pulse"] = max(0.0, float(data.get("pet_pulse", 0.0)) - delta * 1.8)

    if float(data.get("action_timer", 0.0)) <= 0.0:
        _choose_companion_action(species)
        data = companions[species]

    var now = Time.get_ticks_msec() / 1000.0
    var action = str(data.get("action", "idle"))
    var direction = Vector3.ZERO
    var speed = 0.0
    var call_until = float(data.get("call_until", 0.0))

    if call_until > now:
        var call_target = Vector3(0.0, body.position.y, 0.35)
        if body.position.distance_to(call_target) > 1.45:
            direction = (call_target - body.position).normalized()
            speed = 1.22 if species == SPECIES_SHARPEI else 1.02
            data["action"] = "coming"
    elif action == "wander" or action == "sniff" or action == "play":
        var target = data.get("target", body.position)
        if body.position.distance_to(target) < 0.55:
            data["target"] = _new_roam_target(body.position.y)
            target = data["target"]
        direction = (target - body.position).normalized()
        if action == "play":
            speed = 1.72 if species == SPECIES_SHARPEI else 1.42
        elif action == "sniff":
            speed = 0.58
        else:
            speed = 0.88
    elif action == "rest":
        data["energy"] = clamp(float(data.get("energy", 0.8)) + delta * 0.0055, 0.10, 1.0)

    body.velocity = Vector3(direction.x * speed, -0.18, direction.z * speed)
    body.move_and_slide()
    body.position.x = clamp(body.position.x, ROAM_MIN_X, ROAM_MAX_X)
    body.position.z = clamp(body.position.z, ROAM_MIN_Z, ROAM_MAX_Z)

    if direction.length_squared() > 0.02:
        body.rotation.y = atan2(-direction.z, direction.x)

    var visual = data.get("visual") as Node3D
    if visual:
        var motion_reduction = 0.38 if _reduced_motion() else 1.0
        var breathe_rate = 2.25 if species == SPECIES_PIG else 1.85
        var breathe = sin(now * breathe_rate) * 0.022 * motion_reduction
        var pet_lift = sin(now * 11.0) * 0.035 * float(data.get("pet_pulse", 0.0))
        var rest_scale = 0.82 if action == "rest" else 1.0
        visual.scale = Vector3(1.0 + breathe, rest_scale + breathe * 0.45, 1.0 + breathe)
        visual.position.y = pet_lift

    var moving = direction.length_squared() > 0.02
    var stride = sin(now * max(speed, 0.65) * 7.0) * 0.34 if moving else 0.0
    if _reduced_motion():
        stride *= 0.35
    var legs = data.get("legs", [])
    if legs.size() >= 4:
        legs[0].rotation.z = stride
        legs[3].rotation.z = stride
        legs[1].rotation.z = -stride
        legs[2].rotation.z = -stride

    var tail_parts = data.get("tail_parts", [])
    var tail_wag = 0.22 if species == SPECIES_PIG else 0.42
    if action == "play" or float(data.get("pet_pulse", 0.0)) > 0.0:
        tail_wag *= 1.8
    for i in range(tail_parts.size()):
        tail_parts[i].rotation.y = sin(now * 4.4 + float(i) * 0.22) * tail_wag

    var ears = data.get("ears", [])
    if ears.size() >= 2:
        var ear_flick = sin(now * 1.35 + (0.7 if species == SPECIES_PIG else 0.0))
        ears[0].rotation.x = ear_flick * 0.055
        ears[1].rotation.x = -ear_flick * 0.055

    companions[species] = data

func _choose_companion_action(species: String):
    var data = companions[species]
    var energy = float(data.get("energy", 0.8))
    var hunger = float(data.get("hunger", 0.2))
    var curiosity = float(data.get("curiosity", 0.6))
    var playfulness = float(data.get("playfulness", 0.6))

    var action = "watch"
    if energy < 0.28:
        action = "rest"
    elif hunger > 0.76:
        action = "sniff"
    else:
        var roll = randf()
        if roll < 0.20 + playfulness * 0.18 and energy > 0.52:
            action = "play"
        elif roll < 0.54:
            action = "wander"
        elif roll < 0.77 + curiosity * 0.08:
            action = "sniff"
        else:
            action = "watch"

    data["action"] = action
    data["action_timer"] = randf_range(3.4, 7.4)
    if action == "wander" or action == "sniff" or action == "play":
        var body = data.get("node") as CharacterBody3D
        data["target"] = _new_roam_target(body.position.y if body else 0.75)
    companions[species] = data

func _new_roam_target(y: float):
    return Vector3(randf_range(ROAM_MIN_X, ROAM_MAX_X), y, randf_range(ROAM_MIN_Z, ROAM_MAX_Z))

func _build_roster_ui():
    var ui = CanvasLayer.new()
    ui.name = "CompanionRosterUI"
    ui.layer = 30
    main_scene.add_child(ui)

    animals_button = Button.new()
    animals_button.text = "ANIMALS"
    animals_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    animals_button.offset_left = -472.0
    animals_button.offset_top = 20.0
    animals_button.offset_right = -322.0
    animals_button.offset_bottom = 78.0
    animals_button.add_theme_font_size_override("font_size", 17)
    animals_button.pressed.connect(_toggle_roster_panel)
    ui.add_child(animals_button)

    roster_panel = ColorRect.new()
    roster_panel.color = Color(0.015, 0.022, 0.028, 0.96)
    roster_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    roster_panel.offset_left = -455.0
    roster_panel.offset_top = 92.0
    roster_panel.offset_right = -20.0
    roster_panel.offset_bottom = 600.0
    roster_panel.visible = false
    ui.add_child(roster_panel)

    roster_title = Label.new()
    roster_title.text = "YOUR COMPANIONS"
    roster_title.position = Vector2(22, 16)
    roster_title.add_theme_font_size_override("font_size", 24)
    roster_panel.add_child(roster_title)

    var intro = Label.new()
    intro.text = "All three live in the sanctuary. Select one to interact."
    intro.position = Vector2(22, 51)
    intro.add_theme_font_size_override("font_size", 13)
    roster_panel.add_child(intro)

    hippo_button = _roster_button("MOCHI  •  PYGMY HIPPO", 82)
    hippo_button.pressed.connect(_select_companion.bind(SPECIES_HIPPO))
    pig_button = _roster_button("PORKY  •  PIG", 132)
    pig_button.pressed.connect(_select_companion.bind(SPECIES_PIG))
    sharpei_button = _roster_button("BAO  •  SHAR-PEI", 182)
    sharpei_button.pressed.connect(_select_companion.bind(SPECIES_SHARPEI))

    var divider = HSeparator.new()
    divider.position = Vector2(20, 240)
    divider.size = Vector2(395, 8)
    roster_panel.add_child(divider)

    selected_name_label = Label.new()
    selected_name_label.position = Vector2(22, 258)
    selected_name_label.add_theme_font_size_override("font_size", 27)
    roster_panel.add_child(selected_name_label)

    selected_species_label = Label.new()
    selected_species_label.position = Vector2(22, 296)
    selected_species_label.add_theme_font_size_override("font_size", 15)
    roster_panel.add_child(selected_species_label)

    selected_stats_label = Label.new()
    selected_stats_label.position = Vector2(22, 328)
    selected_stats_label.add_theme_font_size_override("font_size", 14)
    roster_panel.add_child(selected_stats_label)

    selected_action_label = Label.new()
    selected_action_label.position = Vector2(22, 356)
    selected_action_label.add_theme_font_size_override("font_size", 14)
    roster_panel.add_child(selected_action_label)

    pet_button = Button.new()
    pet_button.text = "PET"
    pet_button.position = Vector2(22, 407)
    pet_button.size = Vector2(118, 54)
    pet_button.pressed.connect(_pet_selected)
    roster_panel.add_child(pet_button)

    treat_button = Button.new()
    treat_button.text = "TREAT"
    treat_button.position = Vector2(151, 407)
    treat_button.size = Vector2(118, 54)
    treat_button.pressed.connect(_treat_selected)
    roster_panel.add_child(treat_button)

    call_button = Button.new()
    call_button.text = "CALL"
    call_button.position = Vector2(280, 407)
    call_button.size = Vector2(118, 54)
    call_button.pressed.connect(_call_selected)
    roster_panel.add_child(call_button)

    var footer = Label.new()
    footer.text = "Pygmy hippo • Pig • Shar-Pei"
    footer.position = Vector2(22, 474)
    footer.add_theme_font_size_override("font_size", 13)
    roster_panel.add_child(footer)

func _roster_button(text_value: String, y: float):
    var button = Button.new()
    button.text = text_value
    button.position = Vector2(22, y)
    button.size = Vector2(376, 42)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 15)
    roster_panel.add_child(button)
    return button

func _toggle_roster_panel():
    panel_open = not panel_open
    roster_panel.visible = panel_open
    if panel_open:
        _register_hippo()
        _update_roster_ui()
    _haptic(18)

func _select_companion(species: String):
    if not companions.has(species):
        return
    selected_species = species
    if species != SPECIES_HIPPO:
        var data = companions[species]
        data["call_until"] = Time.get_ticks_msec() / 1000.0 + 4.5
        companions[species] = data
    _save_state()
    _haptic(24)
    _update_roster_ui()

func _pet_selected():
    if selected_species == SPECIES_HIPPO:
        if main_scene.has_method("_pet"):
            main_scene.call("_pet", 0.85, "head")
    elif companions.has(selected_species):
        var data = companions[selected_species]
        data["bond"] = clamp(float(data.get("bond", 0.3)) + 0.018, 0.0, 1.0)
        data["curiosity"] = clamp(float(data.get("curiosity", 0.6)) + 0.025, 0.0, 1.0)
        data["pet_pulse"] = 1.0
        data["action"] = "happy"
        data["action_timer"] = 2.2
        companions[selected_species] = data
    _haptic(18)
    _save_state()
    _update_roster_ui()

func _treat_selected():
    if selected_species == SPECIES_HIPPO:
        if main_scene.has_method("_feed_hippo"):
            main_scene.call("_feed_hippo")
    elif companions.has(selected_species):
        var data = companions[selected_species]
        data["hunger"] = clamp(float(data.get("hunger", 0.2)) - 0.27, 0.0, 1.0)
        data["bond"] = clamp(float(data.get("bond", 0.3)) + 0.010, 0.0, 1.0)
        data["energy"] = clamp(float(data.get("energy", 0.8)) + 0.035, 0.0, 1.0)
        data["action"] = "happy"
        data["action_timer"] = 2.6
        companions[selected_species] = data
    _haptic(26)
    _save_state()
    _update_roster_ui()

func _call_selected():
    if selected_species == SPECIES_HIPPO:
        main_scene.set("current_action", "approach")
        main_scene.set("action_timer", 4.5)
    elif companions.has(selected_species):
        var data = companions[selected_species]
        data["call_until"] = Time.get_ticks_msec() / 1000.0 + 7.0
        data["action"] = "coming"
        companions[selected_species] = data
    _haptic(22)
    _update_roster_ui()

func _update_roster_ui():
    if not roster_panel:
        return

    _register_hippo()
    var hippo_name = str(_main_value("hippo_name", "Mochi"))
    hippo_button.text = ("● " if selected_species == SPECIES_HIPPO else "   ") + hippo_name.to_upper() + "  •  PYGMY HIPPO"
    pig_button.text = ("● " if selected_species == SPECIES_PIG else "   ") + str(companions[SPECIES_PIG].get("name", "Porky")).to_upper() + "  •  PIG"
    sharpei_button.text = ("● " if selected_species == SPECIES_SHARPEI else "   ") + str(companions[SPECIES_SHARPEI].get("name", "Bao")).to_upper() + "  •  SHAR-PEI"

    if selected_species == SPECIES_HIPPO:
        selected_name_label.text = hippo_name
        selected_species_label.text = "Baby pygmy hippo • water-loving, curious and social"
        selected_stats_label.text = "Bond %d%%   Hunger %d%%   Energy %d%%" % [
            int(float(_main_value("bond", 0.35)) * 100.0),
            int(float(_main_value("hunger", 0.18)) * 100.0),
            int(float(_main_value("energy", 0.88)) * 100.0)
        ]
        selected_action_label.text = "Now: %s" % str(_main_value("current_action", "idle")).capitalize()
    else:
        var data = companions[selected_species]
        selected_name_label.text = str(data.get("name", "Companion"))
        selected_species_label.text = "%s • %s" % [str(data.get("species_label", "Animal")), str(data.get("tagline", ""))]
        selected_stats_label.text = "Bond %d%%   Hunger %d%%   Energy %d%%" % [
            int(float(data.get("bond", 0.3)) * 100.0),
            int(float(data.get("hunger", 0.2)) * 100.0),
            int(float(data.get("energy", 0.8)) * 100.0)
        ]
        selected_action_label.text = "Now: %s" % _friendly_action(str(data.get("action", "watch")))

func _friendly_action(action: String):
    match action:
        "play":
            return "playing"
        "wander":
            return "exploring"
        "sniff":
            return "sniffing around"
        "rest":
            return "resting"
        "coming":
            return "coming when called"
        "happy":
            return "enjoying your attention"
        _:
            return "watching the sanctuary"

func _main_value(property_name: String, fallback):
    if not main_scene:
        return fallback
    var value = main_scene.get(property_name)
    return fallback if value == null else value

func _reduced_motion():
    var settings_value = _main_value("settings", {})
    if typeof(settings_value) == TYPE_DICTIONARY:
        return bool(settings_value.get("reduced_motion", false))
    return false

func _haptic(duration_ms: int):
    var settings_value = _main_value("settings", {})
    if typeof(settings_value) == TYPE_DICTIONARY and not bool(settings_value.get("haptics", true)):
        return
    Input.vibrate_handheld(duration_ms)

func _save_state():
    if companions.is_empty():
        return
    var animal_data = {}
    for species in [SPECIES_PIG, SPECIES_SHARPEI]:
        if companions.has(species):
            var data = companions[species]
            animal_data[species] = {
                "name": str(data.get("name", "Companion")),
                "bond": float(data.get("bond", 0.3)),
                "hunger": float(data.get("hunger", 0.2)),
                "energy": float(data.get("energy", 0.8)),
                "curiosity": float(data.get("curiosity", 0.6)),
                "last_position": _vector_to_array((data.get("node") as CharacterBody3D).position),
            }

    var payload = {
        "save_version": SAVE_VERSION,
        "selected_species": selected_species,
        "animals": animal_data,
        "last_save": int(Time.get_unix_time_from_system()),
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(payload))

func _load_state():
    saved_data = {}
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        saved_data = parsed

func _apply_loaded_state():
    if saved_data.is_empty():
        return

    var requested_species = str(saved_data.get("selected_species", SPECIES_HIPPO))
    if requested_species in [SPECIES_HIPPO, SPECIES_PIG, SPECIES_SHARPEI]:
        selected_species = requested_species

    var animals = saved_data.get("animals", {})
    if typeof(animals) == TYPE_DICTIONARY:
        for species in [SPECIES_PIG, SPECIES_SHARPEI]:
            if not animals.has(species) or not companions.has(species):
                continue
            var saved = animals[species]
            if typeof(saved) != TYPE_DICTIONARY:
                continue
            var data = companions[species]
            data["name"] = str(saved.get("name", data.get("name", "Companion"))).left(18)
            data["bond"] = clamp(float(saved.get("bond", data.get("bond", 0.3))), 0.0, 1.0)
            data["hunger"] = clamp(float(saved.get("hunger", data.get("hunger", 0.2))), 0.0, 0.94)
            data["energy"] = clamp(float(saved.get("energy", data.get("energy", 0.8))), 0.10, 1.0)
            data["curiosity"] = clamp(float(saved.get("curiosity", data.get("curiosity", 0.6))), 0.12, 1.0)
            var position_values = saved.get("last_position", [])
            var body = data.get("node") as CharacterBody3D
            if body and typeof(position_values) == TYPE_ARRAY and position_values.size() == 3:
                body.position = Vector3(
                    clamp(float(position_values[0]), ROAM_MIN_X, ROAM_MAX_X),
                    body.position.y,
                    clamp(float(position_values[2]), ROAM_MIN_Z, ROAM_MAX_Z)
                )
            companions[species] = data

    var last_save = int(saved_data.get("last_save", 0))
    if last_save > 0:
        var elapsed = max(0, int(Time.get_unix_time_from_system()) - last_save)
        var elapsed_hours = min(float(elapsed) / 3600.0, 168.0)
        for species in [SPECIES_PIG, SPECIES_SHARPEI]:
            var data = companions[species]
            data["hunger"] = clamp(float(data.get("hunger", 0.2)) + elapsed_hours * 0.006, 0.0, 0.88)
            data["energy"] = clamp(float(data.get("energy", 0.8)) + elapsed_hours * 0.018, 0.20, 1.0)
            companions[species] = data

func _vector_to_array(value: Vector3):
    return [value.x, value.y, value.z]

func _notification(what):
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_state()

func _exit_tree():
    _save_state()
