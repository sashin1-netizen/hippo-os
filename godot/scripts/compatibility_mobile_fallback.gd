extends Node

# Renderer-specific fallback for Android emulators and devices that must use Godot's
# Compatibility renderer. The production Mobile/Vulkan world remains untouched on normal
# phones. Compatibility mode gets a clean, low-overdraw open world instead of malformed
# MultiMesh vegetation and unsupported shader output.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.90, 0.72, 3.55)
const DOG_HOME := Vector3(-4.15, 0.75, -2.65)
const HOLD_SECONDS := 35.0

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
        scene_root.set("orbit_pitch", -0.045)
        scene_root.set("orbit_distance", 9.0)
        camera.fov = lerpf(camera.fov, 45.0, clampf(delta * 7.0, 0.0, 1.0))
        _face(hippo, camera.global_position, clampf(delta * 14.0, 0.0, 1.0))
        _face(pig, hippo.global_position, clampf(delta * 9.0, 0.0, 1.0))
        _face(dog, hippo.global_position, clampf(delta * 9.0, 0.0, 1.0))

    maintenance_timer -= delta
    if maintenance_timer <= 0.0:
        maintenance_timer = 0.12
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

    var ground := MeshInstance3D.new()
    ground.name = "CompatibilityGround"
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(34.0, 26.0)
    ground.mesh = ground_mesh
    ground.position = Vector3(-3.0, 0.012, 0.0)
    ground.material_override = _material(Color(0.25, 0.315, 0.14), 0.96)
    fallback_world.add_child(ground)

    var wet_bank := MeshInstance3D.new()
    wet_bank.name = "CompatibilityWetBank"
    var wet_mesh := PlaneMesh.new()
    wet_mesh.size = Vector2(8.8, 6.4)
    wet_bank.mesh = wet_mesh
    wet_bank.position = Vector3(0.6, 0.026, 2.0)
    wet_bank.material_override = _material(Color(0.22, 0.155, 0.085), 0.74)
    fallback_world.add_child(wet_bank)

    var water := MeshInstance3D.new()
    water.name = "CompatibilityWatercourse"
    var water_mesh := PlaneMesh.new()
    water_mesh.size = Vector2(6.4, 7.2)
    water.mesh = water_mesh
    water.position = Vector3(2.2, 0.040, 2.35)
    water.rotation_degrees.y = -7.0
    water.material_override = _material(Color(0.105, 0.215, 0.185), 0.30)
    fallback_world.add_child(water)

    var ridge_materials: Array[StandardMaterial3D] = [
        _material(Color(0.22, 0.25, 0.15), 0.98),
        _material(Color(0.30, 0.29, 0.18), 0.98),
        _material(Color(0.37, 0.34, 0.22), 0.97)
    ]
    var ridge_positions: Array[Vector3] = [
        Vector3(-10.0, 1.7, -6.5), Vector3(-13.8, 2.2, 0.0),
        Vector3(-11.2, 1.5, 6.6), Vector3(-18.0, 3.0, -1.0)
    ]
    var ridge_scales: Array[Vector3] = [
        Vector3(5.4, 2.6, 4.4), Vector3(6.2, 3.4, 5.2),
        Vector3(5.0, 2.4, 4.0), Vector3(7.0, 4.2, 6.2)
    ]
    for i in range(ridge_positions.size()):
        var ridge := MeshInstance3D.new()
        ridge.name = "CompatibilityRidge"
        var sphere := SphereMesh.new()
        sphere.radial_segments = 20
        sphere.rings = 10
        ridge.mesh = sphere
        ridge.position = ridge_positions[i]
        ridge.scale = ridge_scales[i]
        ridge.material_override = ridge_materials[i % ridge_materials.size()]
        ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        fallback_world.add_child(ridge)

    var rock_material := _material(Color(0.34, 0.33, 0.28), 0.95)
    var rock_positions: Array[Vector3] = [
        Vector3(-1.0, 0.30, -4.4), Vector3(3.8, 0.38, -3.7),
        Vector3(5.5, 0.28, 4.7), Vector3(-2.6, 0.24, 5.0),
        Vector3(6.0, 0.20, 0.4), Vector3(-5.2, 0.25, -2.8)
    ]
    for i in range(rock_positions.size()):
        var rock := MeshInstance3D.new()
        rock.name = "CompatibilityRock"
        var rock_mesh := SphereMesh.new()
        rock_mesh.radial_segments = 14
        rock_mesh.rings = 8
        rock.mesh = rock_mesh
        rock.position = rock_positions[i]
        rock.scale = Vector3(0.55 + float(i % 3) * 0.18, 0.30 + float(i % 2) * 0.10, 0.50 + float((i + 1) % 3) * 0.16)
        rock.material_override = rock_material
        fallback_world.add_child(rock)

    var bush_dark := _material(Color(0.10, 0.23, 0.055), 0.96)
    var bush_light := _material(Color(0.18, 0.31, 0.075), 0.94)
    for i in range(18):
        var bush := MeshInstance3D.new()
        bush.name = "CompatibilityBush"
        var bush_mesh := SphereMesh.new()
        bush_mesh.radial_segments = 10
        bush_mesh.rings = 6
        bush.mesh = bush_mesh
        var side := -1.0 if i % 2 == 0 else 1.0
        bush.position = Vector3(-5.5 - float(i % 6) * 0.75, 0.30, side * (4.6 + float(i % 4) * 0.65))
        bush.scale = Vector3(0.75, 0.28, 0.62) * (0.72 + float(i % 3) * 0.12)
        bush.material_override = bush_light if i % 3 == 0 else bush_dark
        bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        fallback_world.add_child(bush)

func _apply_reference_daylight() -> void:
    var sky_color := Color(0.24, 0.61, 0.91)
    RenderingServer.set_default_clear_color(sky_color)
    var environments := scene_root.find_children("*", "WorldEnvironment", true, false)
    for node in environments:
        var world_environment := node as WorldEnvironment
        if world_environment != null and world_environment.environment != null:
            _configure_environment(world_environment.environment, sky_color)
    if camera != null:
        var camera_environment: Variant = camera.get("environment")
        if camera_environment is Environment:
            _configure_environment(camera_environment as Environment, sky_color)

func _configure_environment(env: Environment, sky_color: Color) -> void:
    env.background_mode = Environment.BG_COLOR
    env.background_color = sky_color
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.84, 0.86, 0.76)
    env.ambient_light_energy = 1.14
    env.fog_enabled = true
    env.fog_light_color = Color(0.82, 0.87, 0.83)
    env.fog_light_energy = 0.50
    env.fog_density = 0.0020
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.13
    env.adjustment_contrast = 1.02
    env.adjustment_saturation = 0.98

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
    scene_root.set("orbit_pitch", -0.045)
    scene_root.set("orbit_distance", 9.0)
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
