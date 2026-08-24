extends Node

# Portrait-first, reference-driven production HUD.
# Keeps the companion simulation live while matching the approved sanctuary composition:
# translucent companion card, quiet brand, time/conditions, circular minimap, right action
# rail, orbit control and a premium bottom dock. Landscape remains a supported fallback.

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

var brand_label: Label
var brand_subtitle: Label
var status_panel: Panel
var time_label: Label
var weather_label: Label
var menu_button: Button
var minimap_panel: Panel
var minimap: Control
var location_label: Label
var action_rail: VBoxContainer
var camera_button: Button
var orbit_panel: Panel
var orbit_pad: GridContainer
var bottom_chevron: Button
var bottom_panel: Panel
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
var legacy_hide_timer := 0.0
var last_size := Vector2.ZERO
var built := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 900
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
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
        push_warning("SanctuaryHUD could not bind to the live sanctuary")
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
    legacy_hide_timer -= delta
    if refresh_timer <= 0.0:
        refresh_timer = 0.15
        _refresh_hud()
    if legacy_hide_timer <= 0.0:
        legacy_hide_timer = 0.25
        _hide_legacy_hud()

    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size != last_size:
        _layout_hud()

    if bodycam_mode:
        _update_bodycam(delta)

func _build_hud() -> void:
    var old := scene_root.find_child("GrasslandsSanctuaryHUD", true, false)
    if is_instance_valid(old):
        old.queue_free()

    layer = CanvasLayer.new()
    layer.name = "GrasslandsSanctuaryHUD"
    layer.layer = 60
    scene_root.add_child(layer)

    companion_panel = _panel(Color(0.035, 0.055, 0.070, 0.68), Color(1, 1, 1, 0.14), 22)
    layer.add_child(companion_panel)

    avatar_panel = _panel(Color(0.12, 0.15, 0.16, 0.88), Color(0.82, 0.88, 0.84, 0.58), 36)
    companion_panel.add_child(avatar_panel)
    avatar_label = _label("M", 25, HORIZONTAL_ALIGNMENT_CENTER)
    avatar_panel.add_child(avatar_label)

    name_label = _label("Mochi", 22)
    companion_panel.add_child(name_label)
    species_label = _label("Baby", 14)
    species_label.modulate = Color(0.92, 0.94, 0.94, 0.68)
    companion_panel.add_child(species_label)

    bond_bar = _progress(Color(0.96, 0.34, 0.48))
    hunger_bar = _progress(Color(0.60, 0.84, 0.28))
    energy_bar = _progress(Color(0.18, 0.66, 0.92))
    companion_panel.add_child(bond_bar)
    companion_panel.add_child(hunger_bar)
    companion_panel.add_child(energy_bar)

    brand_label = _label("HIPPO OS", 27, HORIZONTAL_ALIGNMENT_CENTER)
    brand_label.modulate = Color(1, 1, 1, 0.95)
    layer.add_child(brand_label)
    brand_subtitle = _label("Sanctuary", 15, HORIZONTAL_ALIGNMENT_CENTER)
    brand_subtitle.modulate = Color(0.78, 0.68, 0.94, 0.92)
    layer.add_child(brand_subtitle)

    status_panel = _panel(Color(0.035, 0.045, 0.052, 0.56), Color(1, 1, 1, 0.12), 20)
    layer.add_child(status_panel)
    time_label = _label("08:47", 18)
    status_panel.add_child(time_label)
    weather_label = _label("CLEAR DAY", 12)
    weather_label.modulate = Color(1, 1, 1, 0.76)
    status_panel.add_child(weather_label)
    menu_button = _button("MENU", _open_settings, 11)
    status_panel.add_child(menu_button)

    minimap_panel = _panel(Color(0.015, 0.025, 0.025, 0.50), Color(1, 1, 1, 0.46), 94)
    minimap_panel.clip_contents = true
    layer.add_child(minimap_panel)
    minimap = MINIMAP_SCRIPT.new()
    minimap.name = "LiveMinimap"
    minimap_panel.add_child(minimap)
    minimap.call("configure", scene_root, roster)

    location_label = _label("GRASSLANDS\nSOUTH AFRICA", 12, HORIZONTAL_ALIGNMENT_CENTER)
    location_label.modulate = Color(1, 1, 1, 0.72)
    layer.add_child(location_label)

    action_rail = VBoxContainer.new()
    action_rail.name = "ActionRail"
    action_rail.add_theme_constant_override("separation", 12)
    layer.add_child(action_rail)
    action_rail.add_child(_action_button("FEED", _feed_selected))
    action_rail.add_child(_action_button("PET", _pet_selected))
    action_rail.add_child(_action_button("JOURNAL", _open_journal))
    camera_button = _action_button("CAMERA", _toggle_bodycam)
    action_rail.add_child(camera_button)

    orbit_panel = _panel(Color(0.025, 0.035, 0.040, 0.40), Color(1, 1, 1, 0.18), 80)
    layer.add_child(orbit_panel)
    orbit_pad = GridContainer.new()
    orbit_pad.columns = 3
    orbit_pad.add_theme_constant_override("h_separation", 4)
    orbit_pad.add_theme_constant_override("v_separation", 4)
    orbit_panel.add_child(orbit_pad)
    orbit_pad.add_child(_ghost_button("", _noop))
    orbit_pad.add_child(_ghost_button("^", _orbit_up))
    orbit_pad.add_child(_ghost_button("", _noop))
    orbit_pad.add_child(_ghost_button("<", _orbit_left))
    orbit_pad.add_child(_ghost_button("•", _orbit_focus))
    orbit_pad.add_child(_ghost_button(">", _orbit_right))
    orbit_pad.add_child(_ghost_button("", _noop))
    orbit_pad.add_child(_ghost_button("v", _orbit_down))
    orbit_pad.add_child(_ghost_button("", _noop))

    bottom_chevron = _button("^", _orbit_focus, 18)
    layer.add_child(bottom_chevron)

    bottom_panel = _panel(Color(0.030, 0.030, 0.028, 0.64), Color(1, 1, 1, 0.10), 24)
    layer.add_child(bottom_panel)
    bottom_nav = HBoxContainer.new()
    bottom_nav.name = "BottomNavigation"
    bottom_nav.add_theme_constant_override("separation", 3)
    bottom_panel.add_child(bottom_nav)
    bottom_nav.add_child(_nav_button("MAP", _open_map))
    bottom_nav.add_child(_nav_button("CUSTOMIZE", _open_customize))
    bottom_nav.add_child(_nav_button("SHOP", _open_shop))
    bottom_nav.add_child(_nav_button("SANCTUARY", _return_sanctuary))
    bottom_nav.add_child(_nav_button("SOCIAL", _open_social))

    _build_sheet()

func _build_sheet() -> void:
    sheet_panel = _panel(Color(0.012, 0.020, 0.022, 0.94), Color(0.80, 0.88, 0.82, 0.28), 26)
    sheet_panel.visible = false
    layer.add_child(sheet_panel)

    sheet_title = _label("JOURNAL", 25)
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

    for _i in range(4):
        var button := _button("ACTION", _noop, 12)
        button.visible = false
        sheet_action_buttons.append(button)
        sheet_panel.add_child(button)

func _layout_hud() -> void:
    if layer == null:
        return
    var visible := get_viewport().get_visible_rect()
    var safe := _safe_rect(visible)
    last_size = visible.size
    var portrait := safe.size.y >= safe.size.x
    if portrait:
        _layout_portrait(safe)
    else:
        _layout_landscape(safe)

func _layout_portrait(safe: Rect2) -> void:
    var w := safe.size.x
    var h := safe.size.y
    var left := safe.position.x
    var top := safe.position.y
    var right := safe.end.x
    var bottom := safe.end.y
    var m := maxf(14.0, w * 0.028)

    var card_w := minf(286.0, w * 0.36)
    var card_h := 156.0
    companion_panel.position = Vector2(left + m, top + m)
    companion_panel.size = Vector2(card_w, card_h)
    _layout_companion_card(card_w, card_h)

    brand_label.position = Vector2(left + w * 0.5 - 105.0, top + m + 2.0)
    brand_label.size = Vector2(210, 36)
    brand_subtitle.position = Vector2(left + w * 0.5 - 105.0, top + m + 35.0)
    brand_subtitle.size = Vector2(210, 24)

    status_panel.size = Vector2(162, 78)
    status_panel.position = Vector2(right - status_panel.size.x - m, top + m)
    time_label.position = Vector2(14, 10)
    time_label.size = Vector2(86, 26)
    weather_label.position = Vector2(14, 39)
    weather_label.size = Vector2(96, 20)
    menu_button.position = Vector2(111, 14)
    menu_button.size = Vector2(40, 48)

    var map_size := minf(190.0, w * 0.25)
    minimap_panel.size = Vector2(map_size, map_size)
    minimap_panel.position = Vector2(right - map_size - m, status_panel.position.y + status_panel.size.y + 18.0)
    minimap.position = Vector2(8, 8)
    minimap.size = minimap_panel.size - Vector2(16, 16)
    location_label.position = Vector2(minimap_panel.position.x - 4.0, minimap_panel.position.y + map_size + 8.0)
    location_label.size = Vector2(map_size + 8.0, 44)

    action_rail.size = Vector2(82, 352)
    action_rail.position = Vector2(right - 82.0 - m, h * 0.47)
    for child in action_rail.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(82, 76)

    var orbit_size := minf(166.0, w * 0.22)
    orbit_panel.size = Vector2(orbit_size, orbit_size)
    orbit_panel.position = Vector2(left + m, bottom - orbit_size - 118.0)
    orbit_pad.position = Vector2(12, 12)
    orbit_pad.size = orbit_panel.size - Vector2(24, 24)
    var cell := maxf(34.0, (orbit_pad.size.x - 8.0) / 3.0)
    for child in orbit_pad.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(cell, cell)

    bottom_chevron.size = Vector2(108, 36)
    bottom_chevron.position = Vector2(left + w * 0.5 - 54.0, bottom - 146.0)

    bottom_panel.position = Vector2(left + m, bottom - 102.0)
    bottom_panel.size = Vector2(w - m * 2.0, 92.0)
    bottom_nav.position = Vector2(8, 8)
    bottom_nav.size = bottom_panel.size - Vector2(16, 16)
    var nav_w := maxf(72.0, bottom_nav.size.x / 5.0 - 3.0)
    for child in bottom_nav.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(nav_w, 74)

    _layout_sheet(safe)

func _layout_landscape(safe: Rect2) -> void:
    var w := safe.size.x
    var h := safe.size.y
    var left := safe.position.x
    var top := safe.position.y
    var right := safe.end.x
    var bottom := safe.end.y
    var m := maxf(14.0, h * 0.025)

    var card_w := minf(330.0, w * 0.28)
    companion_panel.position = Vector2(left + m, top + m)
    companion_panel.size = Vector2(card_w, 132)
    _layout_companion_card(card_w, 132.0)

    brand_label.position = Vector2(left + w * 0.5 - 130.0, top + m)
    brand_label.size = Vector2(260, 34)
    brand_subtitle.position = Vector2(left + w * 0.5 - 130.0, top + m + 32)
    brand_subtitle.size = Vector2(260, 22)

    status_panel.size = Vector2(210, 68)
    status_panel.position = Vector2(right - 210.0 - m, top + m)
    time_label.position = Vector2(12, 8)
    time_label.size = Vector2(90, 24)
    weather_label.position = Vector2(12, 34)
    weather_label.size = Vector2(108, 20)
    menu_button.position = Vector2(142, 12)
    menu_button.size = Vector2(56, 44)

    minimap_panel.size = Vector2(160, 160)
    minimap_panel.position = Vector2(right - 160.0 - m, status_panel.position.y + 80.0)
    minimap.position = Vector2(8, 8)
    minimap.size = Vector2(144, 144)
    location_label.position = Vector2(minimap_panel.position.x, minimap_panel.position.y + 162.0)
    location_label.size = Vector2(160, 42)

    action_rail.position = Vector2(right - 86.0 - m, h * 0.46)
    action_rail.size = Vector2(86, 250)
    for child in action_rail.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(86, 54)

    orbit_panel.position = Vector2(left + m, bottom - 150.0)
    orbit_panel.size = Vector2(128, 128)
    orbit_pad.position = Vector2(10, 10)
    orbit_pad.size = Vector2(108, 108)
    for child in orbit_pad.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(33, 33)

    bottom_chevron.size = Vector2(94, 32)
    bottom_chevron.position = Vector2(left + w * 0.5 - 47.0, bottom - 106.0)
    bottom_panel.size = Vector2(minf(680.0, w * 0.58), 76)
    bottom_panel.position = Vector2(left + w * 0.5 - bottom_panel.size.x * 0.5, bottom - 82.0)
    bottom_nav.position = Vector2(8, 6)
    bottom_nav.size = bottom_panel.size - Vector2(16, 12)
    var nav_w := maxf(90.0, bottom_nav.size.x / 5.0 - 3.0)
    for child in bottom_nav.get_children():
        if child is Button:
            (child as Button).custom_minimum_size = Vector2(nav_w, 62)

    _layout_sheet(safe)

func _layout_companion_card(card_w: float, card_h: float) -> void:
    var avatar := minf(72.0, card_h * 0.48)
    avatar_panel.position = Vector2(14, 14)
    avatar_panel.size = Vector2(avatar, avatar)
    avatar_label.position = Vector2(0, avatar * 0.24)
    avatar_label.size = Vector2(avatar, 34)
    name_label.position = Vector2(avatar + 28, 14)
    name_label.size = Vector2(card_w - avatar - 40, 30)
    species_label.position = Vector2(avatar + 28, 44)
    species_label.size = Vector2(card_w - avatar - 40, 22)
    var bar_x := avatar + 28
    var bar_w := maxf(86.0, card_w - bar_x - 18.0)
    var first_y := maxf(70.0, card_h - 64.0)
    bond_bar.position = Vector2(bar_x, first_y)
    hunger_bar.position = Vector2(bar_x, first_y + 20)
    energy_bar.position = Vector2(bar_x, first_y + 40)
    bond_bar.size = Vector2(bar_w, 10)
    hunger_bar.size = Vector2(bar_w, 10)
    energy_bar.size = Vector2(bar_w, 10)

func _layout_sheet(safe: Rect2) -> void:
    var w := minf(720.0, safe.size.x - 40.0)
    var h := minf(520.0, safe.size.y - 180.0)
    sheet_panel.size = Vector2(w, h)
    sheet_panel.position = Vector2(safe.position.x + safe.size.x * 0.5 - w * 0.5, safe.position.y + safe.size.y * 0.5 - h * 0.5)
    sheet_title.position = Vector2(26, 20)
    sheet_title.size = Vector2(w - 150, 36)
    sheet_body.position = Vector2(28, 76)
    sheet_body.size = Vector2(w - 56, h - 154)
    sheet_map.position = Vector2(32, 74)
    sheet_map.size = Vector2(w - 64, h - 150)
    close_sheet_button.position = Vector2(w - 108, 16)
    close_sheet_button.size = Vector2(84, 42)
    var spacing := minf(142.0, (w - 60.0) / 4.0)
    for i in range(sheet_action_buttons.size()):
        sheet_action_buttons[i].position = Vector2(28 + float(i) * spacing, h - 66.0)
        sheet_action_buttons[i].size = Vector2(spacing - 10.0, 42)

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
        avatar_style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
        avatar_style.bg_color = Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.90)

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

    var now := Time.get_time_dict_from_system()
    var hour := int(now.get("hour", 12))
    time_label.text = "%02d:%02d" % [hour, int(now.get("minute", 0))]
    weather_label.text = "CLEAR NIGHT" if hour < 6 or hour >= 19 else "CLEAR DAY"
    camera_button.text = "EXIT CAM" if bodycam_mode else "CAMERA"

func _hide_legacy_hud() -> void:
    if scene_root == null:
        return
    var stats_panel_variant: Variant = scene_root.get("stats_panel")
    if stats_panel_variant is Control:
        (stats_panel_variant as Control).visible = false

    var personal_ui := scene_root.find_child("PersonalUseUI", true, false)
    if personal_ui is CanvasLayer:
        (personal_ui as CanvasLayer).visible = false

    var controls := scene_root.find_children("*", "Control", true, false)
    for node in controls:
        if node == companion_panel or node == bottom_panel or node == orbit_panel or node == sheet_panel:
            continue
        if layer != null and layer.is_ancestor_of(node):
            continue
        if node is Button:
            var button := node as Button
            if button.text in ["ANIMALS", "COMPANIONS", "OFFER FOOD", "FEED", "+", "-", "SETTINGS"]:
                button.visible = false
        elif node is OptionButton:
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
    _show_sheet("CUSTOMIZE")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = "LIGHTING & CAMERA\n\nAUTO follows the device clock. DAY and NIGHT let you choose the sanctuary mood manually. The camera reset returns to the cinematic hero framing."
    _configure_sheet_button(0, "AUTO", _set_day_mode.bind("auto"))
    _configure_sheet_button(1, "DAY", _set_day_mode.bind("day"))
    _configure_sheet_button(2, "NIGHT", _set_day_mode.bind("night"))
    _configure_sheet_button(3, "RESET VIEW", _orbit_focus)

func _open_shop() -> void:
    _show_sheet("SHOP")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = "SANCTUARY SUPPLIES\n\nFood, enrichment and habitat customization are represented by the live feeding and care systems. Paid commerce is intentionally disabled in this personal build."

func _open_social() -> void:
    _show_sheet("SOCIAL")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = "YOUR SANCTUARY\n\nThis personal build stays offline-first. Use Camera mode for clean companion views and device screenshots without accounts, tracking or a social login."

func _open_collection() -> void:
    _show_sheet("COMPANIONS")
    sheet_body.visible = true
    sheet_map.visible = false
    sheet_body.text = "Choose who you want the hero camera to follow. All three companions continue their autonomous routines."
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
        companion_panel.visible = false
        minimap_panel.visible = false
        location_label.visible = false
        brand_label.visible = false
        brand_subtitle.visible = false
        status_panel.visible = false
        orbit_panel.visible = false
        bottom_panel.visible = false
        bottom_chevron.visible = false
    else:
        camera.global_transform = saved_camera_transform
        camera.fov = saved_camera_fov
        companion_panel.visible = true
        minimap_panel.visible = true
        location_label.visible = true
        brand_label.visible = true
        brand_subtitle.visible = true
        status_panel.visible = true
        orbit_panel.visible = true
        bottom_panel.visible = true
        bottom_chevron.visible = true
    camera_button.text = "EXIT CAM" if bodycam_mode else "CAMERA"
    _pulse_haptic(16)

func _update_bodycam(delta: float) -> void:
    var selected := _selected_node()
    if selected == null or camera == null:
        return
    var forward := selected.global_transform.basis.x.normalized()
    if forward.length_squared() < 0.1:
        forward = Vector3(1.0, 0.0, 0.0)
    var desired := selected.global_position + Vector3(0.0, 1.02, 0.0) + forward * 0.38
    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 7.2, 0.0, 1.0))
    camera.look_at(desired + forward * 3.4 + Vector3(0.0, -0.10, 0.0), Vector3.UP)
    camera.fov = lerpf(camera.fov, 64.0, clampf(delta * 4.5, 0.0, 1.0))

func _orbit_left() -> void:
    scene_root.set("orbit_yaw", float(scene_root.get("orbit_yaw")) - 0.22)
    _pulse_haptic(8)

func _orbit_right() -> void:
    scene_root.set("orbit_yaw", float(scene_root.get("orbit_yaw")) + 0.22)
    _pulse_haptic(8)

func _orbit_up() -> void:
    scene_root.set("orbit_pitch", clampf(float(scene_root.get("orbit_pitch")) + 0.08, -0.42, 0.16))
    _pulse_haptic(8)

func _orbit_down() -> void:
    scene_root.set("orbit_pitch", clampf(float(scene_root.get("orbit_pitch")) - 0.08, -0.42, 0.16))
    _pulse_haptic(8)

func _orbit_focus() -> void:
    scene_root.set("orbit_distance", 6.0)
    scene_root.set("orbit_pitch", -0.08)
    _pulse_haptic(10)

func _set_day_mode(mode: String) -> void:
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) != TYPE_DICTIONARY:
        return
    var settings := settings_variant as Dictionary
    settings["day_night_mode"] = mode
    scene_root.set("settings", settings)
    if scene_root.has_method("_apply_day_night"):
        scene_root.call("_apply_day_night")
    if scene_root.has_method("_save_state"):
        scene_root.call("_save_state")
    sheet_body.text = "Sanctuary lighting set to %s." % mode.to_upper()

func _select_species(species: String) -> void:
    if roster != null and roster.has_method("_select_companion"):
        roster.call("_select_companion", species)
    _close_sheet()
    _orbit_focus()

func _open_settings() -> void:
    _open_collection()

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
        return "%s\n\nMood: %s\nBond: %d%%\n\nPetting moments: %d\nMeals: %d\nWater visits: %d\nMud sessions: %d" % [name, action, int(float(scene_root.get("bond")) * 100.0), int(counts.get("pet", 0)), int(counts.get("feed", 0)), int(counts.get("water", 0)), int(counts.get("mud", 0))]
    return "%s\n\nMood: %s\nBond: %d%%\nEnergy: %d%%\nCuriosity: %d%%\n\n%s" % [name, action, int(float(data.get("bond", 0.3)) * 100.0), int(float(data.get("energy", 0.8)) * 100.0), int(float(data.get("curiosity", 0.6)) * 100.0), str(data.get("tagline", "Living in the sanctuary"))]

func _show_sheet(title: String) -> void:
    sheet_panel.visible = true
    sheet_title.text = title
    for button in sheet_action_buttons:
        button.visible = false
    _pulse_haptic(10)

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

func _panel(bg: Color = Color(0.025, 0.040, 0.038, 0.70), border: Color = Color(0.70, 0.82, 0.74, 0.18), radius: int = 18) -> Panel:
    var panel := Panel.new()
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.shadow_color = Color(0, 0, 0, 0.22)
    style.shadow_size = 8
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _label(text: String, font_size: int, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = alignment
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.98))
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.48))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    return label

func _button(text: String, callback: Callable, font_size: int = 13) -> Button:
    var button := Button.new()
    button.text = text
    button.add_theme_font_size_override("font_size", font_size)
    _style_button(button, 18, 0.48)
    button.pressed.connect(callback)
    return button

func _action_button(text: String, callback: Callable) -> Button:
    var button := _button(text, callback, 12)
    _style_button(button, 22, 0.60)
    return button

func _nav_button(text: String, callback: Callable) -> Button:
    var button := _button(text, callback, 12)
    _style_button(button, 18, 0.18)
    return button

func _ghost_button(text: String, callback: Callable) -> Button:
    var button := _button(text, callback, 18)
    _style_button(button, 18, 0.12)
    button.focus_mode = Control.FOCUS_NONE
    return button

func _style_button(button: Button, radius: int, alpha: float) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.035, 0.035, 0.030, alpha)
    normal.border_color = Color(1, 1, 1, 0.10)
    normal.set_border_width_all(1)
    normal.corner_radius_top_left = radius
    normal.corner_radius_top_right = radius
    normal.corner_radius_bottom_left = radius
    normal.corner_radius_bottom_right = radius
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.18, 0.22, 0.17, minf(alpha + 0.16, 0.90))
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.25, 0.31, 0.21, minf(alpha + 0.24, 0.96))
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", normal)
    button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96))

func _progress(fill_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.min_value = 0.0
    bar.max_value = 100.0
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.75, 0.78, 0.78, 0.22)
    bg.corner_radius_top_left = 6
    bg.corner_radius_top_right = 6
    bg.corner_radius_bottom_left = 6
    bg.corner_radius_bottom_right = 6
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.corner_radius_top_left = 6
    fill.corner_radius_top_right = 6
    fill.corner_radius_bottom_left = 6
    fill.corner_radius_bottom_right = 6
    bar.add_theme_stylebox_override("background", bg)
    bar.add_theme_stylebox_override("fill", fill)
    return bar

func _set_bar(bar: ProgressBar, value: float, label_text: String) -> void:
    bar.value = clampf(value, 0.0, 1.0) * 100.0
    bar.tooltip_text = "%s %d%%" % [label_text, int(bar.value)]

func _safe_rect(visible: Rect2) -> Rect2:
    var screen_size := DisplayServer.screen_get_size()
    var system_safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0 or screen_size.y <= 0 or system_safe.size.x <= 0 or system_safe.size.y <= 0:
        return visible
    var scale := Vector2(visible.size.x / float(screen_size.x), visible.size.y / float(screen_size.y))
    var safe_position := Vector2(system_safe.position) * scale
    var safe_size := Vector2(system_safe.size) * scale
    return Rect2(safe_position, safe_size)

func _pulse_haptic(duration_ms: int) -> void:
    var settings_variant: Variant = scene_root.get("settings") if scene_root != null else {}
    if typeof(settings_variant) == TYPE_DICTIONARY and not bool((settings_variant as Dictionary).get("haptics", true)):
        return
    Input.vibrate_handheld(duration_ms)

func _noop() -> void:
    pass
