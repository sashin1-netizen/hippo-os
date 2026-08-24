extends Node

# Production-direction sanctuary dressing for the approved Grasslands Sanctuary target.
# Final 1.0 still requires approved production habitat/model assets; this layer improves
# lighting, sky, depth, vegetation density and environmental composition in real time.

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
    for _attempt in range(240):
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
        update_timer = 2.5
        _update_daylight()

func _build_grasslands_layer() -> void:
    var old := scene_root.find_child("GrasslandsProductionLayer", true, false)
    if is_instance_valid(old):
        old.queue_free()

    world_root = Node3D.new()
    world_root.name = "GrasslandsProductionLayer"
    scene_root.add_child(world_root)

    _build_grass_field()
    _build_acacia_groups()
    _build_rock_clusters()
    _build_shoreline_detail()

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
    sky_material = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.12, 0.31, 0.58)
    sky_material.sky_horizon_color = Color(0.72, 0.80, 0.79)
    sky_material.ground_bottom_color = Color(0.08, 0.10, 0.08)
    sky_material.ground_horizon_color = Color(0.42, 0.48, 0.35)
    sky_material.sun_angle_max = 18.0
    sky_material.sun_curve = 0.07
    sky.sky_material = sky_material

    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.62
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.68, 0.74, 0.66)
    environment.fog_light_energy = 0.44
    environment.fog_density = 0.012
    environment.fog_height = 0.0
    environment.fog_height_density = 0.085
    environment.fog_sky_affect = 0.38

    sun_light = scene_root.get("sun_light") as DirectionalLight3D
    if sun_light == null:
        sun_light = scene_root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
    if sun_light != null:
        sun_light.shadow_enabled = true
        sun_light.directional_shadow_max_distance = 36.0
        sun_light.directional_shadow_fade_start = 0.74

func _build_grass_field() -> void:
    var blade_mesh := QuadMesh.new()
    blade_mesh.size = Vector2(0.16, 0.72)

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
void vertex() {
    float sway = sin(TIME * 1.35 + VERTEX.x * 11.0 + VERTEX.y * 4.0) * 0.022;
    VERTEX.x += sway * UV.y;
}
void fragment() {
    float taper = (1.0 - UV.y) * 0.48 + 0.035;
    if (abs(UV.x - 0.5) > taper) { discard; }
    float tip = smoothstep(0.0, 1.0, UV.y);
    vec3 base = vec3(0.075, 0.205, 0.060);
    vec3 sunlit = vec3(0.185, 0.345, 0.090);
    ALBEDO = mix(base, sunlit, tip * 0.58);
    ROUGHNESS = 0.88;
    SPECULAR = 0.18;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    blade_mesh.material = material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade_mesh
    multi.instance_count = 420

    var rng := RandomNumberGenerator.new()
    rng.seed = 608241
    var placed := 0
    var attempts := 0
    while placed < multi.instance_count and attempts < 5000:
        attempts += 1
        var x := rng.randf_range(-8.35, 8.35)
        var z := rng.randf_range(-6.35, 6.35)
        var point2 := Vector2(x, z)
        if point2.distance_to(Vector2(POND_POS.x, POND_POS.z)) < 3.05:
            continue
        if point2.distance_to(Vector2(MUD_POS.x, MUD_POS.z)) < 1.95:
            continue
        var yaw := rng.randf_range(0.0, TAU)
        var width_scale := rng.randf_range(0.72, 1.28)
        var height_scale := rng.randf_range(0.56, 1.38)
        var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, 1.0))
        multi.set_instance_transform(placed, Transform3D(basis, Vector3(x, 0.34 * height_scale, z)))
        placed += 1

    var grass := MultiMeshInstance3D.new()
    grass.name = "GrassField"
    grass.multimesh = multi
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(grass)

func _build_acacia_groups() -> void:
    var positions: Array[Vector3] = [
        Vector3(-7.2, 0.0, -4.8),
        Vector3(-6.6, 0.0, 4.8),
        Vector3(6.9, 0.0, -4.5),
        Vector3(7.4, 0.0, 4.5),
        Vector3(-1.4, 0.0, 5.7),
        Vector3(2.1, 0.0, -5.8)
    ]
    for i in range(positions.size()):
        _add_acacia(positions[i], 0.88 + float(i % 3) * 0.10, float(i) * 0.81)

func _add_acacia(origin: Vector3, scale_value: float, phase: float) -> void:
    var trunk_material := _material(Color(0.21, 0.145, 0.075), 0.94)
    var leaf_material := _material(Color(0.075, 0.245, 0.075), 0.88)
    var leaf_light := _material(Color(0.115, 0.315, 0.085), 0.86)

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.11 * scale_value
    trunk_mesh.bottom_radius = 0.22 * scale_value
    trunk_mesh.height = 2.95 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
    trunk.rotation_degrees.z = sin(phase) * 4.0
    trunk.material_override = trunk_material
    world_root.add_child(trunk)

    var canopy_y := trunk_mesh.height + 0.25 * scale_value
    for j in range(7):
        var canopy := MeshInstance3D.new()
        canopy.name = "AcaciaCanopy"
        var sphere := SphereMesh.new()
        sphere.radial_segments = 12
        sphere.rings = 6
        canopy.mesh = sphere
        var angle := TAU * float(j) / 7.0 + phase
        var radius := 0.46 + float(j % 3) * 0.11
        canopy.position = origin + Vector3(cos(angle) * radius * scale_value, canopy_y + sin(float(j) * 1.4) * 0.10, sin(angle) * radius * scale_value)
        canopy.scale = Vector3(1.05, 0.34, 0.84) * scale_value * (0.88 + float(j % 2) * 0.14)
        canopy.material_override = leaf_light if j % 3 == 0 else leaf_material
        canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        world_root.add_child(canopy)

func _build_rock_clusters() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 120917
    var origins: Array[Vector3] = [
        Vector3(-5.6, 0.0, -2.8),
        Vector3(5.4, 0.0, -2.2),
        Vector3(-1.8, 0.0, 4.9),
        Vector3(1.2, 0.0, -4.9)
    ]
    for cluster in origins:
        for j in range(5):
            var rock := MeshInstance3D.new()
            var mesh := SphereMesh.new()
            mesh.radial_segments = 10
            mesh.rings = 6
            rock.mesh = mesh
            var s := rng.randf_range(0.28, 0.68)
            rock.scale = Vector3(s * rng.randf_range(0.85, 1.35), s * rng.randf_range(0.48, 0.82), s)
            rock.position = cluster + Vector3(rng.randf_range(-0.9, 0.9), rock.scale.y * 0.44, rng.randf_range(-0.7, 0.7))
            rock.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 180.0), rng.randf_range(-7.0, 7.0))
            rock.material_override = _material(Color(0.31 + rng.randf_range(-0.035, 0.035), 0.30, 0.26), 0.89)
            world_root.add_child(rock)

func _build_shoreline_detail() -> void:
    var reed_material := _material(Color(0.095, 0.32, 0.085), 0.91)
    for i in range(32):
        var angle := TAU * float(i) / 32.0
        if i % 7 == 0:
            continue
        var reed := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.008
        mesh.bottom_radius = 0.020
        mesh.height = 0.52 + float(i % 5) * 0.075
        reed.mesh = mesh
        var radial_x := 3.12 + sin(float(i) * 1.9) * 0.10
        var radial_z := 2.18 + cos(float(i) * 1.6) * 0.09
        reed.position = Vector3(POND_POS.x + cos(angle) * radial_x, mesh.height * 0.5, POND_POS.z + sin(angle) * radial_z)
        reed.rotation_degrees.z = sin(float(i) * 0.91) * 5.0
        reed.material_override = reed_material
        world_root.add_child(reed)

func _update_daylight() -> void:
    if scene_root == null:
        return
    var mode := "auto"
    var loaded_settings: Variant = scene_root.get("settings")
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        mode = str((loaded_settings as Dictionary).get("day_night_mode", "auto"))

    var hour := float(Time.get_time_dict_from_system().get("hour", 12))
    var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
    if mode == "day":
        daylight = 1.0
    elif mode == "night":
        daylight = 0.0

    if sky_material != null:
        sky_material.sky_top_color = Color(0.018, 0.035, 0.095).lerp(Color(0.10, 0.35, 0.70), daylight)
        sky_material.sky_horizon_color = Color(0.12, 0.13, 0.19).lerp(Color(0.83, 0.79, 0.62), daylight)
        sky_material.ground_horizon_color = Color(0.055, 0.070, 0.060).lerp(Color(0.37, 0.43, 0.28), daylight)

    if sun_light != null:
        sun_light.light_color = Color(0.32, 0.42, 0.76).lerp(Color(1.0, 0.82, 0.58), daylight)
        sun_light.light_energy = lerpf(0.20, 1.55, daylight)
        sun_light.rotation_degrees = Vector3(lerpf(-24.0, -49.0, daylight), -36.0 + (hour - 12.0) * 2.4, 0.0)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
