extends Node

# Final evidence-driven fallback art direction. This reshapes the existing procedural
# companions so their live AI/interaction nodes stay authoritative, while reducing the
# oversized foreground water/reeds and HUD weight seen in Android 16 evidence.
# Licensed ProductionVisual rigs always bypass the fallback reshaping path.

const POND_POS := Vector3(3.7, 0.0, 2.5)

var scene_root: Node3D
var applied := false
var ui_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 2700
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(480):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            var hippo := scene_root.find_child("BabyHippo", true, false)
            var pig := scene_root.find_child("PorkyPig", true, false)
            var dog := scene_root.find_child("BaoSharPei", true, false)
            if hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null:
        push_warning("ReferenceFidelityFinish could not bind to sanctuary")
        return

    # Wait for all world/HUD builders and material passes to finish once.
    for _frame in range(28):
        await get_tree().process_frame

    _reshape_fallback_animals()
    _refine_habitat_depth()
    _set_opening_camera()
    _refine_hud()
    applied = true
    set_process(true)

func _process(delta: float) -> void:
    if not applied or scene_root == null:
        return
    ui_timer -= delta
    if ui_timer <= 0.0:
        ui_timer = 0.55
        _refine_hud()
        _maintain_habitat_finish()

func _reshape_fallback_animals() -> void:
    var hippo := scene_root.find_child("BabyHippo", true, false) as Node3D
    var pig := scene_root.find_child("PorkyPig", true, false) as Node3D
    var dog := scene_root.find_child("BaoSharPei", true, false) as Node3D
    _reshape_hippo(hippo)
    _reshape_pig(pig)
    _reshape_dog(dog)

func _reshape_hippo(hippo: Node3D) -> void:
    if hippo == null or hippo.find_child("ProductionVisual", false, false) != null:
        return
    var visual := _fallback_visual(hippo)
    if visual == null:
        return

    visual.position.y = -0.20
    _hide_old_anatomy(visual)

    _set_part(visual, "Body", Vector3(-0.18, 0.37, 0.0), Vector3(1.28, 0.72, 0.78))
    _set_part(visual, "Belly", Vector3(-0.24, 0.12, 0.0), Vector3(1.04, 0.40, 0.64))
    _set_part(visual, "Head", Vector3(0.96, 0.57, 0.0), Vector3(0.72, 0.64, 0.64))
    _set_scale(visual, "Snout", Vector3(0.54, 0.35, 0.50))
    _set_scale(visual, "Chin", Vector3(0.42, 0.13, 0.40))
    _set_part(visual, "EarL", Vector3(0.85, 0.98, -0.45), Vector3(0.13, 0.17, 0.11))
    _set_part(visual, "EarR", Vector3(0.85, 0.98, 0.45), Vector3(0.13, 0.17, 0.11))
    _set_part(visual, "EyeL", Vector3(1.22, 0.76, -0.38), Vector3(0.055, 0.055, 0.050))
    _set_part(visual, "EyeR", Vector3(1.22, 0.76, 0.38), Vector3(0.055, 0.055, 0.050))
    _set_part(visual, "LegFL", Vector3(0.55, -0.17, -0.47), Vector3(0.23, 0.50, 0.23))
    _set_part(visual, "LegFR", Vector3(0.55, -0.17, 0.47), Vector3(0.23, 0.50, 0.23))
    _set_part(visual, "LegRL", Vector3(-0.76, -0.17, -0.47), Vector3(0.25, 0.52, 0.25))
    _set_part(visual, "LegRR", Vector3(-0.76, -0.17, 0.47), Vector3(0.25, 0.52, 0.25))
    _set_part(visual, "Tail", Vector3(-1.38, 0.46, 0.0), Vector3(0.22, 0.07, 0.07))

    var body := visual.find_child("Body", true, false) as MeshInstance3D
    var skin: Material = body.material_override if body != null else _mat(Color(0.22, 0.16, 0.18), 0.55)
    var root := _detail_root(visual)
    if root.get_child_count() == 0:
        _ellipsoid(root, "ShoulderBridge", Vector3(0.50, 0.45, 0.0), Vector3(0.66, 0.55, 0.69), skin)
        _ellipsoid(root, "NeckBridge", Vector3(0.69, 0.51, 0.0), Vector3(0.44, 0.42, 0.58), skin)
        _ellipsoid(root, "FootFL", Vector3(0.66, -0.46, -0.47), Vector3(0.29, 0.12, 0.27), skin)
        _ellipsoid(root, "FootFR", Vector3(0.66, -0.46, 0.47), Vector3(0.29, 0.12, 0.27), skin)
        _ellipsoid(root, "FootRL", Vector3(-0.66, -0.47, -0.47), Vector3(0.31, 0.12, 0.29), skin)
        _ellipsoid(root, "FootRR", Vector3(-0.66, -0.47, 0.47), Vector3(0.31, 0.12, 0.29), skin)

func _reshape_pig(pig: Node3D) -> void:
    if pig == null or pig.find_child("ProductionVisual", false, false) != null:
        return
    var visual := _fallback_visual(pig)
    if visual == null:
        return

    visual.position.y = -0.16
    _hide_old_anatomy(visual)
    _set_part(visual, "Body", Vector3(-0.08, 0.35, 0.0), Vector3(0.92, 0.55, 0.56))
    _set_part(visual, "Shoulders", Vector3(0.46, 0.42, 0.0), Vector3(0.55, 0.52, 0.54))
    _set_part(visual, "Head", Vector3(0.78, 0.56, 0.0), Vector3(0.50, 0.49, 0.47))
    _set_part(visual, "Snout", Vector3(1.18, 0.42, 0.0), Vector3(0.37, 0.23, 0.30))
    _set_part(visual, "EarL", Vector3(0.73, 0.90, -0.32), Vector3(0.14, 0.23, 0.09))
    _set_part(visual, "EarR", Vector3(0.73, 0.90, 0.32), Vector3(0.14, 0.23, 0.09))
    _set_part(visual, "EyeL", Vector3(1.02, 0.68, -0.29), Vector3(0.050, 0.050, 0.043))
    _set_part(visual, "EyeR", Vector3(1.02, 0.68, 0.29), Vector3(0.050, 0.050, 0.043))
    _set_part(visual, "LegFL", Vector3(0.42, -0.12, -0.32), Vector3(0.18, 0.43, 0.18))
    _set_part(visual, "LegFR", Vector3(0.42, -0.12, 0.32), Vector3(0.18, 0.43, 0.18))
    _set_part(visual, "LegRL", Vector3(-0.55, -0.12, -0.32), Vector3(0.18, 0.43, 0.18))
    _set_part(visual, "LegRR", Vector3(-0.55, -0.12, 0.32), Vector3(0.18, 0.43, 0.18))

    var body := visual.find_child("Body", true, false) as MeshInstance3D
    var skin: Material = body.material_override if body != null else _mat(Color(0.48, 0.30, 0.28), 0.72)
    var root := _detail_root(visual)
    if root.get_child_count() == 0:
        _ellipsoid(root, "PigChestBridge", Vector3(0.30, 0.38, 0.0), Vector3(0.48, 0.42, 0.50), skin)
        _ellipsoid(root, "PigFootFL", Vector3(0.49, -0.36, -0.32), Vector3(0.21, 0.10, 0.18), skin)
        _ellipsoid(root, "PigFootFR", Vector3(0.49, -0.36, 0.32), Vector3(0.21, 0.10, 0.18), skin)
        _ellipsoid(root, "PigFootRL", Vector3(-0.48, -0.36, -0.32), Vector3(0.21, 0.10, 0.18), skin)
        _ellipsoid(root, "PigFootRR", Vector3(-0.48, -0.36, 0.32), Vector3(0.21, 0.10, 0.18), skin)

func _reshape_dog(dog: Node3D) -> void:
    if dog == null or dog.find_child("ProductionVisual", false, false) != null:
        return
    var visual := _fallback_visual(dog)
    if visual == null:
        return

    visual.position.y = -0.18
    _hide_old_anatomy(visual)
    _set_part(visual, "Body", Vector3(-0.10, 0.40, 0.0), Vector3(0.86, 0.53, 0.50))
    _set_part(visual, "Chest", Vector3(0.42, 0.47, 0.0), Vector3(0.52, 0.56, 0.50))
    _set_part(visual, "Head", Vector3(0.76, 0.72, 0.0), Vector3(0.50, 0.49, 0.47))
    _set_part(visual, "Muzzle", Vector3(1.12, 0.57, 0.0), Vector3(0.36, 0.27, 0.31))
    _set_part(visual, "Nose", Vector3(1.34, 0.61, 0.0), Vector3(0.13, 0.10, 0.12))
    _set_part(visual, "EarL", Vector3(0.69, 1.02, -0.31), Vector3(0.12, 0.19, 0.075))
    _set_part(visual, "EarR", Vector3(0.69, 1.02, 0.31), Vector3(0.12, 0.19, 0.075))
    _set_part(visual, "EyeL", Vector3(0.99, 0.82, -0.29), Vector3(0.047, 0.045, 0.040))
    _set_part(visual, "EyeR", Vector3(0.99, 0.82, 0.29), Vector3(0.047, 0.045, 0.040))
    _set_part(visual, "LegFL", Vector3(0.39, -0.10, -0.31), Vector3(0.18, 0.48, 0.18))
    _set_part(visual, "LegFR", Vector3(0.39, -0.10, 0.31), Vector3(0.18, 0.48, 0.18))
    _set_part(visual, "LegRL", Vector3(-0.52, -0.10, -0.31), Vector3(0.19, 0.49, 0.19))
    _set_part(visual, "LegRR", Vector3(-0.52, -0.10, 0.31), Vector3(0.19, 0.49, 0.19))

    var body := visual.find_child("Body", true, false) as MeshInstance3D
    var coat: Material = body.material_override if body != null else _mat(Color(0.43, 0.25, 0.13), 0.82)
    var fold_mat := _mat(Color(0.33, 0.19, 0.10), 0.88)
    var root := _detail_root(visual)
    if root.get_child_count() == 0:
        _ellipsoid(root, "DogNeckBridge", Vector3(0.44, 0.58, 0.0), Vector3(0.46, 0.40, 0.48), coat)
        _ellipsoid(root, "DogForeheadFold", Vector3(0.82, 0.90, 0.0), Vector3(0.40, 0.075, 0.43), fold_mat)
        _ellipsoid(root, "DogNeckFold", Vector3(0.43, 0.67, 0.0), Vector3(0.43, 0.065, 0.46), fold_mat)
        _ellipsoid(root, "DogFootFL", Vector3(0.46, -0.38, -0.31), Vector3(0.21, 0.10, 0.19), coat)
        _ellipsoid(root, "DogFootFR", Vector3(0.46, -0.38, 0.31), Vector3(0.21, 0.10, 0.19), coat)
        _ellipsoid(root, "DogFootRL", Vector3(-0.45, -0.38, -0.31), Vector3(0.21, 0.10, 0.19), coat)
        _ellipsoid(root, "DogFootRR", Vector3(-0.45, -0.38, 0.31), Vector3(0.21, 0.10, 0.19), coat)

func _refine_habitat_depth() -> void:
    var water := scene_root.find_child("ForegroundWatercourse", true, false) as MeshInstance3D
    if water != null:
        water.scale = Vector3(0.72, 1.0, 0.42)
        water.position = Vector3(2.05, 0.035, 2.90)

    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass != null and grass.multimesh != null and not bool(grass.get_meta("reference_fidelity_grass", false)):
        var multi := grass.multimesh
        for i in range(multi.instance_count):
            var transform := multi.get_instance_transform(i)
            transform.basis = transform.basis.scaled(Vector3(0.74, 0.52, 0.74))
            multi.set_instance_transform(i, transform)
        grass.set_meta("reference_fidelity_grass", true)

    var pads := scene_root.find_children("LilyPad*", "MeshInstance3D", true, false)
    for i in range(pads.size()):
        var pad := pads[i] as MeshInstance3D
        if pad == null:
            continue
        pad.scale *= 0.58
        if i % 3 == 2:
            pad.visible = false

    _thin_shoreline_reeds()

func _maintain_habitat_finish() -> void:
    _thin_shoreline_reeds()

func _thin_shoreline_reeds() -> void:
    var world := scene_root.find_child("GrasslandsProductionLayer", true, false) as Node3D
    if world == null:
        return
    var reed_index := 0
    for child in world.get_children():
        if not (child is MeshInstance3D):
            continue
        var mesh_instance := child as MeshInstance3D
        if not (mesh_instance.mesh is CylinderMesh):
            continue
        var cylinder := mesh_instance.mesh as CylinderMesh
        if cylinder.height > 1.05 or cylinder.top_radius > 0.035:
            continue
        if Vector2(mesh_instance.position.x - POND_POS.x, mesh_instance.position.z - POND_POS.z).length() > 4.0:
            continue
        if not bool(mesh_instance.get_meta("reference_reed", false)):
            mesh_instance.scale = Vector3(0.72, 0.55, 0.72)
            mesh_instance.set_meta("reference_reed", true)
        mesh_instance.visible = reed_index % 2 == 0
        reed_index += 1

func _set_opening_camera() -> void:
    var distance := float(scene_root.get("orbit_distance"))
    if distance < 9.7:
        scene_root.set("orbit_distance", 9.8)
    scene_root.set("orbit_yaw", 0.34)
    scene_root.set("orbit_pitch", -0.055)
    var camera := _find_camera(scene_root)
    if camera != null:
        camera.fov = 48.0

func _refine_hud() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return

    var companion_panel := hud.get("companion_panel") as Control
    var status_panel := hud.get("status_panel") as Control
    var minimap_panel := hud.get("minimap_panel") as Control
    var orbit_panel := hud.get("orbit_panel") as Control
    var bottom_panel := hud.get("bottom_panel") as Control
    var action_rail := hud.get("action_rail") as VBoxContainer

    if companion_panel != null:
        companion_panel.modulate.a = 0.80
    if status_panel != null:
        status_panel.modulate.a = 0.76
    if minimap_panel != null:
        minimap_panel.modulate.a = 0.76
    if orbit_panel != null:
        orbit_panel.modulate.a = 0.54
    if bottom_panel != null:
        bottom_panel.modulate.a = 0.72

    if action_rail != null:
        var size := get_viewport().get_visible_rect().size
        if size.y >= size.x:
            action_rail.position = Vector2(size.x - 78.0 - maxf(14.0, size.x * 0.028), size.y * 0.405)
            action_rail.size = Vector2(72, 304)
            action_rail.add_theme_constant_override("separation", 8)
            for child in action_rail.get_children():
                if child is Button:
                    (child as Button).custom_minimum_size = Vector2(72, 68)

func _fallback_visual(animal: Node3D) -> Node3D:
    var named := animal.get_node_or_null("Visual") as Node3D
    if named != null:
        return named
    for child in animal.get_children():
        if child is Node3D and child.find_child("Body", true, false) != null:
            return child as Node3D
    return null

func _hide_old_anatomy(visual: Node3D) -> void:
    var old := visual.find_child("AnatomyPolish", false, false) as Node3D
    if old != null:
        old.visible = false

func _detail_root(visual: Node3D) -> Node3D:
    var root := visual.find_child("ReferenceAnatomy", false, false) as Node3D
    if root == null:
        root = Node3D.new()
        root.name = "ReferenceAnatomy"
        visual.add_child(root)
    return root

func _set_part(visual: Node3D, part_name: String, position: Vector3, scale_value: Vector3) -> void:
    var part := visual.find_child(part_name, true, false) as Node3D
    if part == null:
        return
    part.position = position
    part.scale = scale_value

func _set_scale(visual: Node3D, part_name: String, scale_value: Vector3) -> void:
    var part := visual.find_child(part_name, true, false) as Node3D
    if part != null:
        part.scale = scale_value

func _ellipsoid(parent: Node3D, name_value: String, position: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = name_value
    var sphere := SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    sphere.radial_segments = 32
    sphere.rings = 16
    part.mesh = sphere
    part.position = position
    part.scale = scale_value
    part.material_override = material
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(part)
    return part

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
