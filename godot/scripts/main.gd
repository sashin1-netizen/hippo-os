extends Node3D

const SAVE_PATH = "user://hippo_save.json"
const SAVE_VERSION = 2
const POND_POS = Vector3(3.7, 0.8, 2.5)
const MUD_POS = Vector3(-3.7, 0.8, 2.8)
const REST_POS = Vector3(-4.6, 0.8, -3.2)
const FEED_POS = Vector3(4.7, 0.8, -2.9)

var hippo
var hippo_visual
var camera
var head
var ear_l
var ear_r
var eye_l
var eye_r
var leg_fl
var leg_fr
var leg_rl
var leg_rr
var tail
var skin_material
var pink_material
var world_environment
var sun_light

var hunger = 0.18
var energy = 0.88
var affection = 0.52
var curiosity = 0.68
var cleanliness = 0.76
var bond = 0.35
var wetness = 0.0
var mud_coat = 0.0
var hippo_name = "Mochi"
var personality = {}
var settings = {
    "master_volume": 1.0,
    "animal_volume": 1.0,
    "ambience_volume": 0.75,
    "ui_volume": 0.85,
    "haptics": true,
    "show_stats": true,
    "reduced_motion": false,
    "camera_sensitivity": 1.0,
    "text_scale": 1.0,
    "day_night_mode": "auto"
}
var current_action = "idle"
var action_timer = 0.0
var wander_target = Vector3.ZERO
var autosave_timer = 0.0
var day_night_timer = 0.0
var pet_pulse = 0.0
var touch_on_hippo = false
var pet_distance = 0.0
var orbit_yaw = 0.0
var orbit_pitch = -0.12
var orbit_distance = 9.0
var interaction_counts = {"pet": 0, "feed": 0, "water": 0, "mud": 0}
var blink_timer = 2.0
var blink_pulse = 0.0
var ear_flick_timer = 1.2
var ear_flick_pulse = 0.0
var settings_open = false

var stats_label
var action_label
var stats_panel
var settings_panel
var name_edit
var master_slider
var animal_slider
var ambience_slider
var ui_slider
var haptics_toggle
var stats_toggle
var reduced_motion_toggle
var camera_slider
var text_scale_slider
var day_night_option
var reset_dialog

func _ready():
    randomize()
    _build_world()
    _build_hippo()
    _build_camera()
    _build_ui()
    _load_state()
    _ensure_personality()
    _apply_settings_to_ui()
    _apply_text_scale()
    _apply_day_night()
    _choose_action()
    _update_camera()
    _update_ui()

func _process(delta):
    _update_needs(delta)
    _update_brain(delta)
    _update_hippo(delta)
    _update_surface_state(delta)
    _update_camera()
    _update_ui()

    autosave_timer += delta
    if autosave_timer >= 20.0:
        autosave_timer = 0.0
        _save_state()

    day_night_timer += delta
    if day_night_timer >= 30.0:
        day_night_timer = 0.0
        _apply_day_night()

func _exit_tree():
    _save_state()

func _notification(what):
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_state()

func _build_world():
    world_environment = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.07, 0.12, 0.09)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.72, 0.60)
    environment.ambient_light_energy = 0.8
    world_environment.environment = environment
    add_child(world_environment)

    sun_light = DirectionalLight3D.new()
    sun_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
    sun_light.light_energy = 1.2
    sun_light.shadow_enabled = true
    add_child(sun_light)

    var ground_body = StaticBody3D.new()
    var ground_mesh = MeshInstance3D.new()
    var ground_box = BoxMesh.new()
    ground_box.size = Vector3(18.0, 0.4, 14.0)
    ground_mesh.mesh = ground_box
    ground_mesh.position.y = -0.2
    ground_mesh.material_override = _make_material(Color(0.22, 0.40, 0.22), 0.9)
    ground_body.add_child(ground_mesh)

    var ground_collision = CollisionShape3D.new()
    var ground_shape = BoxShape3D.new()
    ground_shape.size = Vector3(18.0, 0.4, 14.0)
    ground_collision.shape = ground_shape
    ground_collision.position.y = -0.2
    ground_body.add_child(ground_collision)
    add_child(ground_body)

    _add_zone_disc(POND_POS, Vector3(3.0, 0.06, 2.1), Color(0.10, 0.42, 0.56), 0.2)
    _add_zone_disc(MUD_POS, Vector3(2.0, 0.05, 1.5), Color(0.30, 0.20, 0.12), 1.0)
    _add_zone_disc(REST_POS, Vector3(1.8, 0.04, 1.5), Color(0.34, 0.45, 0.25), 0.95)

    var bowl = MeshInstance3D.new()
    var bowl_mesh = CylinderMesh.new()
    bowl_mesh.top_radius = 0.65
    bowl_mesh.bottom_radius = 0.52
    bowl_mesh.height = 0.18
    bowl.mesh = bowl_mesh
    bowl.position = Vector3(FEED_POS.x, 0.09, FEED_POS.z)
    bowl.material_override = _make_material(Color(0.45, 0.18, 0.10), 0.55)
    add_child(bowl)

    for i in range(20):
        var plant = MeshInstance3D.new()
        var stem = CylinderMesh.new()
        stem.top_radius = 0.04
        stem.bottom_radius = 0.10
        stem.height = randf_range(0.8, 1.8)
        plant.mesh = stem
        var angle = TAU * float(i) / 20.0
        plant.position = Vector3(cos(angle) * 7.2, stem.height * 0.5, sin(angle) * 5.6)
        plant.material_override = _make_material(Color(0.08, 0.28, 0.12), 0.9)
        add_child(plant)

    for i in range(8):
        var rock = MeshInstance3D.new()
        var rock_mesh = SphereMesh.new()
        rock_mesh.radius = 0.5
        rock_mesh.height = 1.0
        rock.mesh = rock_mesh
        rock.scale = Vector3(randf_range(0.45, 1.0), randf_range(0.28, 0.65), randf_range(0.4, 0.9))
        var rock_angle = TAU * float(i) / 8.0 + 0.25
        rock.position = Vector3(cos(rock_angle) * 6.3, rock.scale.y * 0.45, sin(rock_angle) * 4.8)
        rock.material_override = _make_material(Color(0.33, 0.34, 0.31), 0.95)
        add_child(rock)

func _add_zone_disc(zone_position, zone_scale, color, roughness):
    var zone = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 1.0
    zone.mesh = mesh
    zone.scale = zone_scale
    zone.position = Vector3(zone_position.x, zone_scale.y * 0.5, zone_position.z)
    zone.material_override = _make_material(color, roughness)
    add_child(zone)

func _build_hippo():
    hippo = CharacterBody3D.new()
    hippo.name = "BabyHippo"
    hippo.position = Vector3(0.0, 0.8, 0.0)
    hippo.collision_layer = 2
    hippo.collision_mask = 1
    add_child(hippo)

    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.7
    capsule.height = 1.8
    collision.shape = capsule
    collision.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    hippo.add_child(collision)

    hippo_visual = Node3D.new()
    hippo.add_child(hippo_visual)

    skin_material = _make_material(Color(0.45, 0.34, 0.42), 0.35)
    pink_material = _make_material(Color(0.68, 0.43, 0.52), 0.4)
    var eye_material = _make_material(Color(0.03, 0.02, 0.03), 0.15)
    var nostril_material = _make_material(Color(0.08, 0.035, 0.05), 0.25)

    _sphere_part("Body", Vector3(-0.2, 0.35, 0.0), Vector3(1.55, 0.9, 0.9), skin_material)
    _sphere_part("Belly", Vector3(-0.28, 0.08, 0.0), Vector3(1.30, 0.58, 0.76), pink_material)
    head = _sphere_part("Head", Vector3(1.1, 0.5, 0.0), Vector3(0.85, 0.78, 0.78), skin_material)
    _sphere_part("Snout", Vector3(1.72, 0.30, 0.0), Vector3(0.70, 0.48, 0.65), pink_material)
    _sphere_part("Chin", Vector3(1.60, 0.06, 0.0), Vector3(0.55, 0.20, 0.48), pink_material)
    ear_l = _sphere_part("EarL", Vector3(0.98, 1.02, -0.54), Vector3(0.20, 0.24, 0.16), skin_material)
    ear_r = _sphere_part("EarR", Vector3(0.98, 1.02, 0.54), Vector3(0.20, 0.24, 0.16), skin_material)
    eye_l = _sphere_part("EyeL", Vector3(1.52, 0.78, -0.48), Vector3(0.10, 0.10, 0.08), eye_material)
    eye_r = _sphere_part("EyeR", Vector3(1.52, 0.78, 0.48), Vector3(0.10, 0.10, 0.08), eye_material)
    _sphere_part("NostrilL", Vector3(2.02, 0.46, -0.25), Vector3(0.08, 0.045, 0.08), nostril_material)
    _sphere_part("NostrilR", Vector3(2.02, 0.46, 0.25), Vector3(0.08, 0.045, 0.08), nostril_material)

    leg_fl = _sphere_part("LegFL", Vector3(0.7, -0.22, -0.5), Vector3(0.28, 0.55, 0.28), skin_material)
    leg_fr = _sphere_part("LegFR", Vector3(0.7, -0.22, 0.5), Vector3(0.28, 0.55, 0.28), skin_material)
    leg_rl = _sphere_part("LegRL", Vector3(-0.9, -0.22, -0.5), Vector3(0.30, 0.58, 0.30), skin_material)
    leg_rr = _sphere_part("LegRR", Vector3(-0.9, -0.22, 0.5), Vector3(0.30, 0.58, 0.30), skin_material)
    tail = _sphere_part("Tail", Vector3(-1.70, 0.48, 0.0), Vector3(0.38, 0.12, 0.12), skin_material)

func _sphere_part(part_name, local_position, local_scale, material):
    var part = MeshInstance3D.new()
    part.name = part_name
    var sphere = SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    part.mesh = sphere
    part.position = local_position
    part.scale = local_scale
    part.material_override = material
    hippo_visual.add_child(part)
    return part

func _build_camera():
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 52.0
    add_child(camera)

func _build_ui():
    var ui = CanvasLayer.new()
    add_child(ui)

    stats_panel = ColorRect.new()
    stats_panel.color = Color(0.01, 0.02, 0.03, 0.78)
    stats_panel.position = Vector2(18, 18)
    stats_panel.size = Vector2(560, 132)
    ui.add_child(stats_panel)

    var title = Label.new()
    title.text = "HIPPO OS"
    title.position = Vector2(18, 10)
    title.add_theme_font_size_override("font_size", 30)
    stats_panel.add_child(title)

    stats_label = Label.new()
    stats_label.position = Vector2(18, 50)
    stats_label.add_theme_font_size_override("font_size", 18)
    stats_panel.add_child(stats_label)

    action_label = Label.new()
    action_label.position = Vector2(18, 88)
    action_label.add_theme_font_size_override("font_size", 16)
    stats_panel.add_child(action_label)

    var settings_button = Button.new()
    settings_button.text = "SETTINGS"
    settings_button.position = Vector2(1080, 20)
    settings_button.size = Vector2(175, 58)
    settings_button.add_theme_font_size_override("font_size", 18)
    settings_button.pressed.connect(_toggle_settings)
    ui.add_child(settings_button)

    var feed_button = Button.new()
    feed_button.text = "FEED"
    feed_button.position = Vector2(24, 622)
    feed_button.size = Vector2(180, 70)
    feed_button.add_theme_font_size_override("font_size", 24)
    feed_button.pressed.connect(_feed_hippo)
    ui.add_child(feed_button)

    var zoom_in = Button.new()
    zoom_in.text = "+"
    zoom_in.position = Vector2(1080, 610)
    zoom_in.size = Vector2(74, 74)
    zoom_in.add_theme_font_size_override("font_size", 30)
    zoom_in.pressed.connect(_zoom_camera.bind(-0.9))
    ui.add_child(zoom_in)

    var zoom_out = Button.new()
    zoom_out.text = "-"
    zoom_out.position = Vector2(1170, 610)
    zoom_out.size = Vector2(74, 74)
    zoom_out.add_theme_font_size_override("font_size", 30)
    zoom_out.pressed.connect(_zoom_camera.bind(0.9))
    ui.add_child(zoom_out)

    var help = Label.new()
    help.text = "Pet by dragging on %s  •  Drag habitat to orbit" % hippo_name
    help.position = Vector2(250, 650)
    help.add_theme_font_size_override("font_size", 18)
    ui.add_child(help)

    settings_panel = ColorRect.new()
    settings_panel.color = Color(0.015, 0.025, 0.03, 0.96)
    settings_panel.position = Vector2(710, 90)
    settings_panel.size = Vector2(545, 500)
    settings_panel.visible = false
    ui.add_child(settings_panel)

    var settings_title = Label.new()
    settings_title.text = "HIPPO SETTINGS"
    settings_title.position = Vector2(22, 16)
    settings_title.add_theme_font_size_override("font_size", 25)
    settings_panel.add_child(settings_title)

    var name_label = Label.new()
    name_label.text = "Name"
    name_label.position = Vector2(22, 62)
    name_label.add_theme_font_size_override("font_size", 17)
    settings_panel.add_child(name_label)

    name_edit = LineEdit.new()
    name_edit.position = Vector2(125, 56)
    name_edit.size = Vector2(230, 42)
    name_edit.max_length = 18
    settings_panel.add_child(name_edit)

    var rename_button = Button.new()
    rename_button.text = "SAVE NAME"
    rename_button.position = Vector2(368, 56)
    rename_button.size = Vector2(150, 42)
    rename_button.pressed.connect(_rename_hippo)
    settings_panel.add_child(rename_button)

    master_slider = _add_setting_slider("Master", 112, 0.0, 1.0, 0.05)
    animal_slider = _add_setting_slider("Animal", 158, 0.0, 1.0, 0.05)
    ambience_slider = _add_setting_slider("Ambience", 204, 0.0, 1.0, 0.05)
    ui_slider = _add_setting_slider("UI", 250, 0.0, 1.0, 0.05)
    camera_slider = _add_setting_slider("Camera", 296, 0.45, 1.8, 0.05)
    text_scale_slider = _add_setting_slider("Text size", 342, 0.85, 1.35, 0.05)

    master_slider.value_changed.connect(_on_master_volume_changed)
    animal_slider.value_changed.connect(_on_animal_volume_changed)
    ambience_slider.value_changed.connect(_on_ambience_volume_changed)
    ui_slider.value_changed.connect(_on_ui_volume_changed)
    camera_slider.value_changed.connect(_on_camera_sensitivity_changed)
    text_scale_slider.value_changed.connect(_on_text_scale_changed)

    haptics_toggle = CheckButton.new()
    haptics_toggle.text = "Haptics"
    haptics_toggle.position = Vector2(20, 392)
    haptics_toggle.toggled.connect(_on_haptics_toggled)
    settings_panel.add_child(haptics_toggle)

    stats_toggle = CheckButton.new()
    stats_toggle.text = "Show stats"
    stats_toggle.position = Vector2(155, 392)
    stats_toggle.toggled.connect(_on_stats_toggled)
    settings_panel.add_child(stats_toggle)

    reduced_motion_toggle = CheckButton.new()
    reduced_motion_toggle.text = "Reduced motion"
    reduced_motion_toggle.position = Vector2(310, 392)
    reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
    settings_panel.add_child(reduced_motion_toggle)

    var day_label = Label.new()
    day_label.text = "Lighting"
    day_label.position = Vector2(22, 442)
    day_label.add_theme_font_size_override("font_size", 16)
    settings_panel.add_child(day_label)

    day_night_option = OptionButton.new()
    day_night_option.position = Vector2(115, 432)
    day_night_option.size = Vector2(155, 40)
    day_night_option.add_item("Automatic")
    day_night_option.add_item("Day")
    day_night_option.add_item("Night")
    day_night_option.item_selected.connect(_on_day_night_selected)
    settings_panel.add_child(day_night_option)

    var camera_reset = Button.new()
    camera_reset.text = "RESET CAMERA"
    camera_reset.position = Vector2(282, 432)
    camera_reset.size = Vector2(120, 40)
    camera_reset.pressed.connect(_reset_camera)
    settings_panel.add_child(camera_reset)

    var reset_button = Button.new()
    reset_button.text = "RESET PET"
    reset_button.position = Vector2(413, 432)
    reset_button.size = Vector2(105, 40)
    reset_button.pressed.connect(_request_reset_pet)
    settings_panel.add_child(reset_button)

    reset_dialog = ConfirmationDialog.new()
    reset_dialog.title = "Reset hippo?"
    reset_dialog.dialog_text = "This clears the saved name, bond, needs and interaction history."
    reset_dialog.ok_button_text = "RESET"
    reset_dialog.confirmed.connect(_reset_pet_data)
    ui.add_child(reset_dialog)

func _add_setting_slider(label_text, y, min_value, max_value, step):
    var label = Label.new()
    label.text = label_text
    label.position = Vector2(22, y + 4)
    label.add_theme_font_size_override("font_size", 16)
    settings_panel.add_child(label)

    var slider = HSlider.new()
    slider.position = Vector2(125, y)
    slider.size = Vector2(390, 34)
    slider.min_value = min_value
    slider.max_value = max_value
    slider.step = step
    settings_panel.add_child(slider)
    return slider

func _ensure_personality():
    if personality.is_empty():
        personality = {
            "boldness": randf_range(0.30, 0.95),
            "playfulness": randf_range(0.35, 0.98),
            "sociability": randf_range(0.30, 0.95),
            "mud_love": randf_range(0.25, 0.95)
        }

func _update_needs(delta):
    var minutes = delta / 60.0
    hunger = clamp(hunger + 0.006 * minutes, 0.0, 1.0)
    energy = clamp(energy - 0.004 * minutes, 0.0, 1.0)
    curiosity = clamp(curiosity - 0.003 * minutes, 0.0, 1.0)
    cleanliness = clamp(cleanliness - 0.0016 * minutes, 0.0, 1.0)

func _update_brain(delta):
    action_timer -= delta
    if action_timer <= 0.0:
        _choose_action()

func _choose_action():
    _ensure_personality()
    action_timer = randf_range(3.0, 7.0)

    var boldness = float(personality.get("boldness", 0.6))
    var playfulness = float(personality.get("playfulness", 0.6))
    var sociability = float(personality.get("sociability", 0.6))
    var mud_love = float(personality.get("mud_love", 0.5))

    var scores = {
        "idle": 0.55 + randf() * 0.35,
        "wander": 0.35 + boldness * 0.65 + curiosity * 0.35 + randf() * 0.35,
        "approach": 0.25 + sociability * 0.75 + affection * 0.35 + bond * 0.25 + randf() * 0.25,
        "explore": 0.25 + boldness * 0.50 + (1.0 - curiosity) * 0.65 + randf() * 0.30,
        "play": 0.20 + playfulness * 0.85 + energy * 0.35 + randf() * 0.30,
        "drink": 0.22 + (1.0 - cleanliness) * 0.75 + randf() * 0.25,
        "mud": 0.12 + mud_love * 0.90 + energy * 0.20 + randf() * 0.25,
        "sleep": 0.08 + (1.0 - energy) * 2.0 + randf() * 0.20
    }

    if energy < 0.28:
        scores["sleep"] += 2.3
    if hunger > 0.74:
        scores["approach"] += 1.1
    if cleanliness < 0.40:
        scores["drink"] += 0.95
    if energy > 0.72 and playfulness > 0.70:
        scores["play"] += 0.45

    var best_action = "idle"
    var best_score = -999.0
    for action_name in scores:
        var score = float(scores[action_name])
        if score > best_score:
            best_score = score
            best_action = action_name

    current_action = best_action

    if current_action == "wander" or current_action == "explore" or current_action == "play":
        _new_wander_target()
    elif current_action == "drink":
        wander_target = POND_POS
    elif current_action == "mud":
        wander_target = MUD_POS
    elif current_action == "sleep":
        wander_target = REST_POS

func _new_wander_target():
    wander_target = Vector3(randf_range(-5.5, 5.5), hippo.position.y, randf_range(-4.3, 4.3))

func _update_hippo(delta):
    var direction = Vector3.ZERO
    var speed = 0.0
    var moving_to_zone = current_action == "drink" or current_action == "mud" or current_action == "sleep"

    if current_action == "approach":
        var target = camera.global_position
        target.y = hippo.global_position.y
        if hippo.global_position.distance_to(target) > 3.0:
            direction = (target - hippo.global_position).normalized()
            speed = 1.15
    elif current_action == "wander" or current_action == "explore" or current_action == "play":
        if hippo.global_position.distance_to(wander_target) < 0.5:
            _new_wander_target()
        direction = (wander_target - hippo.global_position).normalized()
        speed = 1.7 if current_action == "play" else 0.9
    elif moving_to_zone:
        var distance_to_zone = hippo.global_position.distance_to(wander_target)
        if distance_to_zone > 0.75:
            direction = (wander_target - hippo.global_position).normalized()
            speed = 0.9
        elif current_action == "sleep":
            energy = clamp(energy + delta * 0.018, 0.0, 1.0)
        elif current_action == "drink":
            cleanliness = clamp(cleanliness + delta * 0.045, 0.0, 1.0)
            wetness = clamp(wetness + delta * 0.40, 0.0, 1.0)
            mud_coat = clamp(mud_coat - delta * 0.32, 0.0, 1.0)
            curiosity = clamp(curiosity + delta * 0.01, 0.0, 1.0)
        elif current_action == "mud":
            cleanliness = clamp(cleanliness - delta * 0.025, 0.0, 1.0)
            mud_coat = clamp(mud_coat + delta * 0.28, 0.0, 1.0)
            curiosity = clamp(curiosity + delta * 0.018, 0.0, 1.0)

    hippo.velocity = Vector3(direction.x * speed, -0.2, direction.z * speed)
    hippo.move_and_slide()

    if direction.length_squared() > 0.01:
        var target_point = hippo.global_position + direction
        hippo.look_at(target_point, Vector3.UP)
        hippo.rotation.x = 0.0
        hippo.rotation.z = 0.0

    var now = Time.get_ticks_msec() / 1000.0
    var motion_scale = 0.35 if bool(settings.get("reduced_motion", false)) else 1.0
    var sleep_factor = 0.45 if current_action == "sleep" and direction.length_squared() < 0.01 else 1.0
    var breathe = sin(now * (1.45 if current_action == "sleep" else 2.2)) * 0.025 * motion_scale
    hippo_visual.scale = Vector3(1.0 + breathe, sleep_factor + breathe * 0.5, 1.0 + breathe)

    var moving = direction.length_squared() > 0.01
    var stride = sin(now * max(speed, 0.7) * 7.0) * 0.30 * motion_scale if moving else 0.0
    leg_fl.rotation.z = stride
    leg_rr.rotation.z = stride
    leg_fr.rotation.z = -stride
    leg_rl.rotation.z = -stride
    hippo_visual.position.y = abs(sin(now * max(speed, 0.7) * 7.0)) * 0.055 * motion_scale if moving else 0.0
    tail.rotation.y = sin(now * 4.0) * 0.18 * motion_scale if current_action == "play" else sin(now * 1.2) * 0.05 * motion_scale

    blink_timer -= delta
    if blink_timer <= 0.0:
        blink_timer = randf_range(2.4, 6.2)
        blink_pulse = 0.18
    if blink_pulse > 0.0:
        blink_pulse = max(0.0, blink_pulse - delta)
        var eye_height = 0.018 if blink_pulse > 0.07 else 0.10
        eye_l.scale.y = eye_height
        eye_r.scale.y = eye_height
    else:
        eye_l.scale.y = 0.10
        eye_r.scale.y = 0.10

    ear_flick_timer -= delta
    if ear_flick_timer <= 0.0:
        ear_flick_timer = randf_range(2.0, 7.5)
        ear_flick_pulse = 0.30
    if ear_flick_pulse > 0.0:
        ear_flick_pulse = max(0.0, ear_flick_pulse - delta)
        var flick = sin(now * 22.0) * 0.24 * motion_scale
        ear_l.rotation.z = flick
        ear_r.rotation.z = -flick
    else:
        ear_l.rotation.z = sin(now * 0.7) * 0.025 * motion_scale
        ear_r.rotation.z = -sin(now * 0.7) * 0.025 * motion_scale

    if pet_pulse > 0.0:
        pet_pulse = max(0.0, pet_pulse - delta)
        head.rotation.z = sin(now * 10.0) * 0.12 * pet_pulse * motion_scale
    else:
        head.rotation.z = sin(now * 0.55) * 0.025 * motion_scale

func _update_surface_state(delta):
    wetness = max(0.0, wetness - delta * 0.012)
    mud_coat = max(0.0, mud_coat - delta * 0.0025)
    var base_skin = Color(0.45, 0.34, 0.42)
    var wet_skin = Color(0.29, 0.25, 0.32)
    var muddy_skin = Color(0.31, 0.24, 0.17)
    var skin_color = base_skin.lerp(wet_skin, wetness * 0.45)
    skin_color = skin_color.lerp(muddy_skin, mud_coat * 0.62)
    skin_material.albedo_color = skin_color
    skin_material.roughness = clamp(0.40 - wetness * 0.24 + mud_coat * 0.30, 0.12, 0.95)

func _update_camera():
    var pivot = Vector3(0.0, 1.0, 0.0)
    var horizontal = cos(orbit_pitch) * orbit_distance
    camera.position = pivot + Vector3(
        sin(orbit_yaw) * horizontal,
        -sin(orbit_pitch) * orbit_distance + 1.0,
        cos(orbit_yaw) * horizontal
    )
    camera.look_at(pivot, Vector3.UP)

func _zoom_camera(amount):
    orbit_distance = clamp(orbit_distance + float(amount), 5.4, 12.5)
    _haptic(18)

func _reset_camera():
    orbit_yaw = 0.0
    orbit_pitch = -0.12
    orbit_distance = 9.0
    _haptic(18)

func _update_ui():
    if not stats_label:
        return
    stats_panel.visible = bool(settings.get("show_stats", true))
    stats_label.text = "%s  Bond %d%%  Hunger %d%%  Energy %d%%  Clean %d%%" % [
        hippo_name,
        int(bond * 100.0),
        int(hunger * 100.0),
        int(energy * 100.0),
        int(cleanliness * 100.0)
    ]
    action_label.text = "%s • %s" % [_mood_name(), _action_description()]

func _mood_name():
    if current_action == "sleep":
        return "Sleepy"
    if hunger > 0.82:
        return "Hungry"
    if affection > 0.72 and bond > 0.52:
        return "Content"
    if curiosity < 0.28 and energy > 0.55:
        return "Restless"
    if mud_coat > 0.45:
        return "Muddy & pleased"
    return "Curious"

func _action_description():
    match current_action:
        "wander":
            return "wandering"
        "approach":
            return "coming to see you"
        "explore":
            return "investigating the sanctuary"
        "play":
            return "doing zoomies"
        "drink":
            return "playing in the water"
        "mud":
            return "rolling in mud"
        "sleep":
            return "resting"
        _:
            return "watching the world"

func _feed_hippo():
    hunger = clamp(hunger - 0.30, 0.0, 1.0)
    affection = clamp(affection + 0.03, 0.0, 1.0)
    bond = clamp(bond + 0.008, 0.0, 1.0)
    interaction_counts["feed"] = int(interaction_counts.get("feed", 0)) + 1
    current_action = "approach"
    action_timer = 3.0
    _haptic(28)
    _save_state()

func _pet(strength, region = "body"):
    var region_bonus = 1.15 if region == "head" else 1.0
    affection = clamp(affection + 0.02 * strength * region_bonus, 0.0, 1.0)
    curiosity = clamp(curiosity + 0.006 * strength, 0.0, 1.0)
    bond = clamp(bond + 0.006 * strength * region_bonus, 0.0, 1.0)
    interaction_counts["pet"] = int(interaction_counts.get("pet", 0)) + 1
    pet_pulse = 1.0
    current_action = "idle"
    action_timer = max(action_timer, 1.1)
    _haptic(14)

func _unhandled_input(event):
    if event.is_action_pressed("ui_cancel"):
        if settings_open:
            _set_settings_open(false)
        else:
            _save_state()
            get_tree().quit()
        get_viewport().set_input_as_handled()
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            pet_distance = 0.0
            touch_on_hippo = _screen_hits_hippo(event.position)
        else:
            if touch_on_hippo and pet_distance < 16.0:
                _pet(0.35, _touch_region(event.position))
            touch_on_hippo = false
            pet_distance = 0.0
    elif event is InputEventScreenDrag:
        var drag_delta = event.relative
        if touch_on_hippo:
            if _screen_hits_hippo(event.position):
                pet_distance += drag_delta.length()
                if pet_distance >= 42.0:
                    _pet(clamp(pet_distance / 120.0, 0.4, 1.5), _touch_region(event.position))
                    pet_distance = 0.0
        else:
            var sensitivity = float(settings.get("camera_sensitivity", 1.0))
            orbit_yaw -= drag_delta.x * 0.006 * sensitivity
            orbit_pitch = clamp(orbit_pitch - drag_delta.y * 0.004 * sensitivity, -0.55, 0.20)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _zoom_camera(-0.6)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _zoom_camera(0.6)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                pet_distance = 0.0
                touch_on_hippo = _screen_hits_hippo(event.position)
            else:
                if touch_on_hippo and pet_distance < 16.0:
                    _pet(0.35, _touch_region(event.position))
                touch_on_hippo = false
                pet_distance = 0.0
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_delta = event.relative
        if touch_on_hippo:
            pet_distance += mouse_delta.length()
            if pet_distance >= 42.0:
                _pet(clamp(pet_distance / 120.0, 0.4, 1.5), _touch_region(event.position))
                pet_distance = 0.0
        else:
            var mouse_sensitivity = float(settings.get("camera_sensitivity", 1.0))
            orbit_yaw -= mouse_delta.x * 0.006 * mouse_sensitivity
            orbit_pitch = clamp(orbit_pitch - mouse_delta.y * 0.004 * mouse_sensitivity, -0.55, 0.20)

func _screen_hits_hippo(screen_pos):
    var origin = camera.project_ray_origin(screen_pos)
    var direction = camera.project_ray_normal(screen_pos)
    var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
    query.collision_mask = 2
    var result = get_world_3d().direct_space_state.intersect_ray(query)
    return not result.is_empty() and result.get("collider") == hippo

func _touch_region(screen_pos):
    if not head or not camera:
        return "body"
    var head_screen = camera.unproject_position(head.global_position)
    return "head" if head_screen.distance_to(screen_pos) < 115.0 else "body"

func _toggle_settings():
    _set_settings_open(not settings_open)

func _set_settings_open(open):
    settings_open = bool(open)
    settings_panel.visible = settings_open
    if settings_open:
        name_edit.text = hippo_name
        _apply_settings_to_ui()
    else:
        _save_state()
    _haptic(18)

func _rename_hippo():
    var candidate = name_edit.text.strip_edges()
    if candidate.is_empty():
        return
    hippo_name = candidate.left(18)
    _haptic(26)
    _save_state()
    _update_ui()

func _request_reset_pet():
    reset_dialog.popup_centered(Vector2i(540, 250))

func _reset_pet_data():
    hunger = 0.18
    energy = 0.88
    affection = 0.52
    curiosity = 0.68
    cleanliness = 0.76
    bond = 0.35
    wetness = 0.0
    mud_coat = 0.0
    hippo_name = "Mochi"
    personality = {}
    interaction_counts = {"pet": 0, "feed": 0, "water": 0, "mud": 0}
    _ensure_personality()
    name_edit.text = hippo_name
    _save_state()
    _haptic(45)
    _choose_action()
    _update_ui()

func _on_master_volume_changed(value):
    settings["master_volume"] = float(value)

func _on_animal_volume_changed(value):
    settings["animal_volume"] = float(value)

func _on_ambience_volume_changed(value):
    settings["ambience_volume"] = float(value)

func _on_ui_volume_changed(value):
    settings["ui_volume"] = float(value)

func _on_haptics_toggled(enabled):
    settings["haptics"] = bool(enabled)
    if enabled:
        _haptic(22)

func _on_stats_toggled(enabled):
    settings["show_stats"] = bool(enabled)
    _update_ui()

func _on_reduced_motion_toggled(enabled):
    settings["reduced_motion"] = bool(enabled)

func _on_camera_sensitivity_changed(value):
    settings["camera_sensitivity"] = float(value)

func _on_text_scale_changed(value):
    settings["text_scale"] = float(value)
    _apply_text_scale()

func _on_day_night_selected(index):
    var modes = ["auto", "day", "night"]
    settings["day_night_mode"] = modes[clamp(int(index), 0, modes.size() - 1)]
    _apply_day_night()

func _apply_settings_to_ui():
    if not master_slider:
        return
    master_slider.value = float(settings.get("master_volume", 1.0))
    animal_slider.value = float(settings.get("animal_volume", 1.0))
    ambience_slider.value = float(settings.get("ambience_volume", 0.75))
    ui_slider.value = float(settings.get("ui_volume", 0.85))
    haptics_toggle.button_pressed = bool(settings.get("haptics", true))
    stats_toggle.button_pressed = bool(settings.get("show_stats", true))
    reduced_motion_toggle.button_pressed = bool(settings.get("reduced_motion", false))
    camera_slider.value = float(settings.get("camera_sensitivity", 1.0))
    text_scale_slider.value = float(settings.get("text_scale", 1.0))
    var mode = str(settings.get("day_night_mode", "auto"))
    if mode == "day":
        day_night_option.select(1)
    elif mode == "night":
        day_night_option.select(2)
    else:
        day_night_option.select(0)
    name_edit.text = hippo_name

func _apply_text_scale():
    var scale = float(settings.get("text_scale", 1.0))
    if stats_label:
        stats_label.add_theme_font_size_override("font_size", int(18.0 * scale))
    if action_label:
        action_label.add_theme_font_size_override("font_size", int(16.0 * scale))

func _apply_day_night():
    if not world_environment or not world_environment.environment or not sun_light:
        return
    var mode = str(settings.get("day_night_mode", "auto"))
    var daylight = 1.0
    if mode == "night":
        daylight = 0.0
    elif mode == "auto":
        var time = Time.get_time_dict_from_system()
        var hour = float(time.get("hour", 12))
        var daylight_angle = (hour - 6.0) / 12.0 * PI
        daylight = clamp(sin(daylight_angle), 0.0, 1.0)

    var environment = world_environment.environment
    environment.background_color = Color(0.025, 0.045, 0.085).lerp(Color(0.08, 0.15, 0.10), daylight)
    environment.ambient_light_color = Color(0.20, 0.28, 0.45).lerp(Color(0.58, 0.74, 0.60), daylight)
    environment.ambient_light_energy = lerp(0.42, 0.86, daylight)
    sun_light.light_energy = lerp(0.18, 1.25, daylight)

func _haptic(duration_ms):
    if bool(settings.get("haptics", true)):
        Input.vibrate_handheld(int(duration_ms))

func _save_state():
    var data = {
        "save_version": SAVE_VERSION,
        "hippo_name": hippo_name,
        "hunger": hunger,
        "energy": energy,
        "affection": affection,
        "curiosity": curiosity,
        "cleanliness": cleanliness,
        "bond": bond,
        "wetness": wetness,
        "mud_coat": mud_coat,
        "personality": personality,
        "settings": settings,
        "interaction_counts": interaction_counts,
        "last_save": int(Time.get_unix_time_from_system())
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_state():
    if not FileAccess.file_exists(SAVE_PATH):
        _ensure_personality()
        _save_state()
        return

    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return

    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        _ensure_personality()
        _save_state()
        return

    hippo_name = str(parsed.get("hippo_name", hippo_name))
    hunger = clamp(float(parsed.get("hunger", hunger)), 0.0, 1.0)
    energy = clamp(float(parsed.get("energy", energy)), 0.0, 1.0)
    affection = clamp(float(parsed.get("affection", affection)), 0.0, 1.0)
    curiosity = clamp(float(parsed.get("curiosity", curiosity)), 0.0, 1.0)
    cleanliness = clamp(float(parsed.get("cleanliness", cleanliness)), 0.0, 1.0)
    bond = clamp(float(parsed.get("bond", bond)), 0.0, 1.0)
    wetness = clamp(float(parsed.get("wetness", wetness)), 0.0, 1.0)
    mud_coat = clamp(float(parsed.get("mud_coat", mud_coat)), 0.0, 1.0)
    personality = parsed.get("personality", personality)
    interaction_counts = parsed.get("interaction_counts", interaction_counts)

    var loaded_settings = parsed.get("settings", {})
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        for key in loaded_settings:
            if settings.has(key):
                settings[key] = loaded_settings[key]

    _ensure_personality()

    var last_save = int(parsed.get("last_save", 0))
    if last_save > 0:
        var elapsed_seconds = max(0, int(Time.get_unix_time_from_system()) - last_save)
        var elapsed_minutes = min(float(elapsed_seconds) / 60.0, 10080.0)
        hunger = clamp(hunger + elapsed_minutes * 0.0022, 0.0, 0.92)
        energy = clamp(energy + elapsed_minutes * 0.0018, 0.18, 1.0)
        cleanliness = clamp(cleanliness - elapsed_minutes * 0.00045, 0.25, 1.0)
        curiosity = clamp(curiosity + min(elapsed_minutes * 0.0006, 0.20), 0.0, 1.0)
        wetness = 0.0

func _make_material(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
