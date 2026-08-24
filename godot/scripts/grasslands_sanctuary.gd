extends Node

# Layered mobile grasslands art direction based on the approved sanctuary target.
# Final production animal GLBs still replace procedural companions when licensed assets
# are supplied, but the habitat itself is composed as foreground/midground/background
# instead of a flat prototype arena.

const POND_POS := Vector3(3.7, 0.0, 2.5)
const MUD_POS := Vector3(-3.7, 0.0, 2.8)

var scene_root: Node3D
var world_root: Node3D
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var update_timer := 0.0
var bound := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 165
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(300):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            break
        await get_tree().process_frame
    if scene_root == null:
        push_warning("GrasslandsSanctuary could not bind to the active sanctuary")
        return

    await get_tree().process_frame
    await get_tree().process_frame
    _build_grasslands_layer()
    _configure_environment()
    _update_daylight()
    bound = true
    set_process(true)

func _process(delta: float) -> void:
    if not bound:
        return
    update_timer -= delta
    if update_timer <= 0.0:
        update_timer = 2.0
        _update_daylight()

func _build_grasslands_layer() -> void:
    var old := scene_root.find_child("GrasslandsProductionLayer", true, false)
    if is_instance_valid(old):
        old.queue_free()

    world_root = Node3D.new()
    world_root.name = "GrasslandsProductionLayer"
    scene_root.add_child(world_root)

    _build_distant_ridges()
    _build_watercourse()
    _build_dirt_and_wet_ground()
    _build_grass_field()
    _build_acacia_groups()
    _build_shrub_groups()
    _build_rock_clusters()
    _build_shoreline_detail()
    _build_birds()

func _configure_environment() -> void:
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null:
        world_environment = WorldEnvironment.new()
        world_environment.name = "WorldEnvironment"
        scene_root.add_child(world_environment)
    if world_environment.environment == null:
        world_environment.environment = Environment.new()

    var environment := world_environment.environment
    var sky := Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_128
    sky_material = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.08, 0.34, 0.68)
    sky_material.sky_horizon_color = Color(0.80, 0.88, 0.88)
    sky_material.ground_bottom_color = Color(0.055, 0.070, 0.050)
    sky_material.ground_horizon_color = Color(0.42, 0.50, 0.31)
    sky_material.sun_angle_max = 16.0
    sky_material.sun_curve = 0.065
    sky_material.use_debanding = true
    sky.sky_material = sky_material

    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.76
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.72, 0.78, 0.70)
    environment.fog_light_energy = 0.50
    environment.fog_density = 0.009
    environment.fog_height = -0.5
    environment.fog_height_density = 0.065
    environment.fog_sky_affect = 0.30

    sun_light = scene_root.get("sun_light") as DirectionalLight3D
    if sun_light == null:
        sun_light = scene_root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
    if sun_light != null:
        sun_light.shadow_enabled = true
        sun_light.directional_shadow_max_distance = 42.0
        sun_light.directional_shadow_fade_start = 0.78

func _build_distant_ridges() -> void:
    var ridge_materials: Array[StandardMaterial3D] = [
        _material(Color(0.20, 0.27, 0.17), 0.98),
        _material(Color(0.25, 0.31, 0.19), 0.98),
        _material(Color(0.31, 0.34, 0.22), 0.97)
    ]
    var ridges: Array[Dictionary] = [
        {"p": Vector3(-5.8, 0.4, -11.5), "s": Vector3(5.6, 2.2, 2.1), "m": 0},
        {"p": Vector3(2.2, 0.2, -12.8), "s": Vector3(7.0, 2.8, 2.2), "m": 1},
        {"p": Vector3(8.5, 0.6, -11.0), "s": Vector3(5.2, 2.4, 1.8), "m": 0},
        {"p": Vector3(-10.5, 0.8, -13.5), "s": Vector3(4.6, 3.1, 2.0), "m": 2}
    ]
    for data in ridges:
        var ridge := MeshInstance3D.new()
        ridge.name = "DistantRidge"
        var sphere := SphereMesh.new()
        sphere.radial_segments = 24
        sphere.rings = 12
        ridge.mesh = sphere
        ridge.position = data["p"]
        ridge.scale = data["s"]
        ridge.material_override = ridge_materials[int(data["m"])]
        ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        world_root.add_child(ridge)

func _build_watercourse() -> void:
    var water_mesh := PlaneMesh.new()
    water_mesh.size = Vector2(8.4, 7.2)
    water_mesh.subdivide_width = 24
    water_mesh.subdivide_depth = 20

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
void vertex() {
    float w1 = sin((VERTEX.x + TIME * 0.42) * 2.15) * 0.018;
    float w2 = cos((VERTEX.z - TIME * 0.31) * 2.85) * 0.012;
    VERTEX.y += w1 + w2;
}
void fragment() {
    float ripple = sin((WORLD_MATRIX[3].x + VERTEX.x) * 2.2 + TIME * 0.9) * 0.5 + 0.5;
    ALBEDO = mix(vec3(0.075, 0.19, 0.22), vec3(0.16, 0.34, 0.35), ripple * 0.22);
    ROUGHNESS = 0.18;
    METALLIC = 0.08;
    SPECULAR = 0.78;
    ALPHA = 0.82;
}
"""
    var water_material := ShaderMaterial.new()
    water_material.shader = shader
    water_mesh.material = water_material

    var stream := MeshInstance3D.new()
    stream.name = "ForegroundWatercourse"
    stream.mesh = water_mesh
    stream.position = Vector3(1.7, 0.035, 2.3)
    stream.rotation_degrees.y = -7.0
    stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(stream)

func _build_dirt_and_wet_ground() -> void:
    var path := MeshInstance3D.new()
    path.name = "DryAnimalTrail"
    var path_mesh := PlaneMesh.new()
    path_mesh.size = Vector2(4.2, 7.0)
    path.mesh = path_mesh
    path.position = Vector3(4.2, 0.018, -0.4)
    path.rotation_degrees.y = 8.0
    path.material_override = _material(Color(0.32, 0.235, 0.145), 0.94)
    path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(path)

    var wet := MeshInstance3D.new()
    wet.name = "WetBank"
    var wet_mesh := PlaneMesh.new()
    wet_mesh.size = Vector2(6.8, 4.4)
    wet.mesh = wet_mesh
    wet.position = Vector3(-0.8, 0.024, 2.1)
    wet.rotation_degrees.y = -4.0
    var wet_material := _material(Color(0.16, 0.125, 0.080), 0.42)
    wet_material.metallic = 0.02
    wet.material_override = wet_material
    wet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(wet)

func _build_grass_field() -> void:
    var blade_mesh := QuadMesh.new()
    blade_mesh.size = Vector2(0.16, 0.84)

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
void vertex() {
    float sway = sin(TIME * 1.12 + VERTEX.x * 10.0 + INSTANCE_CUSTOM.x * 6.28) * 0.026;
    VERTEX.x += sway * UV.y;
}
void fragment() {
    float taper = (1.0 - UV.y) * 0.48 + 0.032;
    if (abs(UV.x - 0.5) > taper) { discard; }
    float tip = smoothstep(0.0, 1.0, UV.y);
    vec3 base = vec3(0.065, 0.155, 0.035);
    vec3 warm = vec3(0.30, 0.39, 0.11);
    ALBEDO = mix(base, warm, tip * 0.58);
    ROUGHNESS = 0.90;
    SPECULAR = 0.15;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    blade_mesh.material = material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_custom_data = true
    multi.mesh = blade_mesh
    multi.instance_count = 980

    var rng := RandomNumberGenerator.new()
    rng.seed = 608241
    var placed := 0
    var attempts := 0
    while placed < multi.instance_count and attempts < 10000:
        attempts += 1
        var x := rng.randf_range(-8.55, 8.55)
        var z := rng.randf_range(-6.55, 6.55)
        var p := Vector2(x, z)
        if p.distance_to(Vector2(POND_POS.x, POND_POS.z)) < 2.45:
            continue
        if p.distance_to(Vector2(MUD_POS.x, MUD_POS.z)) < 1.70:
            continue
        if absf(x - 4.2) < 1.25 and z > -3.4 and z < 3.0:
            continue
        var yaw := rng.randf_range(0.0, TAU)
        var width_scale := rng.randf_range(0.64, 1.32)
        var height_scale := rng.randf_range(0.48, 1.52)
        var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, 1.0))
        multi.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.39 * height_scale, z)))
        multi.set_instance_custom_data(placed, Color(rng.randf(), 0, 0, 1))
        placed += 1

    var grass := MultiMeshInstance3D.new()
    grass.name = "GrassField"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(grass)

func _build_acacia_groups() -> void:
    var positions: Array[Vector3] = [
        Vector3(-7.1, 0.0, -4.7),
        Vector3(-6.7, 0.0, 4.8),
        Vector3(6.7, 0.0, -4.8),
        Vector3(7.4, 0.0, 4.6),
        Vector3(-1.4, 0.0, 5.8),
        Vector3(1.9, 0.0, -6.0),
        Vector3(5.1, 0.0, -6.2)
    ]
    for i in range(positions.size()):
        var scale_value := 1.52 if i == 6 else 0.86 + float(i % 3) * 0.12
        _add_acacia(positions[i], scale_value, float(i) * 0.81)

func _add_acacia(origin: Vector3, scale_value: float, phase: float) -> void:
    var trunk_material := _material(Color(0.20, 0.135, 0.072), 0.96)
    var leaf_material := _material(Color(0.065, 0.205, 0.050), 0.90)
    var leaf_light := _material(Color(0.12, 0.31, 0.075), 0.88)

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.10 * scale_value
    trunk_mesh.bottom_radius = 0.23 * scale_value
    trunk_mesh.height = 3.05 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
    trunk.rotation_degrees.z = sin(phase) * 4.5
    trunk.material_override = trunk_material
    world_root.add_child(trunk)

    var canopy_y := trunk_mesh.height + 0.22 * scale_value
    for j in range(9):
        var canopy := MeshInstance3D.new()
        canopy.name = "AcaciaCanopy"
        var sphere := SphereMesh.new()
        sphere.radial_segments = 16
        sphere.rings = 8
        canopy.mesh = sphere
        var angle := TAU * float(j) / 9.0 + phase
        var radius := 0.48 + float(j % 3) * 0.12
        canopy.position = origin + Vector3(cos(angle) * radius * scale_value, canopy_y + sin(float(j) * 1.4) * 0.11, sin(angle) * radius * scale_value)
        canopy.scale = Vector3(1.10, 0.32, 0.86) * scale_value * (0.88 + float(j % 2) * 0.15)
        canopy.material_override = leaf_light if j % 3 == 0 else leaf_material
        canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        world_root.add_child(canopy)

func _build_shrub_groups() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 240825
    var mats: Array[StandardMaterial3D] = [
        _material(Color(0.09, 0.25, 0.055), 0.91),
        _material(Color(0.15, 0.30, 0.075), 0.90),
        _material(Color(0.22, 0.32, 0.10), 0.92)
    ]
    for i in range(38):
        var shrub := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radial_segments = 10
        mesh.rings = 6
        shrub.mesh = mesh
        var x := rng.randf_range(-8.0, 8.0)
        var z := rng.randf_range(-6.0, 6.0)
        var s := rng.randf_range(0.20, 0.46)
        shrub.position = Vector3(x, s * 0.48, z)
        shrub.scale = Vector3(s * 1.45, s * 0.72, s)
        shrub.material_override = mats[i % mats.size()]
        shrub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        world_root.add_child(shrub)

func _build_rock_clusters() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 120917
    var origins: Array[Vector3] = [
        Vector3(-5.6, 0.0, -2.8),
        Vector3(5.4, 0.0, -2.2),
        Vector3(-1.8, 0.0, 4.9),
        Vector3(1.2, 0.0, -4.9),
        Vector3(-6.4, 0.0, 1.3)
    ]
    for cluster in origins:
        for j in range(6):
            var rock := MeshInstance3D.new()
            var mesh := SphereMesh.new()
            mesh.radial_segments = 14
            mesh.rings = 8
            rock.mesh = mesh
            var s := rng.randf_range(0.28, 0.76)
            rock.scale = Vector3(s * rng.randf_range(0.82, 1.45), s * rng.randf_range(0.45, 0.82), s)
            rock.position = cluster + Vector3(rng.randf_range(-1.0, 1.0), rock.scale.y * 0.44, rng.randf_range(-0.75, 0.75))
            rock.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 180.0), rng.randf_range(-7.0, 7.0))
            rock.material_override = _material(Color(0.30 + rng.randf_range(-0.035, 0.045), 0.285, 0.235), 0.90)
            world_root.add_child(rock)

func _build_shoreline_detail() -> void:
    var reed_material := _material(Color(0.085, 0.29, 0.065), 0.92)
    for i in range(52):
        var angle := TAU * float(i) / 52.0
        if i % 9 == 0:
            continue
        var reed := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.007
        mesh.bottom_radius = 0.018
        mesh.height = 0.48 + float(i % 7) * 0.070
        reed.mesh = mesh
        var radial_x := 3.05 + sin(float(i) * 1.9) * 0.14
        var radial_z := 2.15 + cos(float(i) * 1.6) * 0.12
        reed.position = Vector3(POND_POS.x + cos(angle) * radial_x, mesh.height * 0.5, POND_POS.z + sin(angle) * radial_z)
        reed.rotation_degrees.z = sin(float(i) * 0.91) * 6.0
        reed.material_override = reed_material
        world_root.add_child(reed)

func _build_birds() -> void:
    var bird_material := _material(Color(0.07, 0.065, 0.055), 1.0)
    for i in range(5):
        var bird := MeshInstance3D.new()
        bird.name = "DistantBird"
        var quad := QuadMesh.new()
        quad.size = Vector2(0.22, 0.06)
        bird.mesh = quad
        bird.position = Vector3(-3.8 + float(i) * 1.7, 4.0 + sin(float(i)) * 0.55, -8.4 - float(i % 2))
        bird.rotation_degrees = Vector3(-12.0, float(i) * 17.0, 5.0)
        bird.material_override = bird_material
        bird.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        world_root.add_child(bird)

func _update_daylight() -> void:
    if scene_root == null:
        return
    var mode := "auto"
    var loaded_settings: Variant = scene_root.get("settings")
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        mode = str((loaded_settings as Dictionary).get("day_night_mode", "auto"))

    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
    if mode == "day":
        daylight = 1.0
    elif mode == "night":
        daylight = 0.0

    if sky_material != null:
        sky_material.sky_top_color = Color(0.018, 0.040, 0.105).lerp(Color(0.075, 0.36, 0.72), daylight)
        sky_material.sky_horizon_color = Color(0.11, 0.14, 0.22).lerp(Color(0.82, 0.89, 0.91), daylight)
        sky_material.ground_horizon_color = Color(0.055, 0.072, 0.060).lerp(Color(0.40, 0.47, 0.29), daylight)
        sky_material.sky_energy_multiplier = lerpf(0.48, 1.02, daylight)
        sky_material.ground_energy_multiplier = lerpf(0.32, 0.74, daylight)

    if sun_light != null:
        sun_light.light_color = Color(0.44, 0.55, 0.88).lerp(Color(1.0, 0.88, 0.70), daylight)
        sun_light.light_energy = lerpf(0.42, 1.48, daylight)
        sun_light.rotation_degrees = Vector3(lerpf(-24.0, -48.0, daylight), -36.0 + (hour - 12.0) * 2.4, 0.0)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
