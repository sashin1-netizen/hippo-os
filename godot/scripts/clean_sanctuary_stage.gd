extends Node

# Single authoritative visual stage for the procedural fallback build. The legacy
# habitat builders are no longer autoloaded; any geometry still present in the base
# scene is forced hidden while animal AI, collisions, saves, audio and HUD remain live.
# ProductionVisual animal rigs are always preserved.

# The opening camera sits predominantly on +X looking toward -X. Therefore depth is
# staged along X and left/right composition along Z.
const HIPPO_HOME := Vector3(-0.30, 0.80, 0.00)
const PIG_HOME := Vector3(-4.80, 0.72, 3.10)
const DOG_HOME := Vector3(-5.20, 0.75, -3.00)

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
    _enforce_environment()
    _suppress_intrusive_foreground()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null:
        return

    _force_legacy_hidden()
    _enforce_opening_camera()
    _enforce_environment()

    timer -= delta
    if timer <= 0.0:
        timer = 0.14
        _cache_legacy_visuals()
        _force_legacy_hidden()
        _stage_companions(false)
        _suppress_intrusive_foreground()

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

    # Companions remain behind Mochi in depth (negative X) and on opposite screen
    # sides (positive/negative Z) while their autonomous behaviour stays active.
    if pig.position.x > -3.35 or pig.position.z < 1.85 or pig.position.distance_to(PIG_HOME) > 1.80:
        pig.position = pig.position.lerp(PIG_HOME, 0.20)
    if dog.position.x > -3.55 or dog.position.z > -1.75 or dog.position.distance_to(DOG_HOME) > 1.80:
        dog.position = dog.position.lerp(DOG_HOME, 0.20)

    var hero_offset := Vector2(hippo.position.x - HIPPO_HOME.x, hippo.position.z - HIPPO_HOME.z)
    if hero_offset.length() > 1.95:
        hippo.position.x = lerpf(hippo.position.x, HIPPO_HOME.x, 0.15)
        hippo.position.z = lerpf(hippo.position.z, HIPPO_HOME.z, 0.15)

func _enforce_opening_camera() -> void:
    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return
    # Nearly frontal three-quarter wildlife framing. With procedural anatomy authored
    # along local +X, this puts Mochi's face in the visual centre instead of under UI.
    scene_root.set("orbit_yaw", 1.48)
    scene_root.set("orbit_pitch", -0.018)
    scene_root.set("orbit_distance", 14.0)
    camera.fov = 50.0

func _enforce_environment() -> void:
    var daylight := _daylight_factor()
    var sky_color := Color(0.045, 0.075, 0.13).lerp(Color(0.34, 0.64, 0.88), daylight)
    RenderingServer.set_default_clear_color(sky_color)

    var world_environment := _find_world_environment(scene_root)
    if world_environment != null and world_environment.environment != null:
        var environment := world_environment.environment
        environment.background_mode = Environment.BG_COLOR
        environment.background_color = sky_color
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        environment.ambient_light_color = Color(0.34, 0.41, 0.56).lerp(Color(0.72, 0.77, 0.69), daylight)
        environment.ambient_light_energy = lerpf(0.72, 1.04, daylight)
        environment.fog_enabled = true
        environment.fog_light_color = Color(0.20, 0.24, 0.34).lerp(Color(0.73, 0.80, 0.78), daylight)
        environment.fog_light_energy = lerpf(0.26, 0.54, daylight)
        environment.fog_density = lerpf(0.012, 0.0042, daylight)
        environment.adjustment_enabled = true
        environment.adjustment_brightness = lerpf(1.02, 1.06, daylight)
        environment.adjustment_contrast = lerpf(1.01, 1.025, daylight)
        environment.adjustment_saturation = lerpf(0.84, 0.89, daylight)

    var sun := _find_sun(scene_root)
    if sun != null:
        sun.light_energy = lerpf(0.52, 1.14, daylight)
        sun.light_color = Color(0.70, 0.77, 0.94).lerp(Color(1.0, 0.93, 0.80), daylight)

func _daylight_factor() -> float:
    var mode := "auto"
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) == TYPE_DICTIONARY:
        mode = str((settings_variant as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _suppress_intrusive_foreground() -> void:
    if camera == null:
        return
    _suppress_intrusive_recursive(scene_root)

func _suppress_intrusive_recursive(node: Node) -> void:
    if _belongs_to_animal(node):
        return
    if node is MeshInstance3D:
        var visual := node as MeshInstance3D
        if visual.mesh is CylinderMesh:
            var cylinder := visual.mesh as CylinderMesh
            if cylinder.height * absf(visual.scale.y) > 0.45 and visual.global_position.distance_to(camera.global_position) < 11.0:
                visual.visible = false
    for child in node.get_children():
        _suppress_intrusive_recursive(child)

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

func _add_ground() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "CleanGround"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(22.0, 0.10, 18.0)
    ground.mesh = mesh
    ground.position = Vector3(-1.0, -0.055, 0.0)
    ground.material_override = _material(Color(0.095, 0.155, 0.050), 0.98)
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
    bank.scale = Vector3(3.8, 1.0, 3.5)
    bank.position = Vector3(-0.50, 0.026, 0.0)
    bank.material_override = _material(Color(0.205, 0.145, 0.072), 0.97)
    bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(bank)

func _add_water() -> void:
    var water := MeshInstance3D.new()
    water.name = "CleanShallowWater"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.022
    mesh.radial_segments = 64
    water.mesh = mesh
    water.scale = Vector3(2.0, 1.0, 1.20)
    water.position = Vector3(-1.4, 0.050, -4.25)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.045, 0.145, 0.165)
    material.roughness = 0.50
    material.metallic = 0.0
    water.material_override = material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(water)

func _add_distant_ridges() -> void:
    # Negative X is behind the animals from this camera; Z controls left/right spread.
    var data: Array[Dictionary] = [
        {"p": Vector3(-10.0, 1.45, 5.1), "s": Vector3(2.3, 2.25, 5.0), "c": Color(0.20, 0.275, 0.15)},
        {"p": Vector3(-11.4, 1.80, 0.0), "s": Vector3(2.7, 2.75, 5.7), "c": Color(0.25, 0.32, 0.18)},
        {"p": Vector3(-10.2, 1.50, -5.2), "s": Vector3(2.4, 2.30, 5.0), "c": Color(0.19, 0.265, 0.145)}
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
    blade.size = Vector2(0.04, 0.24)
    var blade_material := StandardMaterial3D.new()
    blade_material.albedo_color = Color(0.115, 0.205, 0.045)
    blade_material.roughness = 0.98
    blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade.material = blade_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade
    multi.instance_count = 36

    var rng := RandomNumberGenerator.new()
    rng.seed = 260825
    for i in range(multi.instance_count):
        var x := rng.randf_range(-8.5, -3.0)
        var z := rng.randf_range(-7.0, 7.0)
        var scale_y := rng.randf_range(0.45, 0.80)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rng.randf_range(0.72, 1.0), scale_y, 1.0))
        multi.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.12 * scale_y, z)))

    var grass := MultiMeshInstance3D.new()
    grass.name = "CleanSparseGrass"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(grass)

func _add_edge_rocks() -> void:
    var positions: Array[Vector3] = [
        Vector3(-3.8, 0.11, 5.6), Vector3(-5.8, 0.10, 4.3),
        Vector3(-5.6, 0.12, -4.5), Vector3(-3.6, 0.10, -5.8),
        Vector3(-7.0, 0.10, 1.8), Vector3(-7.2, 0.10, -2.0)
    ]
    for i in range(positions.size()):
        var rock := MeshInstance3D.new()
        rock.name = "CleanRock"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 18
        mesh.rings = 9
        rock.mesh = mesh
        var s := 0.28 + float(i % 3) * 0.06
        rock.scale = Vector3(s * 1.35, s * 0.55, s)
        rock.position = positions[i]
        rock.material_override = _material(Color(0.30, 0.285, 0.23), 0.97)
        stage_root.add_child(rock)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _find_world_environment(node: Node) -> WorldEnvironment:
    if node is WorldEnvironment:
        return node as WorldEnvironment
    for child in node.get_children():
        var found := _find_world_environment(child)
        if found != null:
            return found
    return null

func _find_sun(node: Node) -> DirectionalLight3D:
    if node is DirectionalLight3D:
        return node as DirectionalLight3D
    for child in node.get_children():
        var found := _find_sun(child)
        if found != null:
            return found
    return null

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
