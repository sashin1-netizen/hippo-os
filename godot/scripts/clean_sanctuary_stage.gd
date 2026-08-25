extends Node

# Single authoritative visual stage for the procedural fallback build. The legacy
# habitat builders are no longer autoloaded; any geometry still present in the base
# scene is forced hidden while animal AI, collisions, saves, audio and HUD remain live.
# ProductionVisual animal rigs are always preserved.

const HIPPO_HOME := Vector3(-0.65, 0.80, 0.85)
const PIG_HOME := Vector3(-3.20, 0.72, -4.60)
const DOG_HOME := Vector3(2.70, 0.75, -4.90)

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
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null:
        return

    _force_legacy_hidden()
    _enforce_opening_camera()
    _enforce_environment()

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

    if pig.position.x > -2.35 or pig.position.z > -3.05 or pig.position.distance_to(PIG_HOME) > 1.85:
        pig.position = pig.position.lerp(PIG_HOME, 0.18)
    if dog.position.x < 1.95 or dog.position.z > -3.10 or dog.position.distance_to(DOG_HOME) > 1.85:
        dog.position = dog.position.lerp(DOG_HOME, 0.18)

    var hero_offset := Vector2(hippo.position.x - HIPPO_HOME.x, hippo.position.z - HIPPO_HOME.z)
    if hero_offset.length() > 2.10:
        hippo.position.x = lerpf(hippo.position.x, HIPPO_HOME.x, 0.14)
        hippo.position.z = lerpf(hippo.position.z, HIPPO_HOME.z, 0.14)

func _enforce_opening_camera() -> void:
    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return
    # More frontal three-quarter portrait framing keeps Mochi's face away from the
    # right-side action rail while retaining enough body/environment context.
    scene_root.set("orbit_yaw", 1.38)
    scene_root.set("orbit_pitch", -0.005)
    scene_root.set("orbit_distance", 13.6)
    camera.fov = 52.0

func _enforce_environment() -> void:
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return
    var environment := world_environment.environment
    var daylight := _daylight_factor()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.045, 0.075, 0.13).lerp(Color(0.34, 0.63, 0.86), daylight)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.34, 0.41, 0.56).lerp(Color(0.72, 0.76, 0.68), daylight)
    environment.ambient_light_energy = lerpf(0.72, 1.08, daylight)
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.20, 0.24, 0.34).lerp(Color(0.73, 0.79, 0.75), daylight)
    environment.fog_light_energy = lerpf(0.26, 0.55, daylight)
    environment.fog_density = lerpf(0.012, 0.0045, daylight)
    environment.adjustment_enabled = true
    environment.adjustment_brightness = lerpf(1.02, 1.08, daylight)
    environment.adjustment_contrast = lerpf(1.01, 1.035, daylight)
    environment.adjustment_saturation = lerpf(0.84, 0.90, daylight)

    var sun := scene_root.find_child("Sun", true, false) as DirectionalLight3D
    if sun != null:
        sun.light_energy = lerpf(0.52, 1.20, daylight)
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
    mesh.size = Vector3(20.0, 0.10, 16.0)
    ground.mesh = mesh
    ground.position = Vector3(0.0, -0.055, -0.5)
    ground.material_override = _material(Color(0.105, 0.175, 0.060), 0.98)
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
    bank.scale = Vector3(4.10, 1.0, 3.20)
    bank.position = Vector3(-0.55, 0.026, 0.60)
    bank.material_override = _material(Color(0.215, 0.155, 0.080), 0.97)
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
    water.scale = Vector3(1.65, 1.0, 0.58)
    water.position = Vector3(3.95, 0.050, 4.95)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.055, 0.155, 0.175)
    material.roughness = 0.48
    material.metallic = 0.0
    water.material_override = material
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(water)

func _add_distant_ridges() -> void:
    var data: Array[Dictionary] = [
        {"p": Vector3(-5.8, 0.45, -11.0), "s": Vector3(5.8, 2.20, 2.4), "c": Color(0.22, 0.29, 0.16)},
        {"p": Vector3(1.6, 0.38, -12.0), "s": Vector3(6.5, 2.45, 2.7), "c": Color(0.27, 0.33, 0.19)},
        {"p": Vector3(8.5, 0.48, -11.0), "s": Vector3(5.2, 2.05, 2.3), "c": Color(0.20, 0.27, 0.15)}
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
    blade.size = Vector2(0.045, 0.28)
    var blade_material := StandardMaterial3D.new()
    blade_material.albedo_color = Color(0.125, 0.225, 0.050)
    blade_material.roughness = 0.98
    blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade.material = blade_material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade
    multi.instance_count = 48

    var rng := RandomNumberGenerator.new()
    rng.seed = 260825
    var placed := 0
    var attempts := 0
    while placed < multi.instance_count and attempts < 5000:
        attempts += 1
        var x := rng.randf_range(-8.5, 8.5)
        var z := rng.randf_range(-7.5, -2.4)
        if absf(x) < 5.4 and z > -4.8:
            continue
        var scale_y := rng.randf_range(0.48, 0.85)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(rng.randf_range(0.72, 1.0), scale_y, 1.0))
        multi.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.13 * scale_y, z)))
        placed += 1

    var grass := MultiMeshInstance3D.new()
    grass.name = "CleanSparseGrass"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    stage_root.add_child(grass)

func _add_edge_rocks() -> void:
    var positions: Array[Vector3] = [
        Vector3(-6.0, 0.13, 2.9), Vector3(-5.3, 0.11, -4.4),
        Vector3(6.0, 0.14, -3.5), Vector3(6.3, 0.11, 2.1),
        Vector3(-1.4, 0.10, -6.2), Vector3(4.3, 0.10, -5.6)
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

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
