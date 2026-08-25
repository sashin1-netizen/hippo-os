extends Node

# Final portrait presentation authority for the personal Android build.
# This pass runs after the legacy/polish layers, keeps the simulation live, and fixes
# the phone-specific problems visible in device evidence: excessive empty sky, tiny
# hero subject, intrusive foreground primitives and oversized HUD chrome.

const HERO_HOME := Vector3(-0.30, 0.80, 0.00)
const PIG_HOME := Vector3(-3.25, 0.72, 1.55)
const DOG_HOME := Vector3(-3.45, 0.75, -1.55)

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var stage_root: Node3D
var finish_root: Node3D
var hud: Node
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var built := false
var scenery_timer := 0.0
var ui_timer := 0.0
var framing_timer := 0.0
var smoothed_focus := Vector3.ZERO
var focus_initialized := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 2000000
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(720):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        var hud_candidate := get_node_or_null("/root/SanctuaryHUD")
        if candidate is Node3D and roster_candidate != null and hud_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            hud = hud_candidate
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            stage_root = scene_root.find_child("CleanSanctuaryStage", true, false) as Node3D
            if camera != null and hippo != null and pig != null and dog != null and stage_root != null:
                break
        await get_tree().process_frame

    if scene_root == null or roster == null or camera == null or stage_root == null:
        push_warning("PortraitSanctuaryV2 could not bind to the live sanctuary")
        return

    # Allow asynchronous scene builders to finish, then replace only their rendered
    # stage. Animal nodes, collision, state, audio and interactions stay untouched.
    for _frame in range(18):
        await get_tree().process_frame

    _build_world_finish()
    _remove_intrusive_geometry()
    _stage_companions(true)
    _apply_compact_hud()
    built = true
    set_process(true)

func _process(delta: float) -> void:
    if not built or scene_root == null:
        return

    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return

    scenery_timer -= delta
    ui_timer -= delta
    framing_timer -= delta

    if scenery_timer <= 0.0:
        scenery_timer = 0.30
        _remove_intrusive_geometry()
        _stage_companions(false)
        _keep_finish_visible()

    if ui_timer <= 0.0:
        ui_timer = 0.35
        _apply_compact_hud()

    if framing_timer <= 0.0:
        framing_timer = 0.05
        _apply_camera_frame(delta)

func _build_world_finish() -> void:
    var old := stage_root.find_child("PortraitSanctuaryV2World", false, false)
    if old != null:
        old.queue_free()
        await get_tree().process_frame

    # Hide the crude clean-stage primitives; keep this replacement under the same
    # authoritative stage root so CleanSanctuaryStage does not classify it as legacy.
    for child in stage_root.get_children():
        if child is Node3D:
            (child as Node3D).visible = false

    finish_root = Node3D.new()
    finish_root.name = "PortraitSanctuaryV2World"
    stage_root.add_child(finish_root)

    _add_terrain()
    _add_water()
    _add_distant_landscape()
    _add_trees_and_shrubs()
    _add_grass_field()
    _add_rocks()

func _add_terrain() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "NaturalGrasslandTerrain"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(30.0, 24.0)
    mesh.subdivide_width = 72
    mesh.subdivide_depth = 58
    ground.mesh = mesh
    ground.position = Vector3(-4.0, 0.01, 0.0)

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled;
varying float terrain_noise;
void vertex() {
    float broad = sin(VERTEX.x * 0.22) * cos(VERTEX.z * 0.25);
    float fine = sin(VERTEX.x * 0.83 + VERTEX.z * 0.61) * 0.35;
    terrain_noise = broad * 0.65 + fine * 0.35;
    VERTEX.y += terrain_noise * 0.075;
}
void fragment() {
    float a = sin(UV.x * 46.0 + UV.y * 19.0) * 0.5 + 0.5;
    float b = cos(UV.y * 57.0 - UV.x * 13.0) * 0.5 + 0.5;
    float variation = clamp(a * 0.58 + b * 0.42, 0.0, 1.0);
    vec3 deep_grass = vec3(0.055, 0.135, 0.045);
    vec3 living_grass = vec3(0.105, 0.245, 0.070);
    vec3 sun_grass = vec3(0.195, 0.285, 0.095);
    vec3 soil = vec3(0.235, 0.165, 0.090);
    vec3 base = mix(deep_grass, living_grass, variation);
    base = mix(base, sun_grass, smoothstep(0.70, 1.0, b) * 0.34);
    float worn = smoothstep(0.77, 0.96, sin((UV.x + UV.y) * 18.0) * 0.5 + 0.5);
    ALBEDO = mix(base, soil, worn * 0.15);
    ROUGHNESS = 0.94;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    ground.material_override = material
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    finish_root.add_child(ground)

    # Soft muddy shelf beneath the foreground hero so feet read as grounded rather
    # than floating over a flat green plane.
    var bank := MeshInstance3D.new()
    bank.name = "HeroMudShelf"
    var bank_mesh := CylinderMesh.new()
    bank_mesh.top_radius = 1.0
    bank_mesh.bottom_radius = 1.0
    bank_mesh.height = 0.045
    bank_mesh.radial_segments = 72
    bank.mesh = bank_mesh
    bank.scale = Vector3(3.25, 1.0, 2.30)
    bank.position = Vector3(-0.65, 0.035, 0.15)
    bank.material_override = _material(Color(0.235, 0.165, 0.085), 0.96)
    bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    finish_root.add_child(bank)

func _add_water() -> void:
    var water := MeshInstance3D.new()
    water.name = "SanctuaryWater"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(6.2, 4.0)
    mesh.subdivide_width = 42
    mesh.subdivide_depth = 28
    water.mesh = mesh
    water.position = Vector3(-0.95, 0.075, -3.65)

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
void vertex() {
    float wave = sin(VERTEX.x * 2.2 + TIME * 0.55) * 0.025;
    wave += cos(VERTEX.z * 2.8 - TIME * 0.42) * 0.018;
    VERTEX.y += wave;
}
void fragment() {
    vec2 centered = (UV - vec2(0.5)) * vec2(1.0, 1.45);
    float edge = length(centered);
    float alpha = 1.0 - smoothstep(0.44, 0.52, edge);
    vec3 deep = vec3(0.035, 0.155, 0.185);
    vec3 shallow = vec3(0.085, 0.315, 0.300);
    float shimmer = sin((UV.x + UV.y) * 45.0 + TIME * 0.70) * 0.5 + 0.5;
    ALBEDO = mix(deep, shallow, UV.y * 0.48 + shimmer * 0.08);
    ROUGHNESS = 0.28;
    METALLIC = 0.04;
    ALPHA = alpha * 0.92;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    water.material_override = material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    finish_root.add_child(water)

func _add_distant_landscape() -> void:
    var hill_data: Array[Dictionary] = [
        {"p": Vector3(-10.0, 1.15, -7.0), "s": Vector3(5.6, 2.0, 4.2), "c": Color(0.12, 0.20, 0.08)},
        {"p": Vector3(-11.4, 1.45, -2.5), "s": Vector3(6.2, 2.6, 4.8), "c": Color(0.16, 0.24, 0.10)},
        {"p": Vector3(-12.2, 1.25, 2.6), "s": Vector3(6.0, 2.2, 4.8), "c": Color(0.14, 0.22, 0.09)},
        {"p": Vector3(-10.4, 1.05, 7.2), "s": Vector3(5.2, 1.9, 4.0), "c": Color(0.11, 0.19, 0.075)}
    ]
    for item in hill_data:
        var hill := MeshInstance3D.new()
        hill.name = "DistantSavannaRidge"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 32
        mesh.rings = 16
        hill.mesh = mesh
        hill.position = item["p"]
        hill.scale = item["s"]
        hill.material_override = _material(item["c"], 0.98)
        hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        finish_root.add_child(hill)

func _add_trees_and_shrubs() -> void:
    var tree_positions: Array[Vector3] = [
        Vector3(-7.0, 0.0, -6.2), Vector3(-8.2, 0.0, 5.8),
        Vector3(-10.0, 0.0, -3.8), Vector3(-9.4, 0.0, 3.1),
        Vector3(-6.4, 0.0, 5.0)
    ]
    for i in range(tree_positions.size()):
        _add_tree(tree_positions[i], 0.78 + float(i % 3) * 0.12)

    var shrub_positions: Array[Vector3] = [
        Vector3(-4.4, 0.15, -5.2), Vector3(-5.2, 0.13, 4.6),
        Vector3(-6.1, 0.14, -2.9), Vector3(-6.8, 0.15, 2.8),
        Vector3(-3.8, 0.12, 4.9), Vector3(-4.0, 0.12, -4.7)
    ]
    for i in range(shrub_positions.size()):
        var shrub := MeshInstance3D.new()
        shrub.name = "SavannaShrub"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        shrub.mesh = mesh
        var size := 0.48 + float(i % 3) * 0.11
        shrub.position = shrub_positions[i]
        shrub.scale = Vector3(size * 1.25, size * 0.58, size)
        shrub.material_override = _material(Color(0.105, 0.245 + float(i % 2) * 0.025, 0.065), 0.97)
        finish_root.add_child(shrub)

func _add_tree(origin: Vector3, scale_value: float) -> void:
    var trunk := MeshInstance3D.new()
    trunk.name = "DistantTreeTrunk"
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.07 * scale_value
    trunk_mesh.bottom_radius = 0.12 * scale_value
    trunk_mesh.height = 1.55 * scale_value
    trunk_mesh.radial_segments = 12
    trunk.mesh = trunk_mesh
    trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
    trunk.material_override = _material(Color(0.24, 0.15, 0.075), 0.98)
    finish_root.add_child(trunk)

    var canopy_offsets: Array[Vector3] = [
        Vector3(0.0, 1.55, 0.0), Vector3(0.34, 1.48, 0.06),
        Vector3(-0.34, 1.50, -0.03), Vector3(0.08, 1.62, 0.28),
        Vector3(-0.10, 1.58, -0.28)
    ]
    for j in range(canopy_offsets.size()):
        var canopy := MeshInstance3D.new()
        canopy.name = "DistantTreeCanopy"
        var canopy_mesh := SphereMesh.new()
        canopy_mesh.radial_segments = 16
        canopy_mesh.rings = 8
        canopy.mesh = canopy_mesh
        canopy.position = origin + canopy_offsets[j] * scale_value
        canopy.scale = Vector3(0.78, 0.30, 0.58) * scale_value
        canopy.material_override = _material(Color(0.08 + float(j % 2) * 0.015, 0.235, 0.065), 0.97)
        canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        finish_root.add_child(canopy)

func _add_grass_field() -> void:
    var blade_mesh := QuadMesh.new()
    blade_mesh.size = Vector2(0.045, 0.34)
    var blade_material := StandardMaterial3D.new()
    blade_material.albedo_color = Color(0.12, 0.26, 0.055)
    blade_material.roughness = 0.96
    blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade_mesh.material = blade_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade_mesh
    multi.instance_count = 420

    var rng := RandomNumberGenerator.new()
    rng.seed = 250826
    var i := 0
    while i < multi.instance_count:
        var x := rng.randf_range(-8.8, 4.2)
        var z := rng.randf_range(-8.0, 8.0)
        # Keep the hero's face/feet and the direct camera lane readable.
        if x > -2.5 and x < 3.8 and absf(z) < 1.75:
            continue
        var height := rng.randf_range(0.42, 1.10)
        var width := rng.randf_range(0.72, 1.12)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, 1.0))
        multi.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.17 * height, z)))
        i += 1

    var grass := MultiMeshInstance3D.new()
    grass.name = "NaturalGrassField"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    finish_root.add_child(grass)

func _add_rocks() -> void:
    var positions: Array[Vector3] = [
        Vector3(-2.9, 0.12, 4.0), Vector3(-3.8, 0.10, -4.2),
        Vector3(-5.6, 0.13, 3.4), Vector3(-5.9, 0.10, -3.5),
        Vector3(-7.2, 0.12, 1.5), Vector3(-7.5, 0.11, -1.8)
    ]
    for i in range(positions.size()):
        var rock := MeshInstance3D.new()
        rock.name = "NaturalRock"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        rock.mesh = mesh
        var s := 0.30 + float(i % 3) * 0.08
        rock.position = positions[i]
        rock.scale = Vector3(s * 1.35, s * 0.55, s)
        rock.rotation = Vector3(0.0, float(i) * 0.71, 0.0)
        rock.material_override = _material(Color(0.29, 0.27, 0.21), 0.94)
        finish_root.add_child(rock)

func _stage_companions(initial: bool) -> void:
    if hippo == null or pig == null or dog == null:
        return
    if initial:
        hippo.position = HERO_HOME
        pig.position = PIG_HOME
        dog.position = DOG_HOME
        pig.velocity = Vector3.ZERO
        dog.velocity = Vector3.ZERO
        return

    # Keep supporting companions within the portrait camera cone without freezing
    # their autonomous action/animation state.
    if pig.position.distance_to(PIG_HOME) > 1.20:
        pig.position = pig.position.lerp(PIG_HOME, 0.22)
    if dog.position.distance_to(DOG_HOME) > 1.20:
        dog.position = dog.position.lerp(DOG_HOME, 0.22)
    if Vector2(hippo.position.x - HERO_HOME.x, hippo.position.z - HERO_HOME.z).length() > 1.55:
        hippo.position.x = lerpf(hippo.position.x, HERO_HOME.x, 0.12)
        hippo.position.z = lerpf(hippo.position.z, HERO_HOME.z, 0.12)

func _apply_camera_frame(delta: float) -> void:
    if camera == null or not is_instance_valid(camera):
        return
    if hud != null and bool(hud.get("bodycam_mode")):
        focus_initialized = false
        return

    var selected := _selected_node()
    if selected == null:
        selected = hippo
    if selected == null:
        return

    var desired_focus := selected.global_position + Vector3(0.0, 0.62, 0.0)
    if not focus_initialized:
        smoothed_focus = desired_focus
        focus_initialized = true
    else:
        smoothed_focus = smoothed_focus.lerp(desired_focus, clampf(delta * 6.5, 0.0, 1.0))

    # The procedural companions face +X. A camera on +X gives a strong face-first
    # hero view. Higher camera elevation moves the horizon into the upper third and
    # replaces the previous wall of empty sky with habitat foreground.
    var desired_camera := smoothed_focus + Vector3(5.55, 2.05, 0.22)
    camera.global_position = camera.global_position.lerp(desired_camera, clampf(delta * 9.0, 0.0, 1.0))
    camera.look_at(smoothed_focus + Vector3(0.0, -0.08, 0.0), Vector3.UP)
    camera.fov = lerpf(camera.fov, 41.0, clampf(delta * 8.0, 0.0, 1.0))

    # CleanSanctuaryStage writes these legacy orbit values late each frame. Keep them
    # aligned with the portrait frame so any temporary camera hand-off does not jump.
    scene_root.set("orbit_yaw", 1.52)
    scene_root.set("orbit_pitch", -0.20)
    scene_root.set("orbit_distance", 5.9)

func _apply_compact_hud() -> void:
    if hud == null:
        return
    var viewport := get_viewport().get_visible_rect()
    var safe := _safe_rect(viewport)
    if safe.size.y < safe.size.x:
        return

    var w := safe.size.x
    var h := safe.size.y
    var left := safe.position.x
    var top := safe.position.y
    var right := safe.end.x
    var bottom := safe.end.y
    var margin := maxf(12.0, w * 0.022)

    var companion_panel := hud.get("companion_panel") as Control
    var avatar_panel := hud.get("avatar_panel") as Control
    var avatar_label := hud.get("avatar_label") as Control
    var name_label := hud.get("name_label") as Control
    var species_label := hud.get("species_label") as Control
    var bond_bar := hud.get("bond_bar") as Control
    var hunger_bar := hud.get("hunger_bar") as Control
    var energy_bar := hud.get("energy_bar") as Control
    var brand_label := hud.get("brand_label") as Control
    var brand_subtitle := hud.get("brand_subtitle") as Control
    var status_panel := hud.get("status_panel") as Control
    var time_label := hud.get("time_label") as Control
    var weather_label := hud.get("weather_label") as Control
    var menu_button := hud.get("menu_button") as Control
    var minimap_panel := hud.get("minimap_panel") as Control
    var minimap := hud.get("minimap") as Control
    var location_label := hud.get("location_label") as Control
    var action_rail := hud.get("action_rail") as Control
    var orbit_panel := hud.get("orbit_panel") as Control
    var orbit_pad := hud.get("orbit_pad") as Control
    var bottom_chevron := hud.get("bottom_chevron") as Control
    var bottom_panel := hud.get("bottom_panel") as Control
    var bottom_nav := hud.get("bottom_nav") as Control

    if companion_panel != null:
        companion_panel.position = Vector2(left + margin, top + margin)
        companion_panel.size = Vector2(minf(246.0, w * 0.355), 128.0)
    if avatar_panel != null:
        avatar_panel.position = Vector2(12, 14)
        avatar_panel.size = Vector2(58, 58)
    if avatar_label != null:
        avatar_label.position = Vector2(0, 8)
        avatar_label.size = Vector2(58, 42)
    if name_label != null and companion_panel != null:
        name_label.position = Vector2(84, 12)
        name_label.size = Vector2(companion_panel.size.x - 94, 28)
    if species_label != null and companion_panel != null:
        species_label.position = Vector2(84, 38)
        species_label.size = Vector2(companion_panel.size.x - 94, 20)

    var bar_x := 84.0
    var bar_w := maxf(86.0, companion_panel.size.x - bar_x - 12.0) if companion_panel != null else 112.0
    for bar_data in [[bond_bar, 66.0], [hunger_bar, 85.0], [energy_bar, 104.0]]:
        var bar := bar_data[0] as Control
        if bar != null:
            bar.position = Vector2(bar_x, float(bar_data[1]))
            bar.size = Vector2(bar_w, 12)

    if brand_label != null:
        brand_label.position = Vector2(left + w * 0.5 - 92.0, top + margin)
        brand_label.size = Vector2(184, 32)
    if brand_subtitle != null:
        brand_subtitle.position = Vector2(left + w * 0.5 - 92.0, top + margin + 30.0)
        brand_subtitle.size = Vector2(184, 22)

    if status_panel != null:
        status_panel.size = Vector2(150, 68)
        status_panel.position = Vector2(right - 150.0 - margin, top + margin)
    if time_label != null:
        time_label.position = Vector2(12, 8)
        time_label.size = Vector2(82, 24)
    if weather_label != null:
        weather_label.position = Vector2(12, 34)
        weather_label.size = Vector2(91, 18)
    if menu_button != null:
        menu_button.position = Vector2(104, 11)
        menu_button.size = Vector2(36, 44)

    var map_size := minf(150.0, w * 0.22)
    if minimap_panel != null:
        minimap_panel.size = Vector2(map_size, map_size)
        minimap_panel.position = Vector2(right - map_size - margin, top + 94.0)
    if minimap != null and minimap_panel != null:
        minimap.position = Vector2(7, 7)
        minimap.size = minimap_panel.size - Vector2(14, 14)
    if location_label != null and minimap_panel != null:
        location_label.position = Vector2(minimap_panel.position.x - 2.0, minimap_panel.position.y + map_size + 5.0)
        location_label.size = Vector2(map_size + 4.0, 38)

    if action_rail != null:
        action_rail.position = Vector2(right - 68.0 - margin, top + h * 0.46)
        action_rail.size = Vector2(68, 272)
        for child in action_rail.get_children():
            if child is Button:
                (child as Button).custom_minimum_size = Vector2(68, 58)

    if orbit_panel != null:
        var orbit_size := minf(112.0, w * 0.17)
        orbit_panel.size = Vector2(orbit_size, orbit_size)
        orbit_panel.position = Vector2(left + margin, bottom - orbit_size - 91.0)
    if orbit_pad != null and orbit_panel != null:
        orbit_pad.position = Vector2(8, 8)
        orbit_pad.size = orbit_panel.size - Vector2(16, 16)
        var cell := maxf(26.0, (orbit_pad.size.x - 8.0) / 3.0)
        for child in orbit_pad.get_children():
            if child is Button:
                (child as Button).custom_minimum_size = Vector2(cell, cell)
    if bottom_chevron != null:
        bottom_chevron.visible = false

    if bottom_panel != null:
        bottom_panel.position = Vector2(left + margin, bottom - 78.0)
        bottom_panel.size = Vector2(w - margin * 2.0, 68.0)
    if bottom_nav != null and bottom_panel != null:
        bottom_nav.position = Vector2(6, 6)
        bottom_nav.size = bottom_panel.size - Vector2(12, 12)
        var nav_w := maxf(62.0, (bottom_nav.size.x - 12.0) / 5.0)
        for child in bottom_nav.get_children():
            if child is Button:
                (child as Button).custom_minimum_size = Vector2(nav_w, 54)

func _remove_intrusive_geometry() -> void:
    if scene_root == null or camera == null:
        return
    _hide_long_thin_primitives(scene_root)

func _hide_long_thin_primitives(node: Node) -> void:
    if finish_root != null and (node == finish_root or finish_root.is_ancestor_of(node)):
        return
    if _belongs_to_animal(node):
        return
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh is CylinderMesh:
            var cylinder := mesh_node.mesh as CylinderMesh
            var vertical_extent := cylinder.height * absf(mesh_node.global_transform.basis.y.length())
            var horizontal_extent := maxf(cylinder.top_radius, cylinder.bottom_radius) * maxf(mesh_node.global_transform.basis.x.length(), mesh_node.global_transform.basis.z.length())
            if vertical_extent > 0.75 and horizontal_extent < 0.24 and mesh_node.global_position.distance_to(camera.global_position) < 12.0:
                mesh_node.visible = false
    for child in node.get_children():
        _hide_long_thin_primitives(child)

func _keep_finish_visible() -> void:
    if finish_root == null or not is_instance_valid(finish_root):
        return
    finish_root.visible = true
    for child in stage_root.get_children():
        if child != finish_root and child is Node3D:
            (child as Node3D).visible = false

func _selected_node() -> Node3D:
    if roster == null:
        return null
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return null
    var companions := companions_variant as Dictionary
    var species := str(roster.get("selected_species"))
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return null
    var node := (data_variant as Dictionary).get("node") as Node3D
    return node if node != null and is_instance_valid(node) else null

func _belongs_to_animal(node: Node) -> bool:
    for animal in [hippo, pig, dog]:
        if animal != null and (node == animal or animal.is_ancestor_of(node)):
            return true
    return false

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _safe_rect(visible: Rect2) -> Rect2:
    var screen_size := DisplayServer.screen_get_size()
    var system_safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0 or screen_size.y <= 0 or system_safe.size.x <= 0 or system_safe.size.y <= 0:
        return visible
    var scale := Vector2(visible.size.x / float(screen_size.x), visible.size.y / float(screen_size.y))
    return Rect2(Vector2(system_safe.position) * scale, Vector2(system_safe.size) * scale)

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
