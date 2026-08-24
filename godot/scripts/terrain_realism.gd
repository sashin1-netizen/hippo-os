extends Node

const GRASS_DIFF := "res://assets/textures/leafy_grass_diff_4k.jpg"
const GRASS_NORMAL := "res://assets/textures/leafy_grass_nor_gl_4k.jpg"
const GRASS_ROUGH := "res://assets/textures/leafy_grass_rough_4k.jpg"
const MUD_DIFF := "res://assets/textures/brown_mud_03_diff_4k.jpg"
const MUD_NORMAL := "res://assets/textures/brown_mud_03_nor_gl_4k.jpg"
const MUD_ROUGH := "res://assets/textures/brown_mud_03_rough_4k.jpg"

var host

func _ready():
    process_priority = 24
    for i in range(8):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _style_outer_terrain()
    _style_trails()

func _style_outer_terrain():
    var terrain = host.get_node_or_null("OpenWorldTerrain")
    if terrain == null or not terrain is MeshInstance3D:
        push_error("OpenWorldTerrain missing for realism material pass")
        return
    var material = _terrain_material()
    if material != null:
        terrain.material_override = material

func _style_trails():
    for child in host.get_children():
        if child is MeshInstance3D and child.name == "SanctuaryTrail":
            child.material_override = _trail_material()

func _terrain_material():
    if not _all_exist([GRASS_DIFF, GRASS_NORMAL, GRASS_ROUGH]):
        return null
    var shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_scale = 2.65;
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 tuv = UV * tile_scale;
    vec3 base = texture(grass_diff, tuv).rgb;
    float macro = sin(world_pos.x * 0.17) * cos(world_pos.z * 0.14);
    macro += sin((world_pos.x + world_pos.z) * 0.055) * 0.55;
    float slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
    vec3 dry_tint = vec3(0.34, 0.31, 0.17);
    vec3 shaded = base * (0.95 + macro * 0.055);
    shaded = mix(shaded, dry_tint, clamp(slope * 0.28, 0.0, 0.24));
    ALBEDO = shaded;
    NORMAL_MAP = texture(grass_normal, tuv).rgb;
    NORMAL_MAP_DEPTH = 0.68;
    ROUGHNESS = clamp(texture(grass_rough, tuv).r * 0.96, 0.55, 1.0);
    SPECULAR = 0.22;
}
"""
    var material = ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("grass_diff", load(GRASS_DIFF))
    material.set_shader_parameter("grass_normal", load(GRASS_NORMAL))
    material.set_shader_parameter("grass_rough", load(GRASS_ROUGH))
    return material

func _trail_material():
    if not _all_exist([MUD_DIFF, MUD_NORMAL, MUD_ROUGH]):
        return null
    var shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D mud_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_scale = 1.75;
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 tuv = UV * tile_scale;
    vec3 base = texture(mud_diff, tuv).rgb;
    float damp = 0.5 + 0.5 * sin(world_pos.x * 0.41 + world_pos.z * 0.27);
    ALBEDO = base * mix(0.76, 1.02, damp);
    NORMAL_MAP = texture(mud_normal, tuv).rgb;
    NORMAL_MAP_DEPTH = 0.78;
    ROUGHNESS = clamp(texture(mud_rough, tuv).r * mix(0.72, 0.96, damp), 0.32, 0.96);
    SPECULAR = mix(0.42, 0.24, damp);
}
"""
    var material = ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("mud_diff", load(MUD_DIFF))
    material.set_shader_parameter("mud_normal", load(MUD_NORMAL))
    material.set_shader_parameter("mud_rough", load(MUD_ROUGH))
    return material

func _all_exist(paths: Array) -> bool:
    for path in paths:
        if not ResourceLoader.exists(str(path)):
            push_error("Terrain realism asset missing: %s" % str(path))
            return false
    return true
