extends Node

var host
var foliage_shader
var rock_shader

func _ready():
    process_priority = 28
    for i in range(13):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _build_shaders()
    _scan(host, false)

func _build_shaders():
    foliage_shader = Shader.new()
    foliage_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 leaf_color : source_color = vec4(0.07, 0.27, 0.08, 1.0);
varying vec3 local_pos;
varying vec3 world_pos;
void vertex() {
    vec3 origin = (MODEL_MATRIX * vec4(vec3(0.0), 1.0)).xyz;
    float irregular = sin(VERTEX.x * 7.7 + VERTEX.z * 5.3) * cos(VERTEX.y * 6.1) * 0.035;
    VERTEX += NORMAL * irregular;
    float crown = clamp(VERTEX.y + 0.25, 0.0, 1.0);
    float phase = origin.x * 0.17 + origin.z * 0.21;
    VERTEX.x += sin(TIME * 0.72 + phase) * 0.018 * crown;
    VERTEX.z += cos(TIME * 0.58 + phase * 1.3) * 0.012 * crown;
    local_pos = VERTEX;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float local_var = sin(local_pos.x * 11.0 + local_pos.y * 7.0 + local_pos.z * 9.0) * 0.5 + 0.5;
    float macro = sin(world_pos.x * 0.38 + world_pos.z * 0.29) * 0.5 + 0.5;
    vec3 dark_leaf = leaf_color.rgb * 0.70;
    vec3 light_leaf = leaf_color.rgb * 1.18;
    ALBEDO = mix(dark_leaf, light_leaf, clamp(local_var * 0.55 + macro * 0.45, 0.0, 1.0));
    ROUGHNESS = 0.88;
    SPECULAR = 0.16;
}
"""

    rock_shader = Shader.new()
    rock_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 rock_color : source_color = vec4(0.28, 0.27, 0.24, 1.0);
varying vec3 local_pos;
void vertex() {
    float n1 = sin(VERTEX.x * 8.7 + VERTEX.z * 6.3) * 0.035;
    float n2 = cos(VERTEX.y * 9.1 - VERTEX.x * 4.7) * 0.024;
    VERTEX += NORMAL * (n1 + n2);
    local_pos = VERTEX;
}
void fragment() {
    float fleck = sin(local_pos.x * 17.0 + local_pos.y * 13.0 + local_pos.z * 19.0) * 0.5 + 0.5;
    vec3 cool = rock_color.rgb * 0.78;
    vec3 warm = rock_color.rgb * vec3(1.10, 1.04, 0.92);
    ALBEDO = mix(cool, warm, fleck * 0.42);
    ROUGHNESS = 0.94;
    SPECULAR = 0.20;
}
"""

func _scan(node: Node, inside_tree: bool):
    var now_inside_tree = inside_tree or node.name == "OpenWorldTree"
    if node is MeshInstance3D:
        if node.name == "OpenWorldRock":
            _style_rock(node)
        elif now_inside_tree and node.mesh is SphereMesh:
            _style_crown(node)
    for child in node.get_children():
        _scan(child, now_inside_tree)

func _style_crown(crown: MeshInstance3D):
    var material = ShaderMaterial.new()
    material.shader = foliage_shader
    var base = Color(0.07, 0.26, 0.08)
    var current = crown.material_override
    if current is StandardMaterial3D:
        base = current.albedo_color
    material.set_shader_parameter("leaf_color", base)
    crown.material_override = material

func _style_rock(rock: MeshInstance3D):
    var material = ShaderMaterial.new()
    material.shader = rock_shader
    var base = Color(0.28, 0.27, 0.24)
    var current = rock.material_override
    if current is StandardMaterial3D:
        base = current.albedo_color
    material.set_shader_parameter("rock_color", base)
    rock.material_override = material
