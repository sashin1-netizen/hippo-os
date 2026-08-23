extends Node

var host
var polish_ready = false
var last_selected = ""
var sky_material
var sky

func _ready():
    process_priority = 100
    await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _build_sky()
    _hide_development_labels(host)
    _polish_world()
    _polish_ui()
    _polish_animals()
    _apply_selection_focus(true)
    polish_ready = true

func _process(_delta):
    if not polish_ready or host == null:
        return
    _enforce_readable_lighting()
    _apply_selection_focus(false)

func _build_sky():
    var environment = host.get("environment")
    if environment == null:
        return
    sky_material = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.035, 0.105, 0.16)
    sky_material.sky_horizon_color = Color(0.27, 0.42, 0.42)
    sky_material.ground_bottom_color = Color(0.018, 0.035, 0.028)
    sky_material.ground_horizon_color = Color(0.18, 0.28, 0.22)
    sky = Sky.new()
    sky.sky_material = sky_material
    environment.sky = sky
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_energy = 1.05

func _enforce_readable_lighting():
    var environment = host.get("environment")
    var sun = host.get("sun")
    if environment == null or sun == null:
        return
    var hour = int(Time.get_time_dict_from_system().get("hour", 12))
    if hour >= 19 or hour < 6:
        environment.ambient_light_color = Color(0.34, 0.43, 0.52)
        environment.ambient_light_energy = 1.18
        sun.light_energy = max(float(sun.light_energy), 0.58)
        sun.light_color = Color(0.64, 0.72, 0.90)
        if sky_material != null:
            sky_material.sky_top_color = Color(0.012, 0.035, 0.09)
            sky_material.sky_horizon_color = Color(0.13, 0.22, 0.30)
            sky_material.ground_horizon_color = Color(0.07, 0.13, 0.12)
    elif hour >= 17:
        environment.ambient_light_color = Color(0.76, 0.58, 0.42)
        environment.ambient_light_energy = 1.05
        sun.light_energy = max(float(sun.light_energy), 0.95)
        sun.light_color = Color(1.0, 0.72, 0.46)
        if sky_material != null:
            sky_material.sky_top_color = Color(0.17, 0.22, 0.32)
            sky_material.sky_horizon_color = Color(0.72, 0.38, 0.22)
            sky_material.ground_horizon_color = Color(0.22, 0.18, 0.12)
    else:
        environment.ambient_light_color = Color(0.72, 0.82, 0.74)
        environment.ambient_light_energy = 1.10
        sun.light_energy = max(float(sun.light_energy), 1.55)
        sun.light_color = Color(1.0, 0.94, 0.82)
        if sky_material != null:
            sky_material.sky_top_color = Color(0.16, 0.39, 0.57)
            sky_material.sky_horizon_color = Color(0.64, 0.78, 0.73)
            sky_material.ground_horizon_color = Color(0.30, 0.42, 0.29)

func _hide_development_labels(node):
    for child in node.get_children():
        if child is Label3D:
            child.visible = false
        _hide_development_labels(child)

func _polish_world():
    _add_water_gloss()
    _add_reed_cluster(Vector3(3.9, 0.12, 2.4), 7)
    _add_reed_cluster(Vector3(0.2, 0.12, 3.6), 6)
    _add_reed_cluster(Vector3(-0.4, 0.12, 1.7), 5)
    _add_shrub(Vector3(-4.6, 0.0, 4.8), 1.15)
    _add_shrub(Vector3(5.2, 0.0, 4.4), 1.05)
    _add_shrub(Vector3(-10.8, 0.0, 2.8), 0.95)
    _add_shrub(Vector3(10.7, 0.0, 2.5), 1.00)
    _add_shrub(Vector3(-5.5, 0.0, -5.8), 1.20)
    _add_shrub(Vector3(5.8, 0.0, -5.7), 1.20)

func _add_water_gloss():
    var water = MeshInstance3D.new()
    water.name = "PolishedWater"
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 2.48
    cylinder.bottom_radius = 2.48
    cylinder.height = 0.025
    water.mesh = cylinder
    water.position = Vector3(2.0, 0.115, 2.1)
    water.scale = Vector3(1.15, 1.0, 0.72)
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.08, 0.48, 0.68, 0.82)
    material.roughness = 0.08
    material.metallic = 0.18
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water.material_override = material
    host.add_child(water)

func _add_reed_cluster(center, count):
    for i in range(count):
        var reed = MeshInstance3D.new()
        var stem = CylinderMesh.new()
        stem.top_radius = 0.018
        stem.bottom_radius = 0.035
        stem.height = 0.75 + float(i % 3) * 0.18
        reed.mesh = stem
        var spread = 0.18 + float(i % 4) * 0.12
        var angle = float(i) * 1.7
        reed.position = center + Vector3(cos(angle) * spread, stem.height * 0.5, sin(angle) * spread)
        reed.material_override = _mat(Color(0.12, 0.35, 0.15), 0.86)
        host.add_child(reed)

func _add_shrub(pos, scale_value):
    var root = Node3D.new()
    root.position = pos
    host.add_child(root)
    var trunk = MeshInstance3D.new()
    var trunk_mesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.11 * scale_value
    trunk_mesh.bottom_radius = 0.17 * scale_value
    trunk_mesh.height = 0.78 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position.y = 0.39 * scale_value
    trunk.material_override = _mat(Color(0.19, 0.12, 0.07), 0.95)
    root.add_child(trunk)
    for offset in [Vector3(-0.28, 0.82, 0.0), Vector3(0.28, 0.88, 0.10), Vector3(0.0, 1.06, -0.14)]:
        var crown = MeshInstance3D.new()
        var sphere = SphereMesh.new()
        sphere.radius = 0.5
        sphere.height = 1.0
        crown.mesh = sphere
        crown.position = offset * scale_value
        crown.scale = Vector3(0.72, 0.52, 0.68) * scale_value
        crown.material_override = _mat(Color(0.10, 0.32 + randf_range(0.0, 0.08), 0.13), 0.92)
        root.add_child(crown)

func _polish_ui():
    var ui_layer = host.get("ui_layer")
    var info_panel = host.get("info_panel")
    if ui_layer == null or info_panel == null:
        return

    info_panel.color = Color(0.0, 0.0, 0.0, 0.0)
    info_panel.offset_left = 24
    info_panel.offset_top = 20
    info_panel.offset_right = -24
    info_panel.offset_bottom = 146

    var backing = Panel.new()
    backing.name = "PremiumTopCard"
    backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backing.set_anchors_preset(Control.PRESET_FULL_RECT)
    backing.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.030, 0.028, 0.88), Color(0.27, 0.63, 0.47, 0.42), 18, 1))
    info_panel.add_child(backing)
    info_panel.move_child(backing, 0)

    var accent = ColorRect.new()
    accent.name = "AccentLine"
    accent.color = Color(0.34, 0.82, 0.60, 0.92)
    accent.position = Vector2(0, 0)
    accent.size = Vector2(6, 126)
    accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    info_panel.add_child(accent)
    info_panel.move_child(accent, 1)

    var bottom_card = Panel.new()
    bottom_card.name = "PremiumBottomCard"
    bottom_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_card.offset_left = 14
    bottom_card.offset_top = -188
    bottom_card.offset_right = -14
    bottom_card.offset_bottom = -10
    bottom_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_card.z_index = -10
    bottom_card.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.022, 0.020, 0.76), Color(0.20, 0.47, 0.36, 0.32), 20, 1))
    ui_layer.add_child(bottom_card)

    _style_control_tree(ui_layer)

func _style_control_tree(node):
    for child in node.get_children():
        if child is Button:
            _style_button(child)
        elif child is Label:
            child.add_theme_color_override("font_color", Color(0.94, 0.97, 0.94))
            child.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
            child.add_theme_constant_override("shadow_offset_x", 1)
            child.add_theme_constant_override("shadow_offset_y", 2)
        _style_control_tree(child)

func _style_button(button):
    var text_value = button.text.to_upper()
    var primary = text_value in ["FEED", "PET", "ENTER SANCTUARY", "SAVE NAME", "DONE"]
    var normal_color = Color(0.12, 0.34, 0.25, 0.96) if primary else Color(0.055, 0.075, 0.070, 0.94)
    var hover_color = Color(0.16, 0.46, 0.33, 0.98) if primary else Color(0.09, 0.13, 0.12, 0.98)
    var pressed_color = Color(0.09, 0.27, 0.20, 1.0) if primary else Color(0.035, 0.055, 0.050, 1.0)
    button.add_theme_stylebox_override("normal", _button_style(normal_color, Color(0.26, 0.62, 0.46, 0.32)))
    button.add_theme_stylebox_override("hover", _button_style(hover_color, Color(0.42, 0.86, 0.64, 0.62)))
    button.add_theme_stylebox_override("pressed", _button_style(pressed_color, Color(0.42, 0.86, 0.64, 0.82)))
    button.add_theme_stylebox_override("focus", _button_style(normal_color, Color(0.42, 0.86, 0.64, 0.82)))
    button.add_theme_color_override("font_color", Color(0.95, 0.98, 0.95))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 17)

func _button_style(bg, border):
    var style = StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _panel_style(bg, border, radius, width):
    var style = StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.border_width_left = width
    style.border_width_top = width
    style.border_width_right = width
    style.border_width_bottom = width
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style

func _polish_animals():
    for child in host.get_children():
        if not child.has_meta("animal_id"):
            continue
        var species_id = str(child.get("species_id"))
        if species_id == "pygmy_hippo":
            _upgrade_hippo(child)
        elif species_id == "pig":
            _upgrade_pig(child)
        elif species_id == "shar_pei":
            _upgrade_shar_pei(child)

func _upgrade_hippo(actor):
    var visual = actor.get_node_or_null("Visual")
    if visual == null:
        return
    _set_part(visual, "Body", Vector3(-0.30, 0.42, 0.0), Vector3(1.62, 1.02, 0.98))
    _set_part(visual, "Chest", Vector3(0.50, 0.50, 0.0), Vector3(0.92, 0.88, 0.84))
    _set_part(visual, "Head", Vector3(1.13, 0.63, 0.0), Vector3(0.90, 0.82, 0.80))
    _set_part(visual, "Muzzle", Vector3(1.76, 0.36, 0.0), Vector3(0.78, 0.50, 0.72))
    _sphere_part(visual, "LowerJaw", Vector3(1.68, 0.19, 0.0), Vector3(0.62, 0.24, 0.58), Color(0.55, 0.33, 0.40), 0.30)
    _sphere_part(visual, "BrowL", Vector3(1.38, 0.89, -0.35), Vector3(0.22, 0.13, 0.15), Color(0.31, 0.23, 0.29), 0.25)
    _sphere_part(visual, "BrowR", Vector3(1.38, 0.89, 0.35), Vector3(0.22, 0.13, 0.15), Color(0.31, 0.23, 0.29), 0.25)
    _sphere_part(visual, "CatchL", Vector3(1.505, 0.84, -0.458), Vector3(0.028, 0.028, 0.018), Color(0.96, 0.98, 1.0), 0.03)
    _sphere_part(visual, "CatchR", Vector3(1.505, 0.84, 0.458), Vector3(0.028, 0.028, 0.018), Color(0.96, 0.98, 1.0), 0.03)
    _toe_row(visual, 0.62, -0.84, 0.48, Color(0.20, 0.15, 0.18))

func _upgrade_pig(actor):
    var visual = actor.get_node_or_null("Visual")
    if visual == null:
        return
    _set_part(visual, "Body", Vector3(-0.25, 0.46, 0.0), Vector3(1.30, 0.78, 0.72))
    _set_part(visual, "Head", Vector3(0.93, 0.63, 0.0), Vector3(0.69, 0.64, 0.60))
    _set_part(visual, "Snout", Vector3(1.48, 0.49, 0.0), Vector3(0.44, 0.30, 0.43))
    _sphere_part(visual, "CheekL", Vector3(1.05, 0.52, -0.34), Vector3(0.30, 0.28, 0.22), Color(0.82, 0.54, 0.52), 0.48)
    _sphere_part(visual, "CheekR", Vector3(1.05, 0.52, 0.34), Vector3(0.30, 0.28, 0.22), Color(0.82, 0.54, 0.52), 0.48)
    _sphere_part(visual, "CatchL", Vector3(1.12, 0.79, -0.38), Vector3(0.022, 0.022, 0.016), Color.WHITE, 0.04)
    _sphere_part(visual, "CatchR", Vector3(1.12, 0.79, 0.38), Vector3(0.022, 0.022, 0.016), Color.WHITE, 0.04)

func _upgrade_shar_pei(actor):
    var visual = actor.get_node_or_null("Visual")
    if visual == null:
        return
    _set_part(visual, "Body", Vector3(-0.22, 0.58, 0.0), Vector3(1.14, 0.78, 0.70))
    _set_part(visual, "Shoulders", Vector3(0.40, 0.70, 0.0), Vector3(0.76, 0.80, 0.70))
    _set_part(visual, "Head", Vector3(0.93, 0.94, 0.0), Vector3(0.70, 0.69, 0.66))
    _sphere_part(visual, "Wrinkle1", Vector3(0.68, 1.25, 0.0), Vector3(0.55, 0.12, 0.58), Color(0.67, 0.44, 0.25), 0.78)
    _sphere_part(visual, "Wrinkle2", Vector3(0.84, 1.14, 0.0), Vector3(0.58, 0.11, 0.59), Color(0.64, 0.41, 0.23), 0.78)
    _sphere_part(visual, "CheekL", Vector3(1.22, 0.80, -0.31), Vector3(0.34, 0.32, 0.22), Color(0.56, 0.35, 0.21), 0.72)
    _sphere_part(visual, "CheekR", Vector3(1.22, 0.80, 0.31), Vector3(0.34, 0.32, 0.22), Color(0.56, 0.35, 0.21), 0.72)

func _set_part(visual, part_name, pos, scale_value):
    var part = visual.get_node_or_null(part_name)
    if part == null:
        return
    part.position = pos
    part.scale = scale_value

func _sphere_part(visual, part_name, pos, scale_value, color, roughness):
    if visual.get_node_or_null(part_name) != null:
        return
    var part = MeshInstance3D.new()
    part.name = part_name
    var sphere = SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    part.mesh = sphere
    part.position = pos
    part.scale = scale_value
    part.material_override = _mat(color, roughness)
    visual.add_child(part)

func _toe_row(visual, front_x, rear_x, z_value, color):
    var index = 0
    for x in [front_x, rear_x]:
        for z in [-z_value, z_value]:
            _sphere_part(visual, "Toe%dA" % index, Vector3(x + 0.18, -0.28, z - 0.07), Vector3(0.13, 0.07, 0.10), color, 0.58)
            _sphere_part(visual, "Toe%dB" % index, Vector3(x + 0.18, -0.28, z + 0.07), Vector3(0.13, 0.07, 0.10), color, 0.58)
            index += 1

func _apply_selection_focus(force_update):
    var selected_id = str(host.get("selected_id"))
    if not force_update and selected_id == last_selected:
        return
    last_selected = selected_id
    for child in host.get_children():
        if child.has_meta("animal_id"):
            child.visible = str(child.get_meta("animal_id")) == selected_id

    var actor = host.get("animals").get(selected_id, null)
    if actor == null:
        return
    var species_id = str(actor.get("species_id"))
    if species_id == "pygmy_hippo":
        host.set("orbit_distance", 5.45)
    else:
        host.set("orbit_distance", 4.85)
    var camera = host.get("camera")
    if camera != null:
        camera.fov = 42.0

func _mat(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
