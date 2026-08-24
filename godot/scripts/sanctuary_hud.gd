extends Node

# Reference-driven production HUD for the Grasslands Sanctuary target.
# The UI is fully connected to the existing live companion simulation; it is not a mockup.

const MINIMAP_SCRIPT = preload("res://scripts/sanctuary_minimap.gd")

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var layer: CanvasLayer

var companion_panel: Panel
var avatar_panel: Panel
var avatar_label: Label
var name_label: Label
var species_label: Label
var bond_bar: ProgressBar
var hunger_bar: ProgressBar
var energy_bar: ProgressBar

var title_label: Label
var status_panel: Panel
var time_label: Label
var weather_label: Label
var audio_button: Button
var menu_button: Button
var minimap_panel: Panel
var minimap: Control
var action_rail: VBoxContainer
var camera_button: Button
var orbit_pad: HBoxContainer
var bottom_nav: HBoxContainer

var sheet_panel: Panel
var sheet_title: Label
var sheet_body: Label
var sheet_map: Control
var sheet_action_buttons: Array[Button] = []
var close_sheet_button: Button

var bodycam_mode := false
var saved_camera_transform := Transform3D.IDENTITY
var saved_camera_fov := 48.0
var refresh_timer := 0.0
var last_size := Vector2.ZERO
var built := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 300
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(300):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            var companions_variant: Variant = roster_candidate.get("companions")
            if typeof(companions_variant) == TYPE_DICTIONARY and (companions_variant as Dictionary).size() >= 3:
                scene_root = candidate as Node3D
                roster = roster_candidate
                break
        await get_tree().process_frame

    if scene_root == null or roster == null:
        push_warning("SanctuaryHUD could not bind to the sanctuary and companion roster")
        return

    camera = _find_camera(scene_root)
    _build_hud()
    _hide_legacy_hud()
    built = true
    set_process(true)
    _refresh_hud()
    _layout_hud()

func _process(delta: float) -> void:
    if not built:
        return
    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)

    refresh_timer -= delta
    if refresh_timer <= 0.0:
        refresh_timer = 0.16
        _refresh_hud()

    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size != last_size:
        last_size = viewport_size
        _layout_hud()

    if bodycam_mode:
        _update_bodycam(delta)

func _build_hud() -> void:
    var existing := scene_root.find_child("GrasslandsSanctuaryHUD", true, false)
    if is_instance_valid(existing):
        existing.queue_free()

    layer = CanvasLayer.new()
    layer.name = "GrasslandsSanctuaryHUD"
    layer.layer = 48
    scene_root.add_child(layer)

    companion_panel = _panel()
    layer.add_child(companion_panel)

    avatar_panel = _panel(Color(0.17, 0.22, 0.20, 0.94), Color(0.58, 0.74, 0.62, 0.48), 18)
    companion_panel.add_child(avatar_panel)
    avatar_label = _label("M", 26, HORIZONTAL_ALIGNMENT_CENTER)
    avatar_panel.add_child(avatar_label)

    name_label = _label("Mochi", 23)
    companion_panel.add_child(name_label)
    species_label = _label("Baby pygmy hippo", 12)
    species_label.modulate = Color(0.83, 0.89, 0.84, 0.78)
    companion_panel.add_child(species_label)

    bond_bar = _progress()
    companion_panel.add_child(bond_bar)
    hunger_bar = _progress()
    companion_panel.add_child(hunger_bar)
    energy_bar = _progress()
    companion_panel.add_child(energy_bar)

    title_label = _label("HIPPO OS  •  GRASSLANDS SANCTUARY", 22, HORIZONTAL_ALIGNMENT_CENTER)
    title_label.modulate = Color(0.94, 0.97, 0.93, 0.92)
    layer.add_child(title_label)

    status_panel = _panel()
    layer.add_child(status_panel)
    time_label = _label("21:32", 17)
    status_panel.add_child(time_label)
    weather_label = _label("CLEAR", 11)
    weather_label.modulate = Color(0.82, 0.89, 0.83, 0.76)
    status_panel.add_child(weather_label)
    audio_button = _button("AUDIO", _toggle_audio, 11)
    status_panel.add_child(audio_button)
    menu_button = _button("MENU", _open_settings, 11)
    status_panel.add_child(menu_button)

    minimap_panel = _panel(Color(0.016, 0.030, 0.028, 0.86), Color(0.30, 0.48, 0.38, 0.45), 16)
    layer.add_child(minimap_panel)
    minimap = MINIMAP_SCRIPT.new()
    minimap.name = "LiveMinimap"
    minimap_panel.add_child(minimap)
    minimap.call("configure", scene_root, roster)

    action_rail = VBoxContainer.new()
    action_rail.name = "ActionRail"
    action_rail.add_theme_constant_override("separation", 10)
    layer.add_child(action_rail)
    action_rail.add_child(_button("FEED", _feed_selected, 13))
    action_rail.add_child(_button("PET", _pet_selected, 13))
    action_rail.add_child(_button("JOURNAL", _open_journal, 13))
    camera_button = _button("CAMERA", _toggle_bodycam, 13)
    action_rail.add_child(camera_button)

    orbit_pad = HBoxContainer.new()
    orbit_pad.name = "OrbitPad"
    orbit_pad.add_theme_constant_override("separation", 8)
    layer.add_child(orbit_pad)
    orbit_pad.add_child(_button("<", _orbit_left, 22))
    orbit_pad.add_child(_button("FOCUS", _orbit_focus, 11))
    orbit_pad.add_child(_button(">", _orbit_right, 22))

    bottom_nav = HBoxContainer.new()
    bottom_nav.name = "BottomNavigation"
    bottom_nav.add_theme_constant_override("separation", 8)
    layer.add_child(bottom_nav)
    bottom_nav.add_child(_nav_button("MAP", _open_map))
    bottom_nav.add_child(_nav_button("CUSTOMIZE", _open_customize))
    bottom_nav.add_child(_nav_button("COLLECTION", _open_collection))
    bottom_nav.add_child(_nav_button("SANCTUARY", _return_sanctuary))
    bottom_nav.add_child(_nav_button("COMPANIONS", _open_companions))

    _build_sheet()

func _build_sheet() -> void:
    sheet_panel = _panel(Color(0.012, 0.022, 0.022, 0.975), Color(0.31, 0.51, 0.39, 0.68), 22)
    sheet_panel.visible = false
    layer.add_child(sheet_panel)

    sheet_title = _label("JOURNAL", 26)
    sheet_panel.add_child(sheet_title)
    sheet_body = _label("", 15)
    sheet_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sheet_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    sheet_panel.add_child(sheet_body)

    sheet_map = MINIMAP_SCRIPT.new()
    sheet_map.visible = false
    sheet_panel.add_child(sheet_map)
    sheet_map.call("configure", scene_root, roster)

    close_sheet_button = _button("CLOSE", _close_sheet, 12)
    sheet_panel.add_child(close_sheet_button)

    for i in range(4):
        var button := _button("ACTION", _sheet_noop, 12)
        button.visible = false
        sheet_action_buttons.append(button)
        sheet_panel.add_child(button)

func _layout_hud() -> void:
    if not built and layer == null:
        return
    var visible := get_viewport().get_visible_rect()
    var safe := _safe_rect(visible)
    last_size = visible.size
    var margin := maxf(14.0, minf(24.0, safe.size.y * 0.028))
    var right := safe.end.x
    var bottom := safe.end.y

    companion_panel.position = safe.position + Vector2(margin, margin)
    companion_panel.size = Vector2(minf(330.0, safe.size.x * 0.30), 132.0)
    avatar_panel.position = Vector2(14, 14)
    avatar_panel.size = Vector2(68, 68)
    avatar_label.position = Vector2(0, 15)
    avatar_label.size = Vector2(68, 38)
    name_label.position = Vector2(96, 14)
    name_label.size = Vector2(companion_panel.size.x - 110, 30)
    species_label.position = Vector2(96, 44)
    species_label.size = Vector2(companion_panel.size.x - 110, 22)

    var bar_width := maxf(80.0, companion_panel.size.x - 112.0)
    bond_bar.position = Vector2(96, 72)
    bond_bar.size = Vector2(bar_width, 15)
    hunger_bar.position = Vector2(96, 91)
    hunger_bar.size = Vector2(bar_width, 15)
    energy_bar.position = Vector2(96, 110)
    energy_bar.size = Vector2(bar_width, 15)

    title_label.position = Vector2(safe.position.x + safe.size.x * 0.5 - 230.0, safe.position.y + margin + 2.0)
    title_label.size = Vector2(460, 40)

    status_panel.size = Vector2(272, 72)
    status_panel.position = Vector2(right - status_panel.size.x - margin, safe.position.y + margin)
    time_label.position = Vector2(15, 10)
    time_label.size = Vector2(90, 24)
    weather_label.position = Vector2(15, 37)
    weather_label.size = Vector2(90, 18)
    audio_button.position = Vector2(108, 14)
    audio_button.size = Vector2(70, 42)
    menu_button.position = Vector2(186, 14)
    menu_button.size = Vector2(70, 42)

    minimap_panel.size = Vector2(220, 126)
    minimap_panel.position = Vector2(right - minimap_panel.size.x - margin, status_panel.position.y + status_panel.size.y + 10.0)
    minimap.position = Vector2(8, 8)
    minimap.size = minimap_panel.size - Vector2(16, 16)

    action_rail.size = Vector2(112, 246)
    action_rail.position = Vector2(right - 112.0 - margin, minimap_panel.position.y + minimap_panel.size.y + 13.0)
    for child in action_rail.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(112, 52)

    orbit_pad.position = Vector2(safe.position.x + margin, bottom - 90.0)
    orbit_pad.size = Vector2(246, 60)
    for child in orbit_pad.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(72, 56)

    bottom_nav.size = Vector2(minf(620.0, safe.size.x * 0.54), 62)
    bottom_nav.position = Vector2(safe.position.x + safe.size.x * 0.5 - bottom_nav.size.x * 0.5, bottom - 76.0)
    var nav_width := maxf(92.0, (bottom_nav.size.x - 32.0) / 5.0)
    for child in bottom_nav.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(nav_width, 58)

    sheet_panel.size = Vector2(minf(760.0, safe.size.x - 80.0), minf(470.0, safe.size.y - 100.0))
    sheet_panel.position = Vector2(safe.position.x + safe.size.x * 0.5 - sheet_panel.size.x * 0.5, safe.position.y + safe.size.y * 0.5 - sheet_panel.size.y * 0.5)
    sheet_title.position = Vector2(28, 22)
    sheet_title.size = Vector2(sheet_panel.size.x - 160, 38)
    sheet_body.position = Vector2(30, 82)
    sheet_body.size = Vector2(sheet_panel.size.x - 60, sheet_panel.size.y - 150)
    sheet_map.position = Vector2(38, 82)
    sheet_map.size = Vector2(sheet_panel.size.x - 76, sheet_panel.size.y - 160)
    close_sheet_button.position = Vector2(sheet_panel.size.x - 112, 18)
    close_sheet_button.size = Vector2(88, 42)
    for i in range(sheet_action_buttons.size()):
        sheet_action_buttons[i].position = Vector2(30 + float(i) * 145.0, sheet_panel.size.y - 76.0)
        sheet_action_buttons[i].size = Vector2(132, 44)

func _refresh_hud() -> void:
    if roster == null:
        return
    var species := str(roster.get("selected_species"))
    var data := _selected_data()
    var selected_name := str(data.get("name", "Companion"))
    var selected_species := str(data.get("species_label", species.capitalize()))

    if species == "hippo":
        selected_name = str(scene_root.get("hippo_name"))
        selected_species = "Baby pygmy hippo"

    name_label.text = selected_name
    species_label.text = selected_species
    avatar_label.text = selected_name.left(1).to_upper()

    var accent: Color = data.get("accent", Color(0.72, 0.82, 0.74))
    var avatar_style := avatar_panel.get_theme_stylebox("panel") as StyleBoxFlat
    if avatar_style != null:
        avatar_style.border_color = Color(accent.r, accent.g, accent.b, 0.70)
        avatar_style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.94)

    var bond := 0.0
    var hunger := 0.0
    var energy := 0.0
    if species == "hippo":
        bond = float(scene_root.get("bond"))
        hunger = float(scene_root.get("hunger"))
        energy = float(scene_root.get("energy"))
    else:
        bond = float(data.get("bond", 0.3))
        hunger = float(data.get("hunger", 0.2))
        energy = float(data.get("energy", 0.8))

    _set_bar(bond_bar, bond, "BOND")
    _set_bar(hunger_bar, hunger, "HUNGER")
    _set_bar(energy_bar, energy, "ENERGY")

    var time := Time.get_time_dict_from_system()
    time_label.text = "%02d:%02d" % [int(time.get("hour", 12)), int(time.get("minute", 0))]
    var hour := int(time.get("hour", 12))
    weather_label.text = "CLEAR NIGHT" if hour < 6 or hour >= 19 else "CLEAR DAY"

    var master_index := AudioServer.get_bus_index("Master")
    audio_button.text = "MUTED" if master_index >= 0 and AudioServer.is_bus_mute(master_index) else "AUDIO"
    camera_button.text = "EXIT CAM" if bodycam_mode else "CAMERA"

func _hide_legacy_hud() -> void:
    var stats_panel_variant: Variant = scene_root.get("stats_panel")
    if stats_panel_variant is Control:
        (stats_panel_variant as Control).visible = false

    var controls := scene_root.find_children("*", "Control", true, false)
    for node in controls:
        if node == companion_panel or node.is_ancestor_of(companion_panel):
            continue
        if node is Button:
            var button := node as Button
            if button.text in ["ANIMALS", "COMPANIONS", "OFFER FOOD", "FEED", "+", "-", "SETTINGS"]:
                button.visible = false
        elif node is OptionButton and node.name == "FoodSelector":
            node.visible = false
        elif node is Label:
            var label := node as Label
            if label.text.begins_with("Pet by dragging") or label.text.begins_with("DRAG TO ORBIT") or label.text.begins_with("HIPPO OS"):
                label.visible = false

    var mute := scene_root.find_child("AudioMuteButton", true, false) as Button
    if mute != null:
        mute.visible = false

func _feed_selected() -> void:
    if roster != null and roster.has_method("_treat_selected"):
        roster.call("_treat_selected")
    _pulse_haptic(24)

func _pet_selected() -> void:
    if roster != null and roster.has_method("_pet_selected"):
        roster.call("_pet_selected")
    _pulse_haptic(18)

func _open_journal() -> void:
    _show_sheet("JOURNAL")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = _journal_text()

func _open_map() -> void:
    _show_sheet("SANCTUARY MAP")
    sheet_body.visible = false
    sheet_map.visible = true

func _open_customize() -> void:
    _show_sheet("CUSTOMIZE SANCTUARY")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = "DAY / NIGHT\n\nChoose how the sanctuary lighting behaves. AUTO follows the device clock. These controls update the live sanctuary environment and persist with your pet settings."
    _configure_sheet_button(0, "AUTO", _set_day_mode.bind("auto"))
    _configure_sheet_button(1, "DAY", _set_day_mode.bind("day"))
    _configure_sheet_button(2, "NIGHT", _set_day_mode.bind("night"))
    _configure_sheet_button(3, "RESET VIEW", _orbit_focus)

func _open_collection() -> void:
    _show_sheet("YOUR COLLECTION")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = "Three companions currently live in this sanctuary. Selecting one changes the hero subject, action rail and live companion card."
    _configure_sheet_button(0, "MOCHI", _select_species.bind("hippo"))
    _configure_sheet_button(1, "PORKY", _select_species.bind("pig"))
    _configure_sheet_button(2, "BAO", _select_species.bind("sharpei"))

func _open_companions() -> void:
    _show_sheet("COMPANIONS")
    sheet_body.visible = true
    sheet_map.visible = false
    var data := _selected_data()
    sheet_body.text = "%s\n%s\n\nAll companions continue their autonomous routines while one is selected. Choose who you want to focus on." % [str(data.get("name", "Companion")), str(data.get("tagline", "Living in the sanctuary"))]
    _configure_sheet_button(0, "MOCHI", _select_species.bind("hippo"))
    _configure_sheet_button(1, "PORKY", _select_species.bind("pig"))
    _configure_sheet_button(2, "BAO", _select_species.bind("sharpei"))

func _return_sanctuary() -> void:
    _close_sheet()
    if bodycam_mode:
        _toggle_bodycam()
    _orbit_focus()

func _toggle_bodycam() -> void:
    if camera == null or not is_instance_valid(camera):
        return
    bodycam_mode = not bodycam_mode
    if bodycam_mode:
        saved_camera_transform = camera.global_transform
        saved_camera_fov = camera.fov
        sheet_panel.visible = false
    else:
        camera.global_transform = saved_camera_transform
        camera.fov = saved_camera_fov
    camera_button.text = "EXIT CAM" if bodycam_mode else "CAMERA"
    _pulse_haptic(16)

func _update_bodycam(delta: float) -> void:
    var selected := _selected_node()
    if selected == null or camera == null:
        return
    var forward := selected.global_transform.basis.x.normalized()
    if forward.length_squared() < 0.1:
        forward = Vector3(1.0, 0.0, 0.0)
    var desired := selected.global_position + Vector3(0.0, 1.03, 0.0) + forward * 0.32
    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 7.5, 0.0, 1.0))
    camera.look_at(desired + forward * 3.2 + Vector3(0.0, -0.08, 0.0), Vector3.UP)
    camera.fov = lerpf(camera.fov, 62.0, clampf(delta * 5.0, 0.0, 1.0))

func _orbit_left() -> void:
    scene_root.set("orbit_yaw", float(scene_root.get("orbit_yaw")) - 0.30)
    scene_root.set("orbit_distance", minf(float(scene_root.get("orbit_distance")), 7.0))
    _pulse_haptic(10)

func _orbit_right() -> void:
    scene_root.set("orbit_yaw", float(scene_root.get("orbit_yaw")) + 0.30)
    scene_root.set("orbit_distance", minf(float(scene_root.get("orbit_distance")), 7.0))
    _pulse_haptic(10)

func _orbit_focus() -> void:
    scene_root.set("orbit_distance", 6.2)
    scene_root.set("orbit_pitch", -0.08)
    _pulse_haptic(10)

func _set_day_mode(mode: String) -> void:
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) != TYPE_DICTIONARY:
        return
    var settings: Dictionary = settings_variant as Dictionary
    settings["day_night_mode"] = mode
    scene_root.set("settings", settings)
    if scene_root.has_method("_apply_day_night"):
        scene_root.call("_apply_day_night")
    if scene_root.has_method("_save_state"):
        scene_root.call("_save_state")
    sheet_body.text = "Sanctuary lighting set to %s." % mode.to_upper()
    _pulse_haptic(12)

func _select_species(species: String) -> void:
    if roster != null and roster.has_method("_select_companion"):
        roster.call("_select_companion", species)
    _close_sheet()
    _orbit_focus()

func _toggle_audio() -> void:
    var old_mute := scene_root.find_child("AudioMuteButton", true, false) as Button
    if old_mute != null:
        old_mute.emit_signal("pressed")
    else:
        var master := AudioServer.get_bus_index("Master")
        if master >= 0:
            AudioServer.set_bus_mute(master, not AudioServer.is_bus_mute(master))
    _refresh_hud()

func _open_settings() -> void:
    var buttons := scene_root.find_children("*", "Button", true, false)
    for node in buttons:
        var button := node as Button
        if button != null and button.text == "SETTINGS":
            button.emit_signal("pressed")
            return
    var settings_panel_variant: Variant = scene_root.get("settings_panel")
    if settings_panel_variant is Control:
        var panel := settings_panel_variant as Control
        panel.visible = not panel.visible

func _journal_text() -> String:
    var species := str(roster.get("selected_species"))
    var data := _selected_data()
    var name := str(data.get("name", "Companion"))
    var action := str(data.get("action", "exploring")).capitalize()
    if species == "hippo":
        name = str(scene_root.get("hippo_name"))
        action = str(scene_root.get("current_action")).capitalize()
        var counts_variant: Variant = scene_root.get("interaction_counts")
        var counts: Dictionary = counts_variant as Dictionary if typeof(counts_variant) == TYPE_DICTIONARY else {}
        return "%s'S JOURNAL\n\nCurrent mood: %s\nBond: %d%%\n\nMEMORIES SO FAR\nPetting moments: %d\nMeals offered: %d\nWater visits: %d\nMud sessions: %d\n\nThe production journal will expand these persistent interaction records into dated companion memories." % [name.to_upper(), action, int(float(scene_root.get("bond")) * 100.0), int(counts.get("pet", 0)), int(counts.get("feed", 0)), int(counts.get("water", 0)), int(counts.get("mud", 0))]
    return "%s'S JOURNAL\n\nCurrent mood: %s\nBond: %d%%\nEnergy: %d%%\nCuriosity: %d%%\n\n%s" % [name.to_upper(), action, int(float(data.get("bond", 0.3)) * 100.0), int(float(data.get("energy", 0.8)) * 100.0), int(float(data.get("curiosity", 0.6)) * 100.0), str(data.get("tagline", "Living in the sanctuary"))]

func _show_sheet(title: String) -> void:
    sheet_panel.visible = true
    sheet_title.text = title
    for button in sheet_action_buttons:
        button.visible = false
    _pulse_haptic(12)

func _close_sheet() -> void:
    sheet_panel.visible = false

func _configure_sheet_button(index: int, text: String, callback: Callable) -> void:
    if index < 0 or index >= sheet_action_buttons.size():
        return
    var button := sheet_action_buttons[index]
    button.visible = true
    button.text = text
    for connection in button.pressed.get_connections():
        button.pressed.disconnect(connection.callable)
    button.pressed.connect(callback)

func _sheet_noop() -> void:
    pass

func _selected_data() -> Dictionary:
    if roster == null:
        return {}
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return {}
    var companions := companions_variant as Dictionary
    var species := str(roster.get("selected_species"))
    var data_variant: Variant = companions.get(species, {})
    return data_variant as Dictionary if typeof(data_variant) == TYPE_DICTIONARY else {}

func _selected_node() -> Node3D:
    var data := _selected_data()
    var node := data.get("node") as Node3D
    return node if node != null and is_instance_valid(node) else null

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null

func _set_bar(bar: ProgressBar, value: float, label_text: String) -> void:
    bar.value = clampf(value, 0.0, 1.0) * 100.0
    bar.tooltip_text = "%s %d%%" % [label_text, int(bar.value)]

func _safe_rect(visible: Rect2) -> Rect2:
    var screen_size := DisplayServer.screen_get_size()
    var system_safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0 or screen_size.y <= 0 or system_safe.size.x <= 0 or system_safe.size.y <= 0:
        return visible
    var scale := Vector2(visible.size.x / float(screen_size.x), visible.size.y / float(screen_size.y))
    return Rect2(Vector2(system_safe.position) * scale, Vector2(system_safe.size) * scale)

func _panel(bg := Color(0.016, 0.027, 0.027, 0.88), border := Color(0.28, 0.45, 0.35, 0.52), radius := 18) -> Panel:
    var panel := Panel.new()
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
    style.shadow_size = 8
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _label(text_value: String, font_size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.horizontal_alignment = align
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.modulate = Color(0.94, 0.97, 0.93, 0.96)
    return label

func _button(text_value: String, callback: Callable, font_size := 13) -> Button:
    var button := Button.new()
    button.text = text_value
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", Color(0.92, 0.96, 0.91))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.028, 0.050, 0.043, 0.93)
    normal.border_color = Color(0.31, 0.49, 0.38, 0.62)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(14)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.055, 0.105, 0.078, 0.98)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.10, 0.23, 0.15, 1.0)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.pressed.connect(callback)
    return button

func _nav_button(text_value: String, callback: Callable) -> Button:
    var button := _button(text_value, callback, 11)
    button.custom_minimum_size = Vector2(110, 58)
    return button

func _progress() -> ProgressBar:
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.show_percentage = true
    bar.add_theme_font_size_override("font_size", 9)
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.06, 0.08, 0.07, 0.90)
    background.set_corner_radius_all(5)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(0.36, 0.68, 0.42, 0.92)
    fill.set_corner_radius_all(5)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    return bar

func _pulse_haptic(duration: int) -> void:
    var settings_variant: Variant = scene_root.get("settings") if scene_root != null else null
    if typeof(settings_variant) == TYPE_DICTIONARY and bool((settings_variant as Dictionary).get("haptics", true)):
        Input.vibrate_handheld(duration)
