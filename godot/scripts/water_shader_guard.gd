extends Node

# Replaces the dynamically-created sanctuary water material with a Godot 4 mobile-safe
# shader before the first user-visible interaction. This avoids fragment-stage access
# to vertex/world variables that are not portable across Android GPU drivers.

var scene_root: Node3D
var applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 230
    call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            var water := scene_root.find_child("ForegroundWatercourse", true, false) as MeshInstance3D
            if water != null:
                _apply_safe_water(water)
                applied = true
                return
        await get_tree().process_frame
    push_warning("WaterShaderGuard could not find ForegroundWatercourse")

func _apply_safe_water(water: MeshInstance3D) -> void:
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
    float ripple = sin(UV.x * 9.0 + UV.y * 5.0 + TIME * 0.9) * 0.5 + 0.5;
    ALBEDO = mix(vec3(0.075, 0.19, 0.22), vec3(0.16, 0.34, 0.35), ripple * 0.22);
    ROUGHNESS = 0.18;
    METALLIC = 0.08;
    SPECULAR = 0.78;
    ALPHA = 0.82;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    water.material_override = material
