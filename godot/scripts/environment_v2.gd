extends Node

var host
var environment
var terrain_root
var grass_multimesh
var pond_centers = [Vector2(2.0, 2.1)]
var mud_centers = [Vector2(-2.4, 2.1), Vector2(-8.0, -1.2)]

func _ready():
    await get_tree().process_frame
    await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    environment = host.get("environment")
    _hide_flat_development_geometry()
    _build_terrain()
    _upgrade_water_and_mud()
    _build_grass_field()
    _build_pond_edge()
    _build_hippo_cover()
    _build_pig_enrichment()
    _build_dog_yard()
    _build_shared_habitat()
    _apply_atmosphere()

func _hide_flat_development_geometry():
    for child in host.get_children():
        if child is MeshInstance3D:
            var mesh = child.mesh
            if mesh is BoxMesh and abs(child.position.y - 0.01) < 0.08:
                child.visible = false
            elif mesh is CylinderMesh and float(mesh.top_radius) < 0.14:
                child.visible = false

func _build_terrain():
    terrain_root = MeshInstance3D.new()
    terrain_root.name = "NaturalTerrain"
    var surface = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var cells_x = 56
    var cells_z = 36
    var min_x = -14.0
    var max_x = 14.0
    var min_z = -9.0
    var max_z = 9.0
    for ix in range(cells_x):
        for iz in range(cells_z):
            var x0 = lerp(min_x, max_x, float(ix) / float(cells_x))
            var x1 = lerp(min_x, max_x, float(ix + 1) / float(cells_x))
            var z0 = lerp(min_z, max_z, float(iz) / float(cells_z))
            var z1 = lerp(min_z, max_z, float(iz + 1) / float(cells_z))
            var p00 = Vector3(x0, _terrain_height(x0, z0), z0)
            var p10 = Vector3(x1, _terrain_height(x1, z0), z0)
            var p01 = Vector3(x0, _terrain_height(x0, z1), z1)
            var p11 = Vector3(x1, _terrain_height(x1, z1), z1)
            _terrain_triangle(surface, p00, p10, p11, min_x, max_x, min_z, max_z)
            _terrain_triangle(surface, p00, p11, p01, min_x, max_x, min_z, max_z)
    surface.generate_normals()
    var mesh = surface.commit()
    terrain_root.mesh = mesh
    var material = StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.96
    material.metallic = 0.0
    terrain_root.material_override = material
    host.add_child(terrain_root)

func _terrain_triangle(surface, a, b, c, min_x, max_x, min_z, max_z):
    for p in [a, b, c]:
        surface.set_color(_terrain_color(p.x, p.z, p.y))
        surface.set_uv(Vector2(inverse_lerp(min_x, max_x, p.x), inverse_lerp(min_z, max_z, p.z)))
        surface.add_vertex(p)

func _terrain_height(x, z):
    var rolling = sin(x * 0.38) * cos(z * 0.46) * 0.028
    rolling += sin((x + z) * 0.22) * 0.018
    var height = 0.075 + rolling
    var pond_distance = Vector2(x - 2.0, z - 2.1).length()
    if pond_distance < 3.1:
        height -= smoothstep(3.1, 0.0, pond_distance) * 0.10
    for center in mud_centers:
        var d = Vector2(x - center.x, z - center.y).length()
        if d < 2.2:
            height -= smoothstep(2.2, 0.0, d) * 0.045
    return height

func _terrain_color(x, z, height):
    var variation = sin(x * 1.7 + z * 0.63) * 0.5 + cos(z * 1.35 - x * 0.41) * 0.5
    var base = Color(0.105, 0.245, 0.105)
    if height < 0.025:
        base = Color(0.16, 0.205, 0.095)
    elif variation > 0.45:
        base = Color(0.125, 0.285, 0.115)
    elif variation < -0.45:
        base = Color(0.085, 0.205, 0.085)
    return base

func _upgrade_water_and_mud():
    for child in host.get_children():
        if not child is MeshInstance3D:
            continue
        var mesh = child.mesh
        if not mesh is CylinderMesh:
            continue
        var radius = float(mesh.top_radius)
        if radius >= 2.0:
            child.material_override = _water_material()
        elif radius >= 1.3:
            child.material_override = _mud_material()

func _water_material():
    var shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.018, 0.19, 0.23, 0.90);
uniform vec4 light_color : source_color = vec4(0.08, 0.48, 0.52, 0.90);
void vertex() {
    float wave = sin(UV.x * 31.0 + TIME * 1.4) * 0.012;
    wave += cos(UV.y * 27.0 - TIME * 1.1) * 0.009;
    VERTEX.y += wave;
}
void fragment() {
    float ripple = sin(UV.x * 52.0 + TIME * 1.7) * cos(UV.y * 46.0 - TIME * 1.2);
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
    vec3 water = mix(deep_color.rgb, light_color.rgb, 0.45 + ripple * 0.08 + fresnel * 0.35);
    ALBEDO = water;
    ROUGHNESS = mix(0.16, 0.055, fresnel);
    METALLIC = 0.08;
    SPECULAR = 0.72;
    ALPHA = 0.90;
}
"""
    var material = ShaderMaterial.new()
    material.shader = shader
    return material

func _mud_material():
    var shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
void fragment() {
    float a = sin(UV.x * 39.0 + sin(UV.y * 17.0) * 2.0);
    float b = cos(UV.y * 44.0 - UV.x * 9.0);
    float wet = clamp(0.5 + (a + b) * 0.11, 0.0, 1.0);
    vec3 dry_mud = vec3(0.22, 0.125, 0.058);
    vec3 wet_mud = vec3(0.095, 0.050, 0.026);
    ALBEDO = mix(dry_mud, wet_mud, wet);
    ROUGHNESS = mix(0.82, 0.34, wet);
    SPECULAR = mix(0.28, 0.56, wet);
}
"""
    var material = ShaderMaterial.new()
    material.shader = shader
    return material

func _build_grass_field():
    var blade = QuadMesh.new()
    blade.size = Vector2(0.13, 0.48)
    var grass_material = StandardMaterial3D.new()
    grass_material.albedo_color = Color(0.10, 0.31, 0.095)
    grass_material.roughness = 0.92
    grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade.material = grass_material

    var transforms = []
    var rng = RandomNumberGenerator.new()
    rng.seed = 845179
    for i in range(680):
        var x = rng.randf_range(-13.2, 13.2)
        var z = rng.randf_range(-8.2, 8.2)
        if _avoid_grass(x, z):
            continue
        var y = _terrain_height(x, z) + 0.20
        var angle = rng.randf_range(0.0, TAU)
        var height_scale = rng.randf_range(0.55, 1.55)
        var width_scale = rng.randf_range(0.65, 1.25)
        var basis = Basis.IDENTITY.rotated(Vector3.UP, angle).scaled(Vector3(width_scale, height_scale, width_scale))
        transforms.append(Transform3D(basis, Vector3(x, y, z)))

    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = blade
    mm.instance_count = transforms.size()
    for i in range(transforms.size()):
        mm.set_instance_transform(i, transforms[i])
    grass_multimesh = MultiMeshInstance3D.new()
    grass_multimesh.name = "LivingGrass"
    grass_multimesh.multimesh = mm
    host.add_child(grass_multimesh)

func _avoid_grass(x, z):
    if Vector2(x - 2.0, z - 2.1).length() < 3.25:
        return true
    for center in mud_centers:
        if Vector2(x - center.x, z - center.y).length() < 2.1:
            return true
    if abs(x) < 1.25 and z < 1.0:
        return true
    return false

func _build_pond_edge():
    _add_reed_ring(Vector3(2.0, 0.05, 2.1), 3.0, 42)
    for i in range(14):
        var angle = TAU * float(i) / 14.0 + 0.17
        var radius = 2.85 + sin(float(i) * 2.3) * 0.22
        var pos = Vector3(2.0 + cos(angle) * radius, 0.13, 2.1 + sin(angle) * radius)
        _add_rock(pos, 0.20 + float(i % 4) * 0.045)

func _add_reed_ring(center, radius, count):
    for i in range(count):
        var angle = TAU * float(i) / float(count) + sin(float(i) * 1.71) * 0.15
        var r = radius + sin(float(i) * 2.07) * 0.28
        var pos = center + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
        var height = 0.68 + float(i % 5) * 0.13
        _add_reed(pos, height)

func _add_reed(pos, height):
    var reed = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = 0.012
    mesh.bottom_radius = 0.028
    mesh.height = height
    reed.mesh = mesh
    reed.position = pos + Vector3(0.0, height * 0.5, 0.0)
    reed.rotation_degrees.z = randf_range(-4.0, 4.0)
    reed.material_override = _standard(Color(0.12, randf_range(0.28, 0.40), 0.11), 0.88)
    host.add_child(reed)

func _build_hippo_cover():
    _add_log(Vector3(-2.0, 0.23, -0.6), 1.7, 0.24, 18.0)
    _add_shrub_mass(Vector3(-2.9, 0.0, -1.2), 1.2, Color(0.075, 0.27, 0.095))
    _add_shrub_mass(Vector3(-1.6, 0.0, -2.0), 1.0, Color(0.065, 0.24, 0.085))
    _add_shrub_mass(Vector3(3.5, 0.0, -1.9), 0.9, Color(0.08, 0.29, 0.10))

func _build_pig_enrichment():
    _add_log(Vector3(-9.0, 0.22, -3.9), 1.4, 0.19, -24.0)
    _add_log(Vector3(-6.7, 0.18, -3.6), 1.0, 0.16, 38.0)
    for p in [Vector3(-9.7, 0.16, -0.5), Vector3(-6.1, 0.16, -1.0), Vector3(-9.8, 0.16, -4.8)]:
        _add_rock(p, 0.34)
    _add_shelter(Vector3(-8.4, 0.0, -5.1), Color(0.26, 0.17, 0.09))

func _build_dog_yard():
    _add_shelter(Vector3(8.4, 0.0, -5.0), Color(0.19, 0.16, 0.12))
    _add_shrub_mass(Vector3(10.4, 0.0, -3.8), 0.85, Color(0.09, 0.30, 0.11))
    _add_shrub_mass(Vector3(6.0, 0.0, -4.7), 0.75, Color(0.08, 0.27, 0.10))
    _add_log(Vector3(8.8, 0.18, -0.2), 1.1, 0.15, 70.0)

func _build_shared_habitat():
    for p in [Vector3(-12.2, 0.0, 5.7), Vector3(-10.2, 0.0, 6.8), Vector3(10.8, 0.0, 5.8), Vector3(12.2, 0.0, 3.6), Vector3(-3.4, 0.0, 6.9), Vector3(5.1, 0.0, 6.7)]:
        _add_shrub_mass(p, randf_range(0.85, 1.25), Color(0.07, randf_range(0.23, 0.34), 0.09))

func _add_log(pos, length, radius, yaw_degrees):
    var log = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius * 0.88
    mesh.bottom_radius = radius
    mesh.height = length
    log.mesh = mesh
    log.position = pos
    log.rotation_degrees = Vector3(0.0, yaw_degrees, 90.0)
    log.material_override = _standard(Color(0.22, 0.125, 0.065), 0.94)
    host.add_child(log)

func _add_shelter(pos, tint):
    var root = Node3D.new()
    root.name = "HabitatShelter"
    root.position = pos
    host.add_child(root)
    for x in [-1.0, 1.0]:
        for z in [-0.7, 0.7]:
            var post = MeshInstance3D.new()
            var post_mesh = CylinderMesh.new()
            post_mesh.top_radius = 0.075
            post_mesh.bottom_radius = 0.095
            post_mesh.height = 1.45
            post.mesh = post_mesh
            post.position = Vector3(x, 0.73, z)
            post.material_override = _standard(Color(0.20, 0.12, 0.06), 0.92)
            root.add_child(post)
    var roof = MeshInstance3D.new()
    var roof_mesh = BoxMesh.new()
    roof_mesh.size = Vector3(2.5, 0.16, 2.0)
    roof.mesh = roof_mesh
    roof.position = Vector3(0.0, 1.55, 0.0)
    roof.rotation_degrees.z = -4.0
    roof.material_override = _standard(tint, 0.90)
    root.add_child(roof)

func _add_shrub_mass(pos, scale_value, color):
    var root = Node3D.new()
    root.position = pos
    host.add_child(root)
    var trunk = MeshInstance3D.new()
    var trunk_mesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.07 * scale_value
    trunk_mesh.bottom_radius = 0.11 * scale_value
    trunk_mesh.height = 0.65 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position.y = 0.32 * scale_value
    trunk.material_override = _standard(Color(0.18, 0.105, 0.055), 0.95)
    root.add_child(trunk)
    var offsets = [Vector3(-0.30, 0.72, 0.02), Vector3(0.30, 0.78, 0.10), Vector3(0.02, 0.98, -0.10), Vector3(0.05, 0.67, 0.31)]
    for i in range(offsets.size()):
        var crown = MeshInstance3D.new()
        var sphere = SphereMesh.new()
        sphere.radius = 0.44
        sphere.height = 0.86
        crown.mesh = sphere
        crown.position = offsets[i] * scale_value
        crown.scale = Vector3(0.78, 0.54, 0.70) * scale_value * (0.88 + float(i % 3) * 0.08)
        crown.material_override = _standard(color.lightened(float(i) * 0.025), 0.91)
        root.add_child(crown)

func _add_rock(pos, scale_value):
    var rock = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 0.8
    rock.mesh = mesh
    rock.position = pos
    rock.scale = Vector3(scale_value * 1.25, scale_value * 0.62, scale_value)
    rock.rotation_degrees.y = randf_range(0.0, 180.0)
    rock.material_override = _standard(Color(0.24, 0.255, 0.225), 0.91)
    host.add_child(rock)

func _apply_atmosphere():
    if environment == null:
        return
    environment.ambient_light_energy = max(float(environment.ambient_light_energy), 1.0)
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.43, 0.54, 0.48)
    environment.fog_light_energy = 0.48
    environment.fog_density = 0.0065
    environment.fog_sky_affect = 0.34

func _standard(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
