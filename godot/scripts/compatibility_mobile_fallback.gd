extends Node

# Renderer-specific fallback for Android emulators and devices that must use Godot's
# Compatibility renderer. Normal Mobile/Vulkan phones keep the production world. The
# compatibility path uses pinned CC0 Gobkit scenery when available and retains primitive
# emergency geometry only if those build-time assets are unavailable.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.90, 0.72, 3.45)
const DOG_HOME := Vector3(-4.15, 0.75, -2.75)
const HOLD_SECONDS := 35.0
const CAMERA_DISTANCE := 8.15
const CAMERA_PITCH := -0.085

const GOBKIT_NATURE := "res://assets/community/gobkit/nature/"

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var fallback_world: Node3D
var hold_until := 0.0
var maintenance_timer := 0.0
var active := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 20000
    set_process(false)
    call_deferred("_bind")

func _bind() -> void:
    if not _is_compatibility_renderer():
        return

    for _attempt in range(480):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            if camera != null and hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null or camera == null or hippo == null or pig == null or dog == null:
        push_warning("CompatibilityMobileFallback could not bind")
        return

    # ProductionAssetLoader binds early, but give dynamically imported community GLBs a
    # few frames to mount before final launch staging and screenshot proof.
    for _frame in range(10):
        await get_tree().process_frame

    hold_until = Time.get_ticks_msec() / 1000.0 + HOLD_SECONDS
    _build_fallback_world()
    _apply_reference_daylight()
    _hide_original_geometry(scene_root)
    _stage_opening()
    _fix_hud()
    active = true
    set_process(true)
    print("HippoOS compatibility open-world fallback active")

func _process(delta: float) -> void:
    if not active:
        return

    var holding := Time.get_ticks_msec() / 1000.0 < hold_until
    if holding:
        hippo.velocity = Vector3.ZERO
        pig.velocity = Vector3.ZERO
        dog.velocity = Vector3.ZERO
        hippo.position = hippo.position.lerp(HERO_HOME, clampf(delta * 10.0, 0.0, 1.0))
        pig.position = pig.position.lerp(PIG_HOME, clampf(delta * 8.0, 0.0, 1.0))
        dog.position = dog.position.lerp(DOG_HOME, clampf(delta * 8.0, 0.0, 1.0))
        scene_root.set("current_action", "idle")
        scene_root.set("action_timer", 1.5)
        scene_root.set("orbit_yaw", 1.53)
        scene_root.set("orbit_pitch", CAMERA_PITCH)
        scene_root.set("orbit_distance", CAMERA_DISTANCE)
        camera.fov = lerpf(camera.fov, 44.0, clampf(delta * 7.0, 0.0, 1.0))
        _face(hippo, camera.global_position, clampf(delta * 14.0, 0.0, 1.0))
        _face(pig, hippo.global_position, clampf(delta * 9.0, 0.0, 1.0))
        _face(dog, hippo.global_position, clampf(delta * 9.0, 0.0, 1.0))

    maintenance_timer -= delta
    if maintenance_timer <= 0.0:
        maintenance_timer = 0.20
        _apply_reference_daylight()
        _hide_original_geometry(scene_root)
        if fallback_world != null:
            fallback_world.visible = true
        _fix_hud()

func _is_compatibility_renderer() -> bool:
    var method := String(RenderingServer.get_current_rendering_method()).to_lower()
    return "compatibility" in method or "gl_compatibility" in method

func _build_fallback_world() -> void:
    var existing := scene_root.find_child("CompatibilityOpenWorld", true, false) as Node3D
    if existing != null:
        fallback_world = existing
        fallback_world.visible = true
        return

    fallback_world = Node3D.new()
    fallback_world.name = "CompatibilityOpenWorld"
    scene_root.add_child(fallback_world)

    _build_ground_and_water()
    _build_safe_sun()

    var community_props := _build_gobkit_landscape()
    if community_props == 0:
        push_warning("Gobkit compatibility scenery unavailable; using primitive emergency landscape")
        _build_primitive_background()

func _build_ground_and_water() -> void:
    var ground := MeshInstance3D.new()
    ground.name = "CompatibilityGround"
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(38.0, 30.0)
    ground.mesh = ground_mesh
    ground.position = Vector3(-4.0, 0.012, 0.0)
    ground.material_override = _ground_material()
    fallback_world.add_child(ground)

    var wet_bank := MeshInstance3D.new()
    wet_bank.name = "CompatibilityWetBank"
    var wet_mesh := PlaneMesh.new()
    wet_mesh.size = Vector2(9.8, 6.7)
    wet_bank.mesh = wet_mesh
    wet_bank.position = Vector3(0.65, 0.026, 2.0)
    wet_bank.rotation_degrees.y = -5.0
    wet_bank.material_override = _material(Color(0.24, 0.17, 0.095), 0.82)
    fallback_world.add_child(wet_bank)

    var water := MeshInstance3D.new()
    water.name = "CompatibilityWatercourse"
    var water_mesh := PlaneMesh.new()
    water_mesh.size = Vector2(6.8, 7.5)
    water.mesh = water_mesh
    water.position = Vector3(2.25, 0.040, 2.38)
    water.rotation_degrees.y = -7.0
    water.material_override = _water_material()
    fallback_world.add_child(water)

func _build_safe_sun() -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "CompatibilitySun"
    sun.rotation_degrees = Vector3(-51.0, -32.0, 0.0)
    sun.light_color = Color(1.0, 0.91, 0.75)
    sun.light_energy = 1.05
    sun.shadow_enabled = false
    fallback_world.add_child(sun)

func _build_gobkit_landscape() -> int:
    var count := 0

    # Layered distant silhouettes replace the giant stretched sphere ridges that were
    # dominating the portrait render. Keep all scenery behind the animals along -X.
    count += int(_spawn_gobkit_prop("MountainFar001.glb", "CommunityMountainA", Vector3(-16.0, 0.0, -6.5), 5.0, 0.10))
    count += int(_spawn_gobkit_prop("MountainFar002.glb", "CommunityMountainB", Vector3(-19.5, 0.0, 1.2), 6.2, -0.28))
    count += int(_spawn_gobkit_prop("MountainFar003.glb", "CommunityMountainC", Vector3(-15.5, 0.0, 7.2), 4.7, 0.34))

    count += int(_spawn_gobkit_prop("TreeHigh001.glb", "CommunityTreeTallA", Vector3(-8.8, 0.0, -5.8), 5.1, -0.18))
    count += int(_spawn_gobkit_prop("TreeHigh001.glb", "CommunityTreeTallB", Vector3(-10.2, 0.0, 6.0), 4.5, 0.42))
    count += int(_spawn_gobkit_prop("TreeLow002.glb", "CommunityTreeLow", Vector3(-6.5, 0.0, -7.0), 2.7, -0.60))

    var bush_positions: Array[Vector3] = [
        Vector3(-5.8, 0.0, -5.1), Vector3(-7.2, 0.0, -4.5),
        Vector3(-6.2, 0.0, 5.0), Vector3(-8.0, 0.0, 4.8),
        Vector3(-3.8, 0.0, -5.8), Vector3(-4.2, 0.0, 6.0)
    ]
    for i in range(bush_positions.size()):
        var bush_file := "Bush001.glb" if i % 2 == 0 else "Bush002.glb"
        count += int(_spawn_gobkit_prop(bush_file, "CommunityBush%02d" % i, bush_positions[i], 0.78 + float(i % 3) * 0.14, float(i) * 0.57))

    var rock_positions: Array[Vector3] = [
        Vector3(-0.8, 0.0, -3.8), Vector3(3.8, 0.0, -3.4),
        Vector3(5.6, 0.0, 4.6), Vector3(-2.8, 0.0, 4.9),
        Vector3(5.9, 0.0, 0.2), Vector3(-5.0, 0.0, -2.8)
    ]
    for i in range(rock_positions.size()):
        var rock_file := ["Rock001.glb", "Rock002.glb", "Rock003.glb"][i % 3]
        count += int(_spawn_gobkit_prop(String(rock_file), "CommunityRock%02d" % i, rock_positions[i], 0.48 + float(i % 3) * 0.12, float(i) * 0.71))

    var reed_positions: Array[Vector3] = [
        Vector3(-0.3, 0.0, 3.9), Vector3(0.6, 0.0, 4.5),
        Vector3(4.8, 0.0, 4.8), Vector3(5.2, 0.0, 3.7)
    ]
    for i in range(reed_positions.size()):
        var reed_file := "Reed001.glb" if i % 2 == 0 else "Reed002.glb"
        count += int(_spawn_gobkit_prop(reed_file, "CommunityReed%02d" % i, reed_positions[i], 1.05 + float(i % 2) * 0.16, float(i) * 0.44))

    return count

func _spawn_gobkit_prop(file_name: String, node_name: String, world_position: Vector3, target_height: float, yaw: float) -> bool:
    var path := GOBKIT_NATURE + file_name
    if not ResourceLoader.exists(path):
        return false
    var resource: Resource = load(path)
    if not resource is PackedScene:
        return false
    var instance := (resource as PackedScene).instantiate() as Node3D
    if instance == null:
        return false

    instance.name = node_name
    instance.position = world_position
    instance.rotation.y = yaw
    fallback_world.add_child(instance)
    _normalize_static_prop(instance, world_position, target_height, yaw)
    instance.set_meta("hippo_os_cc0_gobkit", true)
    return true

func _normalize_static_prop(instance: Node3D, world_position: Vector3, target_height: float, yaw: float) -> void:
    instance.scale = Vector3.ONE
    var bounds := _visual_bounds_in_root(instance)
    if bounds.size.y <= 0.001:
        return

    var factor := clampf(target_height / bounds.size.y, 0.05, 20.0)
    var center := bounds.position + bounds.size * 0.5
    var rotated_center := Basis(Vector3.UP, yaw) * Vector3(center.x, 0.0, center.z)
    instance.scale = Vector3.ONE * factor
    instance.position = Vector3(
        world_position.x - rotated_center.x * factor,
        world_position.y - bounds.position.y * factor,
        world_position.z - rotated_center.z * factor
    )

func _visual_bounds_in_root(root: Node3D) -> AABB:
    var found := false
    var merged := AABB()
    var root_inverse := root.global_transform.affine_inverse()
    var mesh_nodes := root.find_children("*", "MeshInstance3D", true, false)
    for node in mesh_nodes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        var to_root := root_inverse * mesh_node.global_transform
        var transformed := _transform_aabb(mesh_node.get_aabb(), to_root)
        if not found:
            merged = transformed
            found = true
        else:
            merged = merged.merge(transformed)
    return merged if found else AABB()

func _transform_aabb(box: AABB, transform: Transform3D) -> AABB:
    var output := AABB(transform * box.position, Vector3.ZERO)
    for xi in range(2):
        for yi in range(2):
            for zi in range(2):
                var point := box.position + Vector3(
                    box.size.x * float(xi),
                    box.size.y * float(yi),
                    box.size.z * float(zi)
                )
                output = output.expand(transform * point)
    return output

func _build_primitive_background() -> void:
    var ridge_materials: Array[StandardMaterial3D] = [
        _material(Color(0.22, 0.25, 0.15), 0.98),
        _material(Color(0.30, 0.29, 0.18), 0.98),
        _material(Color(0.37, 0.34, 0.22), 0.97)
    ]
    var ridge_positions: Array[Vector3] = [
        Vector3(-13.0, 1.0, -6.0), Vector3(-16.0, 1.3, 0.0),
        Vector3(-13.5, 0.9, 6.2)
    ]
    var ridge_scales: Array[Vector3] = [
        Vector3(3.8, 1.3, 3.0), Vector3(4.4, 1.7, 3.6),
        Vector3(3.6, 1.2, 2.9)
    ]
    for i in range(ridge_positions.size()):
        var ridge := MeshInstance3D.new()
        ridge.name = "CompatibilityEmergencyRidge"
        var sphere := SphereMesh.new()
        sphere.radial_segments = 16
        sphere.rings = 8
        ridge.mesh = sphere
        ridge.position = ridge_positions[i]
        ridge.scale = ridge_scales[i]
        ridge.material_override = ridge_materials[i % ridge_materials.size()]
        ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        fallback_world.add_child(ridge)

func _apply_reference_daylight() -> void:
    var sky_top := Color(0.10, 0.42, 0.76)
    var sky_horizon := Color(0.70, 0.86, 0.94)
    RenderingServer.set_default_clear_color(sky_horizon)
    var environments := scene_root.find_children("*", "WorldEnvironment", true, false)
    for node in environments:
        var world_environment := node as WorldEnvironment
        if world_environment != null and world_environment.environment != null:
            _configure_environment(world_environment.environment, sky_top, sky_horizon)
    if camera != null:
        var camera_environment: Variant = camera.get("environment")
        if camera_environment is Environment:
            _configure_environment(camera_environment as Environment, sky_top, sky_horizon)

func _configure_environment(env: Environment, sky_top: Color, sky_horizon: Color) -> void:
    var sky := env.sky
    var sky_material: ProceduralSkyMaterial
    if sky == null or not (sky.sky_material is ProceduralSkyMaterial):
        sky = Sky.new()
        sky.radiance_size = Sky.RADIANCE_SIZE_32
        sky_material = ProceduralSkyMaterial.new()
        sky.sky_material = sky_material
        env.sky = sky
    else:
        sky_material = sky.sky_material as ProceduralSkyMaterial

    sky_material.sky_top_color = sky_top
    sky_material.sky_horizon_color = sky_horizon
    sky_material.ground_horizon_color = Color(0.50, 0.57, 0.36)
    sky_material.ground_bottom_color = Color(0.17, 0.22, 0.11)
    sky_material.use_debanding = true

    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.92
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.fog_enabled = true
    env.fog_light_color = Color(0.80, 0.86, 0.82)
    env.fog_light_energy = 0.38
    env.fog_density = 0.0015
    env.fog_sky_affect = 0.08
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.06
    env.adjustment_contrast = 1.035
    env.adjustment_saturation = 1.02

func _hide_original_geometry(node: Node) -> void:
    for child in node.get_children():
        if child == fallback_world or child == hippo or child == pig or child == dog:
            continue
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).visible = false
        _hide_original_geometry(child)

func _stage_opening() -> void:
    hippo.position = HERO_HOME
    pig.position = PIG_HOME
    dog.position = DOG_HOME
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", HOLD_SECONDS)
    scene_root.set("orbit_yaw", 1.53)
    scene_root.set("orbit_pitch", CAMERA_PITCH)
    scene_root.set("orbit_distance", CAMERA_DISTANCE)
    _face(hippo, camera.global_position, 1.0)
    _face(pig, hippo.global_position, 1.0)
    _face(dog, hippo.global_position, 1.0)

func _fix_hud() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return
    var weather := hud.get("weather_label") as Label
    if weather != null:
        weather.text = "CLEAR DAY"
    var chevron := hud.get("bottom_chevron") as Control
    if chevron != null:
        chevron.visible = false

func _ground_material() -> StandardMaterial3D:
    var material := _material(Color(0.42, 0.48, 0.25), 0.94)
    var texture_path := "res://assets/habitat/pbr/forrest_ground_01_diff_4k.jpg"
    if ResourceLoader.exists(texture_path):
        material.albedo_texture = load(texture_path) as Texture2D
        material.albedo_color = Color(0.78, 0.84, 0.66)
        material.uv1_scale = Vector3(5.4, 5.4, 5.4)
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return material

func _water_material() -> StandardMaterial3D:
    var material := _material(Color(0.10, 0.31, 0.34), 0.22)
    material.metallic = 0.08
    return material

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.0
    return material

func _face(body: CharacterBody3D, target: Vector3, weight: float) -> void:
    var direction := target - body.global_position
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        return
    direction = direction.normalized()
    var target_yaw := atan2(-direction.z, direction.x)
    body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(weight, 0.0, 1.0))
    body.rotation.x = 0.0
    body.rotation.z = 0.0

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
