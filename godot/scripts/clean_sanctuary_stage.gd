extends Node

# Single authoritative visual stage for the procedural fallback build. The legacy
# habitat builders are no longer autoloaded; any geometry still present in the base
# scene is forced hidden while animal AI, collisions, saves, audio and HUD remain live.
# ProductionVisual animal rigs are always preserved.

const HIPPO_HOME := Vector3(-0.35, 0.80, 0.85)
const PIG_HOME := Vector3(-4.10, 0.72, -3.10)
const DOG_HOME := Vector3(3.85, 0.75, -3.35)

var scene_root: Node3D
var stage_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var timer := 0.0
var legacy_visuals: Array[GeometryInstance3D] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 1000000
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(560):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            camera = _find_camera(scene_root)
            if hippo != null and pig != null and dog != null and camera != null:
                break
        await get_tree().process_frame

    if scene_root == null or hippo == null or pig == null or dog == null or camera == null:
        push_warning("CleanSanctuaryStage could not bind to sanctuary")
        return

    for _frame in range(48):
        await get_tree().process_frame

    _build_stage()
    _cache_legacy_visuals()
    _force_legacy_hidden()
    _stage_companions(true)
    _enforce_opening_camera()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null:
        return

    _force_legacy_hidden()
    _enforce_opening_camera()

    timer -= delta
    if timer <= 0.0:
        timer = 0.16
        _cache_legacy_visuals()
        _force_legacy_hidden()
        _stage_companions(false)

func _cache_legacy_visuals() -> void:
    legacy_visuals.clear()
    if scene_root != null:
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

func _belongs_to_animal(node: Node) -> bool:
    for animal in [hippo, pig, dog]:
        if animal != null and (node == animal or animal.is_ancestor_of(node)):
            return true
    return false

func _stage_companions(initial: bool) -> void:
    if hippo == null or pig == null or dog == null:
        return
    if initial:
        hippo.position = HIPPO_HOME
        pig.position = PIG_HOME
        dog.position = DOG_HOME
        pig.velocity = Vector3.ZERO
        dog.velocity = Vector3.ZERO
        return

    # Keep supporting animals in opposite midground zones without disabling their AI.
    if pig.position.x > -2.45 or pig.position.z > -2.15 or pig.position.distance_to(PIG_HOME) > 2.0:
        pig.position = pig.position.lerp(PIG_HOME, 0.16)
    if dog.position.x < 2.35 or dog.position.z > -2.15 or dog.position.distance_to(DOG_HOME) > 2.0:
        dog.position = dog.position.lerp(DOG_HOME, 0.16)

    # Mochi owns the foreground and cannot wander far enough to collide visually with HUD.
    var hero_offset := Vector2(hippo.position.x - HIPPO_HOME.x, hippo.position.z - HIPPO_HOME.z)
    if hero_offset.length() > 2.35:
        hippo.position.x = lerpf(hippo.position.x, HIPPO_HOME.x, 0.12)
        hippo.position.z = lerpf(hippo.position.z, HIPPO_HOME.z, 0.12)

func _enforce_opening_camera() -> void:
    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return
    # Documentary-style portrait framing: full-body Mochi in the lower-middle with
    # enough sky/terrain above and clean left/right space for the supporting animals.
    scene_root.set("orbit_yaw", 1.02)
    scene_root.set("orbit_pitch", -0.015)
    scene_root.set("orbit_distance", 12.8)
    camera.fov = 54.0

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
    _add_distant_acacia(Vector3(-6.8, 0.0, -6.4), 0.92)
    _add_distant_acacia(Vector3(6.4, 0.0, -7.1), 0.80)

func _add_ground() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "CleanGround"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(20.0, 0.10, 16.0)
    ground.mesh = mesh
    ground.position = Vector3(0.0, -0.055, -0.5)
    ground.material_override = _material(Color(0.18, 0.235, 0.105), 0.98)
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
    bank.scale = Vector3(3.8, 1.0, 2.8)
    bank.position = Vector3(-0.35, 0.026, 0.60)
    bank.material_override = _material(Color(0.255, 0.205, 0.120), 0.96)
    bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(bank)

func _add_water() -> void:
    # Water is a supporting midground element, not a foreground wall.
    var water := MeshInstance3D.new()
    water.name = "CleanShallowWater"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.024
    mesh.radial_segments = 64
    water.mesh = mesh
    water.scale = Vector3(2.15, 1.0, 0.82)
    water.position = Vector3(3.75, 0.050, 4.65)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.105, 0.245, 0.255)
    material.roughness = 0.34
    material.metallic = 0.01
    water.material_override = material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(water)

func _add_distant_ridges() -> void:
    var data: Array[Dictionary] = [
        {"p": Vector3(-5.6, 0.15, -10.4), "s": Vector3(5.8, 1.42, 2.3), "c": Color(0.27, 0.32, 0.17)},
        {"p": Vector3(1.8, 0.05, -11.2), "s": Vector3(6.3, 1.68, 2.6), "c": Color(0.31, 0.35, 0.20)},
        {"p": Vector3(8.6, 0.20, -10.3), "s": Vector3(5.0, 1.35, 2.1), "c": Color(0.24, 0.29, 0.16)}
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
    blade.size = Vector2(0.055, 0.34)
    var blade_material := StandardMaterial3D.new()
    blade_material.albedo_color = Color(0.15, 0.265, 0.065)
    blade_material.roughness = 0.97
    blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade.material = blade_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade
    multi.instance_count = 90

    var rng := RandomNumberGenerator.new()
    rng.seed = 260825
    var placed := 0
    var attempts := 0
    while placed < multi.instance_count and attempts < 5000:
        attempts += 1
        var x := rng.randf_range(-8.6, 8.6)
        var z := rng.randf_range(-7.0, 5.8)
        var hero_distance := Vector2(x - HIPPO_HOME.x, z - HIPPO_HOME.z).length()
        if hero_distance < 5.6:
            continue
        var scale_y := rng.randf_range(0.50, 0.95)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rng.randf_range(0.72, 1.05), scale_y, 1.0))
        multi.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.16 * scale_y, z)))
        placed += 1

    var grass := MultiMeshInstance3D.new()
    grass.name = "CleanSparseGrass"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(grass)

func _add_edge_rocks() -> void:
    var positions: Array[Vector3] = [
        Vector3(-5.8, 0.15, 2.9), Vector3(-5.1, 0.12, -4.2),
        Vector3(5.8, 0.16, -3.3), Vector3(6.2, 0.12, 2.2),
        Vector3(-1.2, 0.11, -5.8), Vector3(4.1, 0.11, -5.2)
    ]
    for i in range(positions.size()):
        var rock := MeshInstance3D.new()
        rock.name = "CleanRock"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        rock.mesh = mesh
        var s := 0.30 + float(i % 3) * 0.07
        rock.scale = Vector3(s * 1.35, s * 0.56, s)
        rock.position = positions[i]
        rock.material_override = _material(Color(0.33, 0.31, 0.24), 0.96)
        stage_root.add_child(rock)

func _add_distant_acacia(origin: Vector3, scale_value: float) -> void:
    var trunk := MeshInstance3D.new()
    trunk.name = "CleanAcaciaTrunk"
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.08 * scale_value
    trunk_mesh.bottom_radius = 0.15 * scale_value
    trunk_mesh.height = 3.5 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
    trunk.material_override = _material(Color(0.23, 0.15, 0.08), 0.98)
    stage_root.add_child(trunk)

    var canopy_material := _material(Color(0.105, 0.255, 0.062), 0.94)
    for i in range(4):
        var canopy := MeshInstance3D.new()
        canopy.name = "CleanAcaciaCanopy"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        canopy.mesh = mesh
        var angle := TAU * float(i) / 4.0
        canopy.position = origin + Vector3(cos(angle) * 0.58 * scale_value, trunk_mesh.height + 0.08, sin(angle) * 0.42 * scale_value)
        canopy.scale = Vector3(1.12, 0.28, 0.80) * scale_value
        canopy.material_override = canopy_material
        stage_root.add_child(canopy)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
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
