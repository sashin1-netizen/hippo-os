extends Node

# Premium presentation layer for the personal sanctuary build.
# Keeps simulation and installer systems untouched while improving composition,
# habitat dressing, selected-animal focus and the overall app chrome.

const POND_POS := Vector3(3.7, 0.8, 2.5)
const MUD_POS := Vector3(-3.7, 0.8, 2.8)
const REST_POS := Vector3(-4.6, 0.8, -3.2)
const FEED_POS := Vector3(4.7, 0.8, -2.9)

var scene_root: Node3D
var camera: Camera3D
var roster: Node
var presentation_root: Node3D
var focus_ring: MeshInstance3D
var focus_material: StandardMaterial3D
var focus_position := Vector3.ZERO
var focus_initialized := false
var ui_timer := 0.0
var night_glow: Array[Dictionary] = []
var styled_controls := {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 150
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(180):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            break
        await get_tree().process_frame
    if scene_root == null:
        push_warning("PremiumExperience could not bind to the sanctuary scene")
        return

    camera = _find_camera(scene_root)
    roster = get_node_or_null("/root/CompanionRoster")
    _build_presentation_world()
    _style_all_ui()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null:
        return
    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
    if roster == null or not is_instance_valid(roster):
        roster = get_node_or_null("/root/CompanionRoster")

    _update_selected_focus(delta)
    _animate_night_glow()

    ui_timer -= delta
    if ui_timer <= 0.0:
        ui_timer = 0.8
        _style_all_ui()

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null

func _build_presentation_world() -> void:
    var existing := scene_root.find_child("PremiumExperienceWorld", true, false)
    if is_instance_valid(existing):
        existing.queue_free()

    presentation_root = Node3D.new()
    presentation_root.name = "PremiumExperienceWorld"
    scene_root.add_child(presentation_root)

    _build_ground_finish()
    _build_shoreline()
    _build_enrichment()
    _build_reed_beds()
    _build_rest_grove()
    _build_feed_station()
    _build_focus_ring()
    _build_night_glow()

func _build_ground_finish() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "SanctuaryGroundFinish"
    var plane := PlaneMesh.new()
    plane.size = Vector2(17.7, 13.7)
    plane.subdivide_width = 12
    plane.subdivide_depth = 10
    ground.mesh = plane
    ground.position.y = 0.012

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
    float broad = sin(VERTEX.x * 0.48) * cos(VERTEX.z * 0.42);
    float fine = sin(VERTEX.x * 2.1 + VERTEX.z * 1.7) * 0.5;
    VERTEX.y += broad * 0.018 + fine * 0.006;
}
void fragment() {
    float a = sin(UV.x * 31.0 + UV.y * 17.0) * 0.5 + 0.5;
    float b = cos(UV.x * 13.0 - UV.y * 29.0) * 0.5 + 0.5;
    float texture_mix = clamp(a * 0.45 + b * 0.35, 0.0, 1.0);
    vec3 grass_dark = vec3(0.055, 0.185, 0.085);
    vec3 grass_mid = vec3(0.095, 0.285, 0.125);
    vec3 grass_warm = vec3(0.145, 0.315, 0.125);
    ALBEDO = mix(grass_dark, grass_mid, texture_mix);
    ALBEDO = mix(ALBEDO, grass_warm, smoothstep(0.72, 1.0, b) * 0.26);
    ROUGHNESS = 0.94;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    ground.material_override = material
    presentation_root.add_child(ground)

    _terrain_patch(Vector3(-2.8, 0.027, -1.2), Vector3(2.9, 0.02, 1.25), Color(0.17, 0.25, 0.095), 0.95)
    _terrain_patch(Vector3(1.2, 0.026, -2.6), Vector3(2.2, 0.02, 0.95), Color(0.13, 0.22, 0.08), 0.96)
    _terrain_patch(Vector3(-4.7, 0.026, 1.4), Vector3(1.25, 0.02, 0.75), Color(0.18, 0.23, 0.08), 0.97)

func _terrain_patch(position: Vector3, scale_value: Vector3, color: Color, roughness: float) -> void:
    var patch := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 1.0
    patch.mesh = mesh
    patch.position = position
    patch.scale = scale_value
    patch.material_override = _material(color, roughness)
    presentation_root.add_child(patch)

func _build_shoreline() -> void:
    var stone_material := _material(Color(0.28, 0.30, 0.27), 0.92)
    var wet_stone := _material(Color(0.18, 0.23, 0.23), 0.72)
    for i in range(15):
        var angle := TAU * float(i) / 15.0
        var rock := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.5
        mesh.height = 1.0
        rock.mesh = mesh
        var radius_x := 3.15 + sin(float(i) * 1.7) * 0.18
        var radius_z := 2.2 + cos(float(i) * 1.3) * 0.15
        rock.position = Vector3(POND_POS.x + cos(angle) * radius_x, 0.17, POND_POS.z + sin(angle) * radius_z)
        rock.scale = Vector3(0.38 + float(i % 4) * 0.055, 0.22 + float(i % 3) * 0.045, 0.32 + float((i + 2) % 4) * 0.045)
        rock.rotation.y = angle + float(i) * 0.17
        rock.material_override = wet_stone if i % 3 == 0 else stone_material
        presentation_root.add_child(rock)

    var log := MeshInstance3D.new()
    var log_mesh := CylinderMesh.new()
    log_mesh.top_radius = 0.17
    log_mesh.bottom_radius = 0.21
    log_mesh.height = 2.7
    log.mesh = log_mesh
    log.rotation_degrees = Vector3(0.0, 0.0, 88.0)
    log.position = Vector3(POND_POS.x - 1.6, 0.23, POND_POS.z - 1.65)
    log.material_override = _material(Color(0.25, 0.13, 0.065), 0.94)
    presentation_root.add_child(log)

func _build_enrichment() -> void:
    var wood := _material(Color(0.30, 0.17, 0.08), 0.94)
    var rope := _material(Color(0.50, 0.39, 0.22), 0.98)

    for x in [-1.0, 1.0]:
        var post := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.10
        mesh.bottom_radius = 0.13
        mesh.height = 1.45
        post.mesh = mesh
        post.position = Vector3(0.15 + x * 0.75, 0.72, 3.95)
        post.material_override = wood
        presentation_root.add_child(post)

    var bar := MeshInstance3D.new()
    var bar_mesh := CylinderMesh.new()
    bar_mesh.top_radius = 0.08
    bar_mesh.bottom_radius = 0.08
    bar_mesh.height = 1.65
    bar.mesh = bar_mesh
    bar.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    bar.position = Vector3(0.15, 1.38, 3.95)
    bar.material_override = wood
    presentation_root.add_child(bar)

    var toy := MeshInstance3D.new()
    var toy_mesh := SphereMesh.new()
    toy.mesh = toy_mesh
    toy.scale = Vector3(0.24, 0.24, 0.24)
    toy.position = Vector3(0.15, 0.66, 3.95)
    toy.material_override = _material(Color(0.72, 0.34, 0.12), 0.68)
    presentation_root.add_child(toy)

    var rope_line := MeshInstance3D.new()
    var rope_mesh := CylinderMesh.new()
    rope_mesh.top_radius = 0.025
    rope_mesh.bottom_radius = 0.025
    rope_mesh.height = 0.58
    rope_line.mesh = rope_mesh
    rope_line.position = Vector3(0.15, 1.03, 3.95)
    rope_line.material_override = rope
    presentation_root.add_child(rope_line)

func _build_reed_beds() -> void:
    var reed_green := _material(Color(0.12, 0.34, 0.12), 0.96)
    var reed_tip := _material(Color(0.31, 0.20, 0.08), 0.92)
    var origins := [
        Vector3(POND_POS.x - 2.55, 0.0, POND_POS.z + 0.65),
        Vector3(POND_POS.x + 2.35, 0.0, POND_POS.z - 0.65),
        Vector3(POND_POS.x + 1.3, 0.0, POND_POS.z + 1.65)
    ]
    for origin in origins:
        for i in range(7):
            var angle := float(i) * 2.31
            var offset := Vector3(cos(angle) * (0.12 + float(i % 3) * 0.09), 0.0, sin(angle) * (0.10 + float((i + 1) % 3) * 0.08))
            var stem := MeshInstance3D.new()
            var stem_mesh := CylinderMesh.new()
            stem_mesh.top_radius = 0.018
            stem_mesh.bottom_radius = 0.028
            stem_mesh.height = 0.62 + float(i % 4) * 0.11
            stem.mesh = stem_mesh
            stem.position = origin + offset + Vector3(0.0, stem_mesh.height * 0.5, 0.0)
            stem.rotation.z = sin(float(i) * 1.7) * 0.09
            stem.material_override = reed_green
            presentation_root.add_child(stem)
            if i % 2 == 0:
                var tip := MeshInstance3D.new()
                var tip_mesh := SphereMesh.new()
                tip.mesh = tip_mesh
                tip.scale = Vector3(0.045, 0.10, 0.045)
                tip.position = stem.position + Vector3(0.0, stem_mesh.height * 0.52, 0.0)
                tip.material_override = reed_tip
                presentation_root.add_child(tip)

func _build_rest_grove() -> void:
    var posts: Array[Vector3] = [
        REST_POS + Vector3(-0.8, 0.0, -0.55),
        REST_POS + Vector3(0.8, 0.0, -0.55),
        REST_POS + Vector3(-0.8, 0.0, 0.55),
        REST_POS + Vector3(0.8, 0.0, 0.55)
    ]
    var timber := _material(Color(0.22, 0.12, 0.06), 0.95)
    for base in posts:
        var post := MeshInstance3D.new()
        var post_mesh := CylinderMesh.new()
        post_mesh.top_radius = 0.09
        post_mesh.bottom_radius = 0.11
        post_mesh.height = 1.35
        post.mesh = post_mesh
        post.position = base + Vector3(0.0, 0.675, 0.0)
        post.material_override = timber
        presentation_root.add_child(post)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(1.95, 0.09, 1.45)
    roof.mesh = roof_mesh
    roof.position = REST_POS + Vector3(0.0, 1.34, 0.0)
    roof.rotation_degrees.z = -4.0
    roof.material_override = _material(Color(0.18, 0.27, 0.10), 0.92)
    presentation_root.add_child(roof)

    var bedding := MeshInstance3D.new()
    var bed_mesh := CylinderMesh.new()
    bed_mesh.top_radius = 1.0
    bed_mesh.bottom_radius = 1.0
    bed_mesh.height = 1.0
    bedding.mesh = bed_mesh
    bedding.position = REST_POS + Vector3(0.0, -0.69, 0.0)
    bedding.scale = Vector3(1.25, 0.025, 0.86)
    bedding.material_override = _material(Color(0.36, 0.34, 0.17), 0.98)
    presentation_root.add_child(bedding)

func _build_feed_station() -> void:
    var pad := MeshInstance3D.new()
    var pad_mesh := CylinderMesh.new()
    pad_mesh.top_radius = 1.0
    pad_mesh.bottom_radius = 1.0
    pad_mesh.height = 1.0
    pad.mesh = pad_mesh
    pad.position = Vector3(FEED_POS.x, 0.035, FEED_POS.z)
    pad.scale = Vector3(1.15, 0.035, 0.82)
    pad.material_override = _material(Color(0.22, 0.26, 0.18), 0.94)
    presentation_root.add_child(pad)

    for i in range(3):
        var vegetable := MeshInstance3D.new()
        var veg_mesh := SphereMesh.new()
        vegetable.mesh = veg_mesh
        vegetable.scale = Vector3(0.17 + float(i) * 0.025, 0.11, 0.12)
        vegetable.position = Vector3(FEED_POS.x - 0.35 + float(i) * 0.32, 0.20, FEED_POS.z + 0.05 * float(i % 2))
        vegetable.material_override = _material(Color(0.12 + float(i) * 0.05, 0.42, 0.10), 0.86)
        presentation_root.add_child(vegetable)

func _build_focus_ring() -> void:
    focus_ring = MeshInstance3D.new()
    focus_ring.name = "SelectedCompanionFocus"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.78
    mesh.outer_radius = 0.84
    mesh.rings = 32
    mesh.ring_segments = 8
    focus_ring.mesh = mesh
    focus_ring.scale = Vector3(1.0, 0.25, 1.0)
    focus_material = StandardMaterial3D.new()
    focus_material.albedo_color = Color(0.78, 0.90, 0.78, 0.50)
    focus_material.emission_enabled = true
    focus_material.emission = Color(0.22, 0.55, 0.34)
    focus_material.emission_energy_multiplier = 0.45
    focus_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    focus_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    focus_ring.material_override = focus_material
    focus_ring.position = Vector3(0.0, 0.075, 0.0)
    presentation_root.add_child(focus_ring)

func _build_night_glow() -> void:
    var glow_material := StandardMaterial3D.new()
    glow_material.albedo_color = Color(0.78, 0.92, 0.48, 0.72)
    glow_material.emission_enabled = true
    glow_material.emission = Color(0.62, 0.90, 0.30)
    glow_material.emission_energy_multiplier = 1.2
    glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

    for i in range(14):
        var glow := MeshInstance3D.new()
        var glow_mesh := SphereMesh.new()
        glow.mesh = glow_mesh
        glow.scale = Vector3(0.035, 0.035, 0.035)
        var angle := TAU * float(i) / 14.0 + 0.27
        var radius := 3.2 + float(i % 5) * 0.52
        glow.position = Vector3(cos(angle) * radius, 0.55 + float(i % 4) * 0.27, sin(angle) * radius * 0.72)
        glow.material_override = glow_material
        presentation_root.add_child(glow)
        night_glow.append({"node": glow, "base": glow.position, "phase": float(i) * 0.83})

func _update_selected_focus(delta: float) -> void:
    if roster == null:
        return
    var species := str(roster.get("selected_species"))
    var companions_variant := roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return
    var companions: Dictionary = companions_variant
    if not companions.has(species):
        return
    var data_variant := companions.get(species)
    if typeof(data_variant) != TYPE_DICTIONARY:
        return
    var data: Dictionary = data_variant
    var node := data.get("node") as Node3D
    if node == null or not is_instance_valid(node):
        return

    var target := node.global_position
    target.y = 0.82
    if not focus_initialized:
        focus_position = target
        focus_initialized = true
    else:
        focus_position = focus_position.lerp(target, clampf(delta * 4.6, 0.0, 1.0))

    if is_instance_valid(focus_ring):
        focus_ring.global_position = Vector3(focus_position.x, 0.08, focus_position.z)
        var now := float(Time.get_ticks_msec()) / 1000.0
        var pulse := 1.0 + sin(now * 2.6) * 0.055
        focus_ring.scale = Vector3(pulse, 0.24, pulse)
        if is_instance_valid(focus_material):
            var accent: Color = data.get("accent", Color(0.62, 0.86, 0.67))
            accent.a = 0.46
            focus_material.albedo_color = accent
            focus_material.emission = Color(accent.r, accent.g, accent.b, 1.0)

    # main.gd rebuilds the orbit around the sanctuary centre every frame.
    # Offset that already-calculated orbit after it runs so the selected animal
    # becomes the visual subject without breaking drag/orbit input.
    if is_instance_valid(camera):
        camera.global_position += Vector3(focus_position.x * 0.42, 0.0, focus_position.z * 0.42)
        camera.look_at(focus_position + Vector3(0.0, 0.40, 0.0), Vector3.UP)
        camera.fov = lerpf(camera.fov, 48.0, clampf(delta * 2.5, 0.0, 1.0))

func _animate_night_glow() -> void:
    var daylight := _daylight_amount()
    var alpha := clampf((0.58 - daylight) * 2.0, 0.0, 1.0)
    var now := float(Time.get_ticks_msec()) / 1000.0
    for entry in night_glow:
        var node := entry.get("node") as MeshInstance3D
        if not is_instance_valid(node):
            continue
        var base: Vector3 = entry.get("base", node.position)
        var phase := float(entry.get("phase", 0.0))
        node.position = base + Vector3(sin(now * 0.48 + phase) * 0.16, sin(now * 0.92 + phase) * 0.08, cos(now * 0.43 + phase) * 0.12)
        node.visible = alpha > 0.04
        node.modulate.a = alpha * (0.58 + sin(now * 1.6 + phase) * 0.22)

func _daylight_amount() -> float:
    var settings_variant := scene_root.get("settings")
    var mode := "auto"
    if typeof(settings_variant) == TYPE_DICTIONARY:
        mode = str((settings_variant as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var hour := float(Time.get_time_dict_from_system().get("hour", 12))
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _style_all_ui() -> void:
    if scene_root == null:
        return
    var controls := scene_root.find_children("*", "Control", true, false)
    for node in controls:
        if node is Button:
            _style_button(node as Button)

    var stats_panel := scene_root.get("stats_panel") as Control
    if stats_panel is ColorRect:
        (stats_panel as ColorRect).color = Color(0.018, 0.027, 0.032, 0.88)
        stats_panel.size.y = 126.0

    var companion_ui := scene_root.find_child("CompanionRosterUI", true, false)
    if is_instance_valid(companion_ui):
        var panels := companion_ui.find_children("*", "ColorRect", true, false)
        for panel in panels:
            if panel is ColorRect:
                (panel as ColorRect).color = Color(0.018, 0.028, 0.034, 0.96)

    var help_labels := scene_root.find_children("*", "Label", true, false)
    for label_node in help_labels:
        var label := label_node as Label
        if label == null:
            continue
        if label.text.begins_with("Pet by dragging"):
            label.text = "DRAG TO ORBIT  •  TAP ANIMALS TO CHOOSE A COMPANION"
            label.add_theme_font_size_override("font_size", 14)
            label.modulate = Color(0.86, 0.91, 0.88, 0.78)

func _style_button(button: Button) -> void:
    var key := str(button.get_instance_id())
    if styled_controls.has(key):
        return
    styled_controls[key] = true

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.045, 0.060, 0.067, 0.94)
    normal.border_color = Color(0.19, 0.30, 0.26, 0.82)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    normal.content_margin_left = 14.0
    normal.content_margin_right = 14.0
    normal.content_margin_top = 8.0
    normal.content_margin_bottom = 8.0

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.075, 0.105, 0.095, 0.96)
    hover.border_color = Color(0.34, 0.58, 0.44, 0.95)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.105, 0.155, 0.125, 0.98)
    pressed.border_color = Color(0.48, 0.73, 0.56, 1.0)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.93))
    button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
    button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
