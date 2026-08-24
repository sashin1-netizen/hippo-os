extends Node

const HALF_X := 45.0
const HALF_Z := 29.0
const GRASS_COUNT := 4200

var host
var world_builder
var rng := RandomNumberGenerator.new()

func _ready():
    process_priority = 26
    rng.seed = 517339
    for i in range(10):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    world_builder = host.get_node_or_null("OpenWorldEnvironment")
    _retire_legacy_grass()
    _build_living_grass()

func _retire_legacy_grass():
    var legacy = host.get_node_or_null("LivingGrass")
    if legacy != null:
        legacy.visible = false
        legacy.name = "LegacyGrass"

func _build_living_grass():
    if world_builder == null or not world_builder.has_method("terrain_height"):
        push_error("OpenWorldEnvironment missing for foliage realism")
        return
    var blade_mesh = _blade_mesh()
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = blade_mesh

    var transforms: Array[Transform3D] = []
    for i in range(GRASS_COUNT):
        var x = rng.randf_range(-HALF_X, HALF_X)
        var z = rng.randf_range(-HALF_Z, HALF_Z)
        if _avoid_position(x, z):
            continue
        var y = float(world_builder.call("terrain_height", x, z)) + 0.015
        var yaw = rng.randf_range(0.0, TAU)
        var width = rng.randf_range(0.72, 1.22)
        var height = rng.randf_range(0.58, 1.55)
        var basis = Basis.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3(width, height, width))
        transforms.append(Transform3D(basis, Vector3(x, y, z)))

    mm.instance_count = transforms.size()
    for i in range(transforms.size()):
        mm.set_instance_transform(i, transforms[i])

    var field = MultiMeshInstance3D.new()
    field.name = "LivingGrass"
    field.multimesh = mm
    field.visibility_range_end = 42.0
    field.visibility_range_end_margin = 7.0
    host.add_child(field)

func _blade_mesh():
    var surface = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _add_blade_plane(surface, false)
    _add_blade_plane(surface, true)
    surface.generate_normals()
    var mesh = surface.commit()
    mesh.surface_set_material(0, _grass_material())
    return mesh

func _add_blade_plane(surface: SurfaceTool, rotate_plane: bool):
    var a = Vector3(-0.055, 0.0, 0.0)
    var b = Vector3(0.055, 0.0, 0.0)
    var c = Vector3(0.020, 0.48, 0.0)
    var d = Vector3(-0.020, 0.48, 0.0)
    if rotate_plane:
        a = Vector3(0.0, 0.0, -0.055)
        b = Vector3(0.0, 0.0, 0.055)
        c = Vector3(0.0, 0.48, 0.020)
        d = Vector3(0.0, 0.48, -0.020)
    _tri(surface, a, b, c, Vector2(0, 0), Vector2(1, 0), Vector2(0.68, 1))
    _tri(surface, a, c, d, Vector2(0, 0), Vector2(0.68, 1), Vector2(0.32, 1))

func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2):
    surface.set_uv(uva)
    surface.add_vertex(a)
    surface.set_uv(uvb)
    surface.add_vertex(b)
    surface.set_uv(uvc)
    surface.add_vertex(c)

func _grass_material():
    var shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 grass_color : source_color = vec4(0.12, 0.30, 0.10, 1.0);
varying vec3 world_pos;
void vertex() {
    vec3 origin = (MODEL_MATRIX * vec4(vec3(0.0), 1.0)).xyz;
    float influence = clamp(VERTEX.y / 0.48, 0.0, 1.0);
    float phase = origin.x * 0.29 + origin.z * 0.43;
    VERTEX.x += sin(TIME * 1.35 + phase) * 0.040 * influence;
    VERTEX.z += cos(TIME * 1.08 + phase * 1.17) * 0.025 * influence;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float macro = sin(world_pos.x * 0.61 + world_pos.z * 0.37) * 0.5 + 0.5;
    vec3 dry = vec3(0.23, 0.29, 0.10);
    vec3 lush = grass_color.rgb;
    ALBEDO = mix(dry, lush, 0.62 + macro * 0.30);
    ROUGHNESS = 0.90;
    SPECULAR = 0.18;
}
"""
    var material = ShaderMaterial.new()
    material.shader = shader
    return material

func _avoid_position(x: float, z: float) -> bool:
    if Vector2(x - 2.0, z - 2.1).length() < 3.5:
        return true
    if Vector2(x + 2.4, z - 2.1).length() < 2.4:
        return true
    if Vector2(x + 8.0, z + 1.2).length() < 2.3:
        return true
    if z > 4.0:
        var stream_x = 3.3 + sin(z * 0.16) * 2.2
        if abs(x - stream_x) < 2.1:
            return true
    # Keep the most-used walking routes readable rather than burying them in grass.
    if abs(z + 6.5) < 0.85 and abs(x) > 5.0:
        return true
    if abs(x) < 1.1 and z > 5.0:
        return true
    return false
