extends Node

var host

func _ready():
    for i in range(9):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _upgrade_living_grass()

func _upgrade_living_grass():
    var grass = host.get_node_or_null("LivingGrass")
    if grass == null or not grass is MultiMeshInstance3D:
        return
    if grass.multimesh == null:
        return
    grass.multimesh.mesh = _build_grass_cluster_mesh()

func _build_grass_cluster_mesh():
    var surface = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    _add_blade_plane(surface, 0.0)
    _add_blade_plane(surface, PI * 0.5)
    surface.generate_normals()
    var mesh = surface.commit()
    mesh.surface_set_material(0, _grass_material())
    return mesh

func _add_blade_plane(surface, yaw):
    var basis = Basis(Vector3.UP, yaw)
    var left_bottom = basis * Vector3(-0.060, 0.0, 0.0)
    var right_bottom = basis * Vector3(0.060, 0.0, 0.0)
    var left_mid = basis * Vector3(-0.042, 0.31, 0.0)
    var right_mid = basis * Vector3(0.042, 0.31, 0.0)
    var tip = basis * Vector3(0.0, 0.58, 0.0)

    _tri(surface, left_bottom, right_bottom, right_mid, Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.55))
    _tri(surface, left_bottom, right_mid, left_mid, Vector2(0, 0), Vector2(1, 0.55), Vector2(0, 0.55))
    _tri(surface, left_mid, right_mid, tip, Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1))

func _tri(surface, a, b, c, uva, uvb, uvc):
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
uniform vec3 root_color = vec3(0.055, 0.18, 0.045);
uniform vec3 tip_color = vec3(0.18, 0.42, 0.11);
void vertex() {
    float bend = UV.y * UV.y;
    float phase = TIME * 1.15 + float(INSTANCE_ID) * 0.371;
    VERTEX.x += sin(phase) * 0.035 * bend;
    VERTEX.z += cos(phase * 0.73) * 0.024 * bend;
}
void fragment() {
    float variation = 0.92 + 0.08 * sin(float(INSTANCE_ID) * 1.713);
    vec3 grass = mix(root_color, tip_color, smoothstep(0.0, 1.0, UV.y)) * variation;
    ALBEDO = grass;
    ROUGHNESS = 0.88;
    SPECULAR = 0.20;
}
"""
    var material = ShaderMaterial.new()
    material.shader = shader
    return material
