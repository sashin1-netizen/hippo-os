extends Node

# Consolidates the visible habitat into one controlled stage for the current procedural
# fallback build. Legacy habitat geometry is hidden (collisions/gameplay remain active),
# then a clean grassland/mud/water composition is rendered around the live companions.
# ProductionVisual animal rigs are untouched.

const HERO := Vector3(0.0, 0.80, 0.20)

var scene_root: Node3D
var stage_root: Node3D
var hippo: Node3D
var pig: Node3D
var dog: Node3D
var timer := 0.0
var legacy_visuals: Array[GeometryInstance3D] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # Run after every older presentation/habitat autoload so they cannot re-enable
    # legacy geometry after this stage takes visual ownership.
    process_priority = 1000000
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(560):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            hippo = scene_root.find_child("BabyHippo", true, false) as Node3D
            pig = scene_root.find_child("PorkyPig", true, false) as Node3D
            dog = scene_root.find_child("BaoSharPei", true, false) as Node3D
            if hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null or hippo == null:
        push_warning("CleanSanctuaryStage could not bind to sanctuary")
        return

    for _frame in range(54):
        await get_tree().process_frame

    _hide_legacy_visuals(scene_root)
    _build_stage()
    _cache_legacy_visuals()
    _force_legacy_hidden()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null:
        return

    # Older environment scripts may set visible=true during their own process pass.
    # Force the cached legacy geometry off every frame, then periodically rescan for
    # any late-created geometry while leaving the clean stage and all animals intact.
    _force_legacy_hidden()

    timer -= delta
    if timer <= 0.0:
        timer = 0.80
        _cache_legacy_visuals()
        _force_legacy_hidden()

func _cache_legacy_visuals() -> void:
    legacy_visuals.clear()
    if scene_root == null:
        return
    _collect_legacy_visuals(scene_root)

func _collect_legacy_visuals(node: Node) -> void:
    if stage_root != null and (node == stage_root or stage_root.is_ancestor_of(node)):
        return
    if _belongs_to_animal(node):
        return

    if node is GeometryInstance3D:
        legacy_visuals.append(node as GeometryInstance3D)

    for child in node.get_children():
        _collect_legacy_visuals(child)

func _force_legacy_hidden() -> void:
    for visual in legacy_visuals:
        if visual != null and is_instance_valid(visual):
            visual.visible = false

func _hide_legacy_visuals(node: Node) -> void:
    if stage_root != null and (node == stage_root or stage_root.is_ancestor_of(node)):
        return
    if _belongs_to_animal(node):
        return

    if node is GeometryInstance3D:
        (node as GeometryInstance3D).visible = false

    for child in node.get_children():
        _hide_legacy_visuals(child)

func _belongs_to_animal(node: Node) -> bool:
    for animal in [hippo, pig, dog]:
        if animal != null and (node == animal or animal.is_ancestor_of(node)):
            return true
    return false

func _build_stage() -> void:
    var existing := scene_root.find_child("CleanSanctuaryStage", true, false) as Node3D
    if existing != null:
        stage_root = existing
        stage_root.visible = true
        return

    stage_root = Node3D.new()
    stage_root.name = "CleanSanctuaryStage"
    scene_root.add_child(stage_root)

    _add_ground()
    _add_hero_bank()
    _add_water()
    _add_distant_ridges()
    _add_sparse_grass()
    _add_edge_rocks()
    _add_distant_acacia(Vector3(-6.6, 0.0, -2.0), 0.92)
    _add_distant_acacia(Vector3(-1.8, 0.0, -6.7), 0.78)

func _add_ground() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "CleanGround"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(18.0, 0.10, 14.0)
    ground.mesh = mesh
    ground.position = Vector3(0.0, -0.055, 0.0)
    ground.material_override = _material(Color(0.19, 0.265, 0.115), 0.98)
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(ground)

func _add_hero_bank() -> void:
    var bank := MeshInstance3D.new()
    bank.name = "CleanHeroMudBank"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.035
    mesh.radial_segments = 64
    bank.mesh = mesh
    bank.scale = Vector3(3.55, 1.0, 2.65)
    bank.position = Vector3(-0.25, 0.026, 0.35)
    bank.material_override = _material(Color(0.265, 0.215, 0.125), 0.96)
    bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(bank)

func _add_water() -> void:
    var water := MeshInstance3D.new()
    water.name = "CleanShallowWater"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.026
    mesh.radial_segments = 64
    water.mesh = mesh
    water.scale = Vector3(3.20, 1.0, 1.55)
    water.position = Vector3(2.75, 0.052, 3.20)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.105, 0.285, 0.285)
    material.roughness = 0.28
    material.metallic = 0.02
    water.material_override = material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(water)

func _add_distant_ridges() -> void:
    var data: Array[Dictionary] = [
        {"p": Vector3(-4.8, 0.15, -9.0), "s": Vector3(5.4, 1.55, 2.2), "c": Color(0.28, 0.34, 0.18)},
        {"p": Vector3(2.2, 0.05, -10.2), "s": Vector3(6.0, 1.85, 2.4), "c": Color(0.33, 0.37, 0.21)},
        {"p": Vector3(8.2, 0.25, -9.3), "s": Vector3(4.8, 1.45, 2.0), "c": Color(0.25, 0.31, 0.17)}
    ]
    for item in data:
        var ridge := MeshInstance3D.new()
        ridge.name = "CleanDistantRidge"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 24
        mesh.rings = 12
        ridge.mesh = mesh
        ridge.position = item["p"]
        ridge.scale = item["s"]
        ridge.material_override = _material(item["c"], 0.99)
        ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        stage_root.add_child(ridge)

func _add_sparse_grass() -> void:
    var blade := QuadMesh.new()
    blade.size = Vector2(0.075, 0.46)
    var blade_material := StandardMaterial3D.new()
    blade_material.albedo_color = Color(0.17, 0.30, 0.075)
    blade_material.roughness = 0.96
    blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade.material = blade_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade
    multi.instance_count = 260

    var rng := RandomNumberGenerator.new()
    rng.seed = 260825
    var placed := 0
    var attempts := 0
    while placed < multi.instance_count and attempts < 6000:
        attempts += 1
        var x := rng.randf_range(-8.2, 8.2)
        var z := rng.randf_range(-6.2, 6.2)
        var hero_distance := Vector2(x - HERO.x, z - HERO.z).length()
        if hero_distance < 4.15:
            continue
        var scale_y := rng.randf_range(0.55, 1.20)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rng.randf_range(0.72, 1.18), scale_y, 1.0))
        multi.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.22 * scale_y, z)))
        placed += 1

    var grass := MultiMeshInstance3D.new()
    grass.name = "CleanSparseGrass"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(grass)

func _add_edge_rocks() -> void:
    var positions: Array[Vector3] = [
        Vector3(-5.5, 0.18, 2.8), Vector3(-4.8, 0.14, -3.8),
        Vector3(5.4, 0.18, -2.9), Vector3(5.9, 0.13, 2.0),
        Vector3(-1.0, 0.13, -5.0), Vector3(3.8, 0.12, -4.6)
    ]
    for i in range(positions.size()):
        var rock := MeshInstance3D.new()
        rock.name = "CleanRock"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        rock.mesh = mesh
        var s := 0.32 + float(i % 3) * 0.08
        rock.scale = Vector3(s * 1.35, s * 0.58, s)
        rock.position = positions[i]
        rock.material_override = _material(Color(0.34, 0.32, 0.25), 0.96)
        stage_root.add_child(rock)

func _add_distant_acacia(origin: Vector3, scale_value: float) -> void:
    var trunk := MeshInstance3D.new()
    trunk.name = "CleanAcaciaTrunk"
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.09 * scale_value
    trunk_mesh.bottom_radius = 0.17 * scale_value
    trunk_mesh.height = 3.7 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
    trunk.material_override = _material(Color(0.24, 0.16, 0.085), 0.98)
    stage_root.add_child(trunk)

    var canopy_material := _material(Color(0.115, 0.285, 0.070), 0.94)
    for i in range(5):
        var canopy := MeshInstance3D.new()
        canopy.name = "CleanAcaciaCanopy"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        canopy.mesh = mesh
        var angle := TAU * float(i) / 5.0
        canopy.position = origin + Vector3(cos(angle) * 0.62 * scale_value, trunk_mesh.height + 0.10, sin(angle) * 0.46 * scale_value)
        canopy.scale = Vector3(1.20, 0.32, 0.88) * scale_value
        canopy.material_override = canopy_material
        stage_root.add_child(canopy)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
