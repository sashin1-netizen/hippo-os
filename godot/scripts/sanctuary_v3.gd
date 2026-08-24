extends Node3D

const SpeciesProfiles = preload("res://scripts/species_profiles.gd")
const AnimalActor = preload("res://scripts/animal_actor.gd")
const SanctuaryState = preload("res://scripts/sanctuary_state.gd")

const SAVE_PATH = "user://sanctuary_save.json"

var sanctuary
var animals = {}
var selected_id = "hippo_01"
var camera
var environment
var sun
var ui_layer
var info_panel
var animal_name_label
var animal_species_label
var animal_status_label
var animal_stats_label
var settings_overlay
var journal_overlay
var rename_edit
var master_slider
var animal_slider
var ambience_slider
var ui_slider
var stats_toggle
var haptics_toggle
var reduced_motion_toggle
var autosave_timer = 0.0
var orbit_yaw = -0.18
var orbit_pitch = -0.15
var orbit_distance = 7.5
var camera_dragging = false
var app_ready = false

func _ready():
    randomize()
    sanctuary = SanctuaryState.new()
    _load_sanctuary()
    _ensure_audio_buses()
    _build_world()
    _spawn_animals()
    _build_camera()
    _build_ui()
    _apply_settings()
    _select_animal(selected_id)
    app_ready = true

func _process(delta):
    if not app_ready:
        return
    autosave_timer += delta
    if autosave_timer >= 15.0:
        autosave_timer = 0.0
        _save_sanctuary()
    _update_camera(delta)
    _update_day_night()
    _refresh_info()

func _notification(what):
    if what == NOTIFICATION_APPLICATION_PAUSED:
        _save_sanctuary()
    elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_sanctuary()
    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_sanctuary()
        get_tree().quit()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if settings_overlay != null and settings_overlay.visible:
            settings_overlay.visible = false
        elif journal_overlay != null and journal_overlay.visible:
            journal_overlay.visible = false
        else:
            _save_sanctuary()
            get_tree().quit()

func _build_world():
    var world_environment = WorldEnvironment.new()
    environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.055, 0.045)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.46, 0.58, 0.50)
    environment.ambient_light_energy = 0.82
    world_environment.environment = environment
    add_child(world_environment)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
    sun.light_energy = 1.40
    sun.light_color = Color(1.0, 0.90, 0.76)
    sun.shadow_enabled = true
    add_child(sun)

    var fill = OmniLight3D.new()
    fill.position = Vector3(0.0, 6.0, 0.0)
    fill.omni_range = 24.0
    fill.light_energy = 0.55
    fill.light_color = Color(0.52, 0.68, 0.60)
    add_child(fill)

    _ground_box(Vector3(0.0, -0.25, 0.0), Vector3(28.0, 0.5, 18.0), Color(0.11, 0.24, 0.12))

    _zone_pad(Vector3(0.0, 0.01, 1.0), Vector3(8.8, 0.10, 7.4), Color(0.12, 0.30, 0.17))
    _zone_pad(Vector3(-8.0, 0.01, -2.2), Vector3(6.7, 0.10, 6.0), Color(0.26, 0.22, 0.13))
    _zone_pad(Vector3(8.0, 0.01, -2.2), Vector3(6.7, 0.10, 6.0), Color(0.19, 0.27, 0.16))

    _pond(Vector3(2.0, 0.06, 2.1), Vector3(1.15, 1.0, 0.72))
    _mud_patch(Vector3(-2.4, 0.06, 2.1), Vector3(0.95, 1.0, 0.72))
    _mud_patch(Vector3(-8.0, 0.06, -1.2), Vector3(0.78, 1.0, 0.55))

    for i in range(36):
        var angle = TAU * float(i) / 36.0
        var x = cos(angle) * randf_range(10.0, 13.2)
        var z = sin(angle) * randf_range(6.5, 8.0)
        _plant(Vector3(x, 0.0, z), randf_range(0.8, 2.5))

    for i in range(10):
        _rock(Vector3(randf_range(-12.0, 12.0), 0.25, randf_range(-7.0, 7.0)), randf_range(0.5, 1.2))

    _zone_sign("PYGMY HIPPO", Vector3(0.0, 0.04, -2.1))
    _zone_sign("PIG PADDOCK", Vector3(-8.0, 0.04, -5.0))
    _zone_sign("SHAR-PEI YARD", Vector3(8.0, 0.04, -5.0))

func _ground_box(pos, size, color):
    var body = StaticBody3D.new()
    var mesh_instance = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    mesh_instance.material_override = _material(color, 0.96)
    body.add_child(mesh_instance)
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    body.position = pos
    add_child(body)

func _zone_pad(pos, size, color):
    var mesh_instance = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    mesh_instance.position = pos
    mesh_instance.material_override = _material(color, 0.94)
    add_child(mesh_instance)

func _pond(pos, scale_value):
    var mesh_instance = MeshInstance3D.new()
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 2.45
    cylinder.bottom_radius = 2.45
    cylinder.height = 0.08
    mesh_instance.mesh = cylinder
    mesh_instance.position = pos
    mesh_instance.scale = scale_value
    var water = _material(Color(0.05, 0.34, 0.45), 0.13)
    water.metallic = 0.08
    mesh_instance.material_override = water
    add_child(mesh_instance)

func _mud_patch(pos, scale_value):
    var mesh_instance = MeshInstance3D.new()
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 1.65
    cylinder.bottom_radius = 1.65
    cylinder.height = 0.07
    mesh_instance.mesh = cylinder
    mesh_instance.position = pos
    mesh_instance.scale = scale_value
    mesh_instance.material_override = _material(Color(0.26, 0.16, 0.09), 1.0)
    add_child(mesh_instance)

func _plant(pos, height_value):
    var plant = MeshInstance3D.new()
    var stem = CylinderMesh.new()
    stem.top_radius = 0.035
    stem.bottom_radius = 0.12
    stem.height = height_value
    plant.mesh = stem
    plant.position = pos + Vector3(0.0, height_value * 0.5, 0.0)
    plant.material_override = _material(Color(0.035, randf_range(0.20, 0.34), 0.09), 0.96)
    add_child(plant)

func _rock(pos, scale_value):
    var rock = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 0.9
    rock.mesh = sphere
    rock.position = pos
    rock.scale = Vector3(scale_value, scale_value * 0.65, scale_value * 1.15)
    rock.material_override = _material(Color(0.25, 0.27, 0.24), 0.98)
    add_child(rock)

func _zone_sign(text_value, pos):
    var label = Label3D.new()
    label.text = text_value
    label.position = pos + Vector3(0.0, 0.6, 0.0)
    label.font_size = 28
    label.modulate = Color(0.82, 0.88, 0.82)
    label.outline_size = 8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

func _material(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _spawn_animals():
    var offline_minutes = sanctuary.offline_minutes()

    _spawn_animal("hippo_01", SpeciesProfiles.PYGMY_HIPPO, Vector3(0.0, 0.78, 1.0), Vector2(3.3, 2.6), offline_minutes)
    _spawn_animal("pig_01", SpeciesProfiles.PIG, Vector3(-8.0, 0.55, -2.2), Vector2(2.7, 2.2), offline_minutes)
    _spawn_animal("sharpei_01", SpeciesProfiles.SHAR_PEI, Vector3(8.0, 0.62, -2.2), Vector2(2.7, 2.2), offline_minutes)

func _spawn_animal(animal_id, species_id, home, zone_radius, offline_minutes):
    var saved = sanctuary.animal(animal_id)
    var saved_name = SpeciesProfiles.default_name(species_id)
    if typeof(saved) == TYPE_DICTIONARY and not saved.is_empty():
        saved_name = str(saved.get("animal_name", saved_name))

    var actor = AnimalActor.new()
    actor.setup(animal_id, species_id, saved_name, home, zone_radius, saved)
    if typeof(saved) == TYPE_DICTIONARY and saved.has("brain_memory"):
        actor.load_brain_memory(saved.get("brain_memory", {}))
    if offline_minutes > 0.0:
        actor.offline_simulate(offline_minutes)
    animals[animal_id] = actor
    add_child(actor)

func _build_camera():
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 48.0
    add_child(camera)

func _build_ui():
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    info_panel = ColorRect.new()
    info_panel.color = Color(0.008, 0.014, 0.012, 0.88)
    info_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    info_panel.offset_left = 18
    info_panel.offset_top = 16
    info_panel.offset_right = -18
    info_panel.offset_bottom = 150
    ui_layer.add_child(info_panel)

    var title = Label.new()
    title.text = "HIPPO OS  •  PRIVATE SANCTUARY"
    title.position = Vector2(18, 10)
    title.add_theme_font_size_override("font_size", 25)
    info_panel.add_child(title)

    animal_name_label = Label.new()
    animal_name_label.position = Vector2(18, 45)
    animal_name_label.add_theme_font_size_override("font_size", 22)
    info_panel.add_child(animal_name_label)

    animal_species_label = Label.new()
    animal_species_label.position = Vector2(170, 49)
    animal_species_label.add_theme_font_size_override("font_size", 16)
    info_panel.add_child(animal_species_label)

    animal_status_label = Label.new()
    animal_status_label.position = Vector2(18, 80)
    animal_status_label.add_theme_font_size_override("font_size", 17)
    info_panel.add_child(animal_status_label)

    animal_stats_label = Label.new()
    animal_stats_label.position = Vector2(18, 108)
    animal_stats_label.add_theme_font_size_override("font_size", 15)
    info_panel.add_child(animal_stats_label)

    var settings_button = Button.new()
    settings_button.text = "SETTINGS"
    settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    settings_button.offset_left = -170
    settings_button.offset_top = 30
    settings_button.offset_right = -20
    settings_button.offset_bottom = 88
    settings_button.pressed.connect(_toggle_settings)
    info_panel.add_child(settings_button)

    var selector = HBoxContainer.new()
    selector.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    selector.offset_left = 22
    selector.offset_top = -166
    selector.offset_right = 600
    selector.offset_bottom = -102
    selector.add_theme_constant_override("separation", 10)
    ui_layer.add_child(selector)
    _animal_button(selector, "MOCHI", "hippo_01")
    _animal_button(selector, "TRUFFLE", "pig_01")
    _animal_button(selector, "BAO", "sharpei_01")

    var actions = HBoxContainer.new()
    actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    actions.offset_left = 22
    actions.offset_top = -90
    actions.offset_right = -22
    actions.offset_bottom = -20
    actions.add_theme_constant_override("separation", 10)
    ui_layer.add_child(actions)

    _action_button(actions, "FEED", _feed_selected)
    _action_button(actions, "PET", _pet_selected)
    _action_button(actions, "JOURNAL", _toggle_journal)
    _action_button(actions, "CAMERA RESET", _reset_camera)

    _build_settings_overlay()
    _build_journal_overlay()

func _animal_button(parent, text_value, id_value):
    var button = Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(145, 58)
    button.pressed.connect(func(): _select_animal(id_value))
    parent.add_child(button)

func _action_button(parent, text_value, callback):
    var button = Button.new()
    button.text = text_value
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(180, 66)
    button.add_theme_font_size_override("font_size", 18)
    button.pressed.connect(callback)
    parent.add_child(button)

func _build_settings_overlay():
    settings_overlay = ColorRect.new()
    settings_overlay.color = Color(0.01, 0.018, 0.016, 0.97)
    settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    settings_overlay.visible = false
    ui_layer.add_child(settings_overlay)

    var card = VBoxContainer.new()
    card.set_anchors_preset(Control.PRESET_CENTER)
    card.offset_left = -300
    card.offset_top = -300
    card.offset_right = 300
    card.offset_bottom = 300
    card.add_theme_constant_override("separation", 12)
    settings_overlay.add_child(card)

    var title = Label.new()
    title.text = "SANCTUARY SETTINGS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    card.add_child(title)

    var rename_label = Label.new()
    rename_label.text = "Selected animal name"
    card.add_child(rename_label)
    rename_edit = LineEdit.new()
    card.add_child(rename_edit)
    var rename_button = Button.new()
    rename_button.text = "SAVE NAME"
    rename_button.pressed.connect(_rename_selected)
    card.add_child(rename_button)

    master_slider = _settings_slider(card, "Master volume", float(sanctuary.settings.get("master_volume", 1.0)))
    master_slider.value_changed.connect(_on_master_volume)
    animal_slider = _settings_slider(card, "Animal sounds", float(sanctuary.settings.get("animal_volume", 1.0)))
    animal_slider.value_changed.connect(_on_animal_volume)
    ambience_slider = _settings_slider(card, "Sanctuary ambience", float(sanctuary.settings.get("ambience_volume", 0.85)))
    ambience_slider.value_changed.connect(_on_ambience_volume)
    ui_slider = _settings_slider(card, "UI sounds", float(sanctuary.settings.get("ui_volume", 0.85)))
    ui_slider.value_changed.connect(_on_ui_volume)

    haptics_toggle = CheckButton.new()
    haptics_toggle.text = "Haptics"
    haptics_toggle.button_pressed = bool(sanctuary.settings.get("haptics", true))
    haptics_toggle.toggled.connect(_on_haptics)
    card.add_child(haptics_toggle)

    stats_toggle = CheckButton.new()
    stats_toggle.text = "Show animal stats"
    stats_toggle.button_pressed = bool(sanctuary.settings.get("show_stats", true))
    stats_toggle.toggled.connect(_on_show_stats)
    card.add_child(stats_toggle)

    reduced_motion_toggle = CheckButton.new()
    reduced_motion_toggle.text = "Reduced motion"
    reduced_motion_toggle.button_pressed = bool(sanctuary.settings.get("reduced_motion", false))
    reduced_motion_toggle.toggled.connect(_on_reduced_motion)
    card.add_child(reduced_motion_toggle)

    var about = Label.new()
    about.text = "Hippo OS • development build\nPrivate offline sanctuary • no ads • no account required"
    about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(about)

    var close = Button.new()
    close.text = "DONE"
    close.custom_minimum_size = Vector2(0, 58)
    close.pressed.connect(_toggle_settings)
    card.add_child(close)

func _settings_slider(parent, label_text, current_value):
    var row = HBoxContainer.new()
    var label = Label.new()
    label.text = label_text
    label.custom_minimum_size = Vector2(200, 0)
    row.add_child(label)
    var slider = HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.05
    slider.value = current_value
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    parent.add_child(row)
    return slider

func _build_journal_overlay():
    journal_overlay = ColorRect.new()
    journal_overlay.color = Color(0.012, 0.020, 0.017, 0.97)
    journal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    journal_overlay.visible = false
    ui_layer.add_child(journal_overlay)

    var title = Label.new()
    title.text = "SANCTUARY JOURNAL"
    title.position = Vector2(50, 45)
    title.add_theme_font_size_override("font_size", 32)
    journal_overlay.add_child(title)

    var journal_text = Label.new()
    journal_text.name = "JournalText"
    journal_text.position = Vector2(50, 110)
    journal_text.size = Vector2(1000, 430)
    journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    journal_text.add_theme_font_size_override("font_size", 20)
    journal_overlay.add_child(journal_text)

    var close = Button.new()
    close.text = "BACK TO SANCTUARY"
    close.position = Vector2(50, 610)
    close.size = Vector2(300, 65)
    close.pressed.connect(_toggle_journal)
    journal_overlay.add_child(close)

func _select_animal(id_value):
    if not animals.has(id_value):
        return
    selected_id = id_value
    for id_key in animals.keys():
        animals[id_key].set_selected(id_key == selected_id)
    var actor = animals[selected_id]
    if rename_edit != null:
        rename_edit.text = actor.display_name()
    orbit_yaw = -0.18
    orbit_pitch = -0.15
    orbit_distance = 7.5 if actor.species_id == SpeciesProfiles.PYGMY_HIPPO else 6.3
    _refresh_info()

func _feed_selected():
    var actor = _selected_actor()
    if actor == null:
        return
    actor.feed()
    sanctuary.add_journal_event("feeding", selected_id, "%s was fed." % actor.display_name(), 0.35)
    _haptic(45)
    _save_sanctuary()

func _pet_selected():
    var actor = _selected_actor()
    if actor == null:
        return
    var quality = actor.pet("forehead")
    if quality >= 0.22:
        sanctuary.add_journal_event("interaction", selected_id, "%s accepted a gentle forehead rub." % actor.display_name(), 0.42)
    else:
        sanctuary.add_journal_event("boundary", selected_id, "%s chose to move away from interaction." % actor.display_name(), 0.48)
    _haptic(22)
    _save_sanctuary()

func _selected_actor():
    return animals.get(selected_id, null)

func _refresh_info():
    var actor = _selected_actor()
    if actor == null or actor.state == null:
        return
    animal_name_label.text = actor.display_name()
    animal_species_label.text = actor.species_display_name()
    animal_status_label.text = actor.status_line()
    var needs = actor.state.needs
    animal_stats_label.visible = bool(sanctuary.settings.get("show_stats", true))
    animal_stats_label.text = "Bond %d%%   Hunger %d%%   Energy %d%%   Security %d%%" % [
        int(actor.state.bond * 100.0),
        int(float(needs.get("hunger", 0.0)) * 100.0),
        int(float(needs.get("energy", 0.0)) * 100.0),
        int(float(actor.state.emotion.get("security", 0.0)) * 100.0)
    ]

func _update_camera(delta):
    var actor = _selected_actor()
    if actor == null or camera == null:
        return
    var pivot = actor.global_position + Vector3(0.0, 0.75, 0.0)
    var horizontal = cos(orbit_pitch) * orbit_distance
    var desired = pivot + Vector3(sin(orbit_yaw) * horizontal, -sin(orbit_pitch) * orbit_distance + 1.2, cos(orbit_yaw) * horizontal)
    var smoothing = 2.2 if bool(sanctuary.settings.get("reduced_motion", false)) else 4.2
    camera.global_position = camera.global_position.lerp(desired, min(delta * smoothing, 1.0))
    camera.look_at(pivot, Vector3.UP)

func _input(event):
    if settings_overlay != null and settings_overlay.visible:
        return
    if journal_overlay != null and journal_overlay.visible:
        return

    var sensitivity = float(sanctuary.settings.get("camera_sensitivity", 1.0))
    if event is InputEventScreenDrag:
        orbit_yaw -= event.relative.x * 0.006 * sensitivity
        orbit_pitch = clamp(orbit_pitch - event.relative.y * 0.004 * sensitivity, -0.55, 0.20)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        orbit_yaw -= event.relative.x * 0.006 * sensitivity
        orbit_pitch = clamp(orbit_pitch - event.relative.y * 0.004 * sensitivity, -0.55, 0.20)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
        orbit_distance = max(4.2, orbit_distance - 0.5)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
        orbit_distance = min(11.0, orbit_distance + 0.5)

func _reset_camera():
    orbit_yaw = -0.18
    orbit_pitch = -0.15
    var actor = _selected_actor()
    orbit_distance = 7.5 if actor != null and actor.species_id == SpeciesProfiles.PYGMY_HIPPO else 6.3

func _toggle_settings():
    settings_overlay.visible = not settings_overlay.visible
    if settings_overlay.visible:
        var actor = _selected_actor()
        if actor != null:
            rename_edit.text = actor.display_name()
    else:
        _save_sanctuary()

func _toggle_journal():
    journal_overlay.visible = not journal_overlay.visible
    if journal_overlay.visible:
        _refresh_journal()

func _refresh_journal():
    var label = journal_overlay.get_node_or_null("JournalText")
    if label == null:
        return
    var recent = sanctuary.recent_journal(12)
    if recent.is_empty():
        label.text = "Your sanctuary story will appear here as the animals create memorable moments."
        return
    var lines = []
    for event in recent:
        lines.append("• %s" % str(event.get("text", "Sanctuary event")))
    label.text = "\n\n".join(lines)

func _rename_selected():
    var actor = _selected_actor()
    if actor == null:
        return
    var clean_name = rename_edit.text.strip_edges()
    if clean_name.length() < 1:
        return
    clean_name = clean_name.substr(0, min(clean_name.length(), 24))
    actor.state.animal_name = clean_name
    sanctuary.add_journal_event("identity", selected_id, "%s received a new name." % clean_name, 0.65)
    _refresh_info()
    _save_sanctuary()

func _ensure_audio_buses():
    for bus_name in ["Animal", "Ambience", "UI"]:
        if AudioServer.get_bus_index(bus_name) == -1:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _apply_settings():
    _set_bus_volume("Master", float(sanctuary.settings.get("master_volume", 1.0)))
    _set_bus_volume("Animal", float(sanctuary.settings.get("animal_volume", 1.0)))
    _set_bus_volume("Ambience", float(sanctuary.settings.get("ambience_volume", 0.85)))
    _set_bus_volume("UI", float(sanctuary.settings.get("ui_volume", 0.85)))

func _set_bus_volume(bus_name, value):
    var index = AudioServer.get_bus_index(bus_name)
    if index >= 0:
        var safe_value = max(float(value), 0.001)
        AudioServer.set_bus_volume_db(index, linear_to_db(safe_value))
        AudioServer.set_bus_mute(index, float(value) <= 0.001)

func _on_master_volume(value):
    sanctuary.settings["master_volume"] = value
    _set_bus_volume("Master", value)

func _on_animal_volume(value):
    sanctuary.settings["animal_volume"] = value
    _set_bus_volume("Animal", value)

func _on_ambience_volume(value):
    sanctuary.settings["ambience_volume"] = value
    _set_bus_volume("Ambience", value)

func _on_ui_volume(value):
    sanctuary.settings["ui_volume"] = value
    _set_bus_volume("UI", value)

func _on_haptics(enabled):
    sanctuary.settings["haptics"] = enabled

func _on_show_stats(enabled):
    sanctuary.settings["show_stats"] = enabled
    animal_stats_label.visible = enabled

func _on_reduced_motion(enabled):
    sanctuary.settings["reduced_motion"] = enabled

func _haptic(milliseconds):
    if bool(sanctuary.settings.get("haptics", true)):
        Input.vibrate_handheld(milliseconds)

func _update_day_night():
    if environment == null or sun == null:
        return
    if str(sanctuary.settings.get("time_mode", "automatic")) != "automatic":
        return
    var hour = int(Time.get_time_dict_from_system().get("hour", 12))
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

func _save_sanctuary():
    if sanctuary == null:
        return
    for id_key in animals.keys():
        sanctuary.update_animal(id_key, animals[id_key].to_dict())

    var temp_path = SAVE_PATH + ".tmp"
    var file = FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(sanctuary.to_dict()))
    file.close()

    var absolute_temp = ProjectSettings.globalize_path(temp_path)
    var absolute_save = ProjectSettings.globalize_path(SAVE_PATH)
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(absolute_save)
    DirAccess.rename_absolute(absolute_temp, absolute_save)

func _load_sanctuary():
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        _recover_corrupt_save()
        return
    sanctuary.from_dict(parsed)

func _recover_corrupt_save():
    var corrupt_path = "user://sanctuary_save_corrupt_%d.json" % int(Time.get_unix_time_from_system())
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(corrupt_path))
