extends Node

# Premium presentation layer for Hippo OS.
# It deliberately leaves simulation and Android packaging untouched and focuses on
# camera composition, habitat dressing and a cleaner app-like interface.

const POND_POS := Vector3(3.7, 0.8, 2.5)
const REST_POS := Vector3(-4.6, 0.8, -3.2)
const FEED_POS := Vector3(4.7, 0.8, -2.9)

var scene_root: Node3D
var camera: Camera3D
var roster: Node
var world_root: Node3D
var focus_ring: MeshInstance3D
var focus_material: StandardMaterial3D
var focus_position := Vector3.ZERO
var focus_initialized := false
var restyle_timer := 0.0
var styled_buttons: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 150
    set_process(false)
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
    _build_world_finish()
    _restyle_interface()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null:
        return

    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
    if roster == null or not is_instance_valid(roster):
        roster = get_node_or_null("/root/CompanionRoster")

    _update_selected_focus(delta)

    restyle_timer -= delta
    if restyle_timer <= 0.0:
        restyle_timer = 0.8
        _restyle_interface()

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null

func _build_world_finish() -> void:
    var old_root := scene_root.find_child("PremiumExperienceWorld", true, false)
    if is_instance_valid(old_root):
        old_root.queue_free()

    world_root = Node3D.new()
    world_root.name = "PremiumExperienceWorld"
    scene_root.add_child(world_root)

    _build_ground_finish()
    _build_pond_edge()
    _build_reeds()
    _build_rest_shelter()
    _build_enrichment_station()
    _build_feed_finish()
    _build_focus_ring()

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
    float m = clamp(a * 0.45 + b * 0.35, 0.0, 1.0);
    vec3 dark_grass = vec3(0.055, 0.17, 0.075);
    vec3 mid_grass = vec3(0.085, 0.26, 0.11);
    vec3 warm_grass = vec3(0.13, 0.30, 0.115);
    ALBEDO = mix(dark_grass, mid_grass, m);
    ALBEDO = mix(ALBEDO, warm_grass, smoothstep(0.72, 1.0, b) * 0.22);
    ROUGHNESS = 0.95;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    ground.material_override = material
    world_root.add_child(ground)

    _add_ground_patch(Vector3(-2.8, 0.028, -1.2), Vector3(2.8, 0.02, 1.20), Color(0.14, 0.23, 0.085))
    _add_ground_patch(Vector3(1.2, 0.027, -2.7), Vector3(2.1, 0.02, 0.92), Color(0.11, 0.20, 0.075))
    _add_ground_patch(Vector3(-4.6, 0.027, 1.3), Vector3(1.2, 0.02, 0.72), Color(0.17, 0.22, 0.075))

func _add_ground_patch(position: Vector3, scale_value: Vector3, color: Color) -> void:
    var patch := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 1.0
    patch.mesh = mesh
    patch.position = position
    patch.scale = scale_value
    patch.material_override = _material(color, 0.97)
    world_root.add_child(patch)

func _build_pond_edge() -> void:
    var dry_stone := _material(Color(0.28, 0.30, 0.27), 0.92)
    var wet_stone := _material(Color(0.17, 0.22, 0.22), 0.74)

    for i in range(16):
        var angle := TAU * float(i) / 16.0
        var rock := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.5
        mesh.height = 1.0
        rock.mesh = mesh
        var radius_x := 3.16 + sin(float(i) * 1.7) * 0.16
        var radius_z := 2.20 + cos(float(i) * 1.3) * 0.14
        rock.position = Vector3(POND_POS.x + cos(angle) * radius_x, 0.16, POND_POS.z + sin(angle) * radius_z)
        rock.scale = Vector3(0.34 + float(i % 4) * 0.055, 0.20 + float(i % 3) * 0.040, 0.30 + float((i + 2) % 4) * 0.045)
        rock.rotation.y = angle + float(i) * 0.17
        rock.material_override = wet_stone if i % 3 == 0 else dry_stone
        world_root.add_child(rock)

    var fallen_log := MeshInstance3D.new()
    var log_mesh := CylinderMesh.new()
    log_mesh.top_radius = 0.17
    log_mesh.bottom_radius = 0.21
    log_mesh.height = 2.65
    fallen_log.mesh = log_mesh
    fallen_log.rotation_degrees = Vector3(0.0, 0.0, 88.0)
    fallen_log.position = Vector3(POND_POS.x - 1.65, 0.24, POND_POS.z - 1.65)
    fallen_log.material_override = _material(Color(0.24, 0.13, 0.065), 0.95)
    world_root.add_child(fallen_log)

func _build_reeds() -> void:
    var stem_material := _material(Color(0.10, 0.31, 0.10), 0.96)
    var tip_material := _material(Color(0.30, 0.19, 0.075), 0.92)
    var origins: Array[Vector3] = [
        Vector3(POND_POS.x - 2.55, 0.0, POND_POS.z + 0.62),
        Vector3(POND_POS.x + 2.38, 0.0, POND_POS.z - 0.58),
        Vector3(POND_POS.x + 1.25, 0.0, POND_POS.z + 1.66)
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
            stem.rotation.z = sin(float(i) * 1.7) * 0.08
            stem.material_override = stem_material
            world_root.add_child(stem)

            if i % 2 == 0:
                var tip := MeshInstance3D.new()
                var tip_mesh := SphereMesh.new()
                tip.mesh = tip_mesh
                tip.scale = Vector3(0.045, 0.10, 0.045)
                tip.position = stem.position + Vector3(0.0, stem_mesh.height * 0.52, 0.0)
                tip.material_override = tip_material
                world_root.add_child(tip)

func _build_rest_shelter() -> void:
    var timber := _material(Color(0.22, 0.12, 0.06), 0.96)
    var post_offsets: Array[Vector3] = [
        Vector3(-0.80, 0.0, -0.55),
        Vector3(0.80, 0.0, -0.55),
        Vector3(-0.80, 0.0, 0.55),
        Vector3(0.80, 0.0, 0.55)
    ]

    for offset in post_offsets:
        var post := MeshInstance3D.new()
        var post_mesh := CylinderMesh.new()
        post_mesh.top_radius = 0.09
        post_mesh.bottom_radius = 0.11
        post_mesh.height = 1.35
        post.mesh = post_mesh
        post.position = REST_POS + offset + Vector3(0.0, 0.675, 0.0)
        post.material_override = timber
        world_root.add_child(post)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(1.95, 0.09, 1.45)
    roof.mesh = roof_mesh
    roof.position = REST_POS + Vector3(0.0, 1.34, 0.0)
    roof.rotation_degrees.z = -4.0
    roof.material_override = _material(Color(0.16, 0.25, 0.095), 0.94)
    world_root.add_child(roof)

    _add_ground_patch(REST_POS + Vector3(0.0, -0.69, 0.0), Vector3(1.25, 0.025, 0.86), Color(0.34, 0.32, 0.16))

func _build_enrichment_station() -> void:
    var timber := _material(Color(0.29, 0.16, 0.075), 0.95)
    var offsets: Array[Vector3] = [Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0)]

    for offset in offsets:
        var post := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.10
        mesh.bottom_radius = 0.13
        mesh.height = 1.45
        post.mesh = mesh
        post.position = Vector3(0.15, 0.72, 3.95) + offset
        post.material_override = timber
        world_root.add_child(post)

    var crossbar := MeshInstance3D.new()
    var cross_mesh := CylinderMesh.new()
    cross_mesh.top_radius = 0.08
    cross_mesh.bottom_radius = 0.08
    cross_mesh.height = 1.65
    crossbar.mesh = cross_mesh
    crossbar.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    crossbar.position = Vector3(0.15, 1.38, 3.95)
    crossbar.material_override = timber
    world_root.add_child(crossbar)

    var hanging_toy := MeshInstance3D.new()
    var toy_mesh := SphereMesh.new()
    hanging_toy.mesh = toy_mesh
    hanging_toy.scale = Vector3(0.24, 0.24, 0.24)
    hanging_toy.position = Vector3(0.15, 0.66, 3.95)
    hanging_toy.material_override = _material(Color(0.72, 0.34, 0.12), 0.70)
    world_root.add_child(hanging_toy)

    var rope := MeshInstance3D.new()
    var rope_mesh := CylinderMesh.new()
    rope_mesh.top_radius = 0.025
    rope_mesh.bottom_radius = 0.025
    rope_mesh.height = 0.58
    rope.mesh = rope_mesh
    rope.position = Vector3(0.15, 1.03, 3.95)
    rope.material_override = _material(Color(0.49, 0.38, 0.21), 0.98)
    world_root.add_child(rope)

func _build_feed_finish() -> void:
    _add_ground_patch(Vector3(FEED_POS.x, 0.035, FEED_POS.z), Vector3(1.15, 0.035, 0.82), Color(0.21, 0.25, 0.17))

    for i in range(3):
        var vegetable := MeshInstance3D.new()
        var veg_mesh := SphereMesh.new()
        vegetable.mesh = veg_mesh
        vegetable.scale = Vector3(0.17 + float(i) * 0.025, 0.11, 0.12)
        vegetable.position = Vector3(FEED_POS.x - 0.35 + float(i) * 0.32, 0.20, FEED_POS.z + 0.05 * float(i % 2))
        vegetable.material_override = _material(Color(0.12 + float(i) * 0.05, 0.42, 0.10), 0.87)
        world_root.add_child(vegetable)

func _build_focus_ring() -> void:
    focus_ring = MeshInstance3D.new()
    focus_ring.name = "SelectedCompanionFocus"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.78
    ring_mesh.outer_radius = 0.84
    ring_mesh.rings = 32
    ring_mesh.ring_segments = 8
    focus_ring.mesh = ring_mesh
    focus_ring.scale = Vector3(1.0, 0.24, 1.0)

    focus_material = StandardMaterial3D.new()
    focus_material.albedo_color = Color(0.70, 0.90, 0.75, 0.48)
    focus_material.emission_enabled = true
    focus_material.emission = Color(0.24, 0.62, 0.38)
    focus_material.emission_energy_multiplier = 0.45
    focus_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    focus_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    focus_ring.material_override = focus_material
    world_root.add_child(focus_ring)

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
    var selected_node := data.get("node") as Node3D
    if selected_node == null or not is_instance_valid(selected_node):
        return

    var target := selected_node.global_position
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

    # main.gd rebuilds the orbit around the sanctuary centre first.
    # Offset that completed orbit so the chosen companion becomes the subject
    # while drag/orbit controls remain owned by the mature main controller.
    if is_instance_valid(camera):
        camera.global_position += Vector3(focus_position.x * 0.42, 0.0, focus_position.z * 0.42)
        camera.look_at(focus_position + Vector3(0.0, 0.40, 0.0), Vector3.UP)
        camera.fov = lerpf(camera.fov, 48.0, clampf(delta * 2.5, 0.0, 1.0))

func _restyle_interface() -> void:
    if scene_root == null:
        return

    var controls := scene_root.find_children("*", "Control", true, false)
    for node in controls:
        if node is Button:
            _style_button(node as Button)

    var stats_panel := scene_root.get("stats_panel") as Control
    if stats_panel is ColorRect:
        (stats_panel as ColorRect).color = Color(0.016, 0.024, 0.030, 0.88)
        stats_panel.size.y = 126.0

    var companion_ui := scene_root.find_child("CompanionRosterUI", true, false)
    if is_instance_valid(companion_ui):
        var panels := companion_ui.find_children("*", "ColorRect", true, false)
        for panel in panels:
            if panel is ColorRect:
                (panel as ColorRect).color = Color(0.016, 0.026, 0.032, 0.96)

    var labels := scene_root.find_children("*", "Label", true, false)
    for label_node in labels:
        var label := label_node as Label
        if label == null:
            continue
        if label.text == "HIPPO OS":
            label.text = "HIPPO OS  •  SANCTUARY"
            label.add_theme_font_size_override("font_size", 27)
        elif label.text.begins_with("Pet by dragging"):
            label.text = "DRAG TO ORBIT  •  OPEN COMPANIONS TO CHOOSE"
            label.add_theme_font_size_override("font_size", 14)
            label.modulate = Color(0.86, 0.91, 0.88, 0.78)

    var buttons := scene_root.find_children("*", "Button", true, false)
    for button_node in buttons:
        var button := button_node as Button
        if button != null and button.text == "ANIMALS":
            button.text = "COMPANIONS"

func _style_button(button: Button) -> void:
    var key := str(button.get_instance_id())
    if styled_buttons.has(key):
        return
    styled_buttons[key] = true

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.042, 0.058, 0.064, 0.95)
    normal.border_color = Color(0.18, 0.30, 0.25, 0.84)
    normal.border_width_left = 1
    normal.border_width_top = 1
    normal.border_width_right = 1
    normal.border_width_bottom = 1
    normal.corner_radius_top_left = 12
    normal.corner_radius_top_right = 12
    normal.corner_radius_bottom_left = 12
    normal.corner_radius_bottom_right = 12
    normal.content_margin_left = 14.0
    normal.content_margin_right = 14.0
    normal.content_margin_top = 8.0
    normal.content_margin_bottom = 8.0

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.072, 0.105, 0.092, 0.97)
    hover.border_color = Color(0.34, 0.58, 0.44, 0.95)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.10, 0.15, 0.12, 0.99)
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
