extends Node

# Natural-colour and foreground finish for the procedural fallback presentation.
# Final ProductionVisual GLBs are never restyled here. This pass only prevents the
# current fallback animals/grass/water from reading as neon primitives on mobile.

var scene_root: Node3D
var apply_timer := 0.0
var palette_applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 2500
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(420):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            if scene_root.find_child("BabyHippo", true, false) != null:
                break
        await get_tree().process_frame
    if scene_root == null:
        push_warning("NaturalPresentationFinish could not bind to the sanctuary")
        return

    for _frame in range(16):
        await get_tree().process_frame
    _apply_finish()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or not is_instance_valid(scene_root):
        return
    apply_timer -= delta
    if apply_timer <= 0.0:
        apply_timer = 1.0
        _apply_finish()

func _apply_finish() -> void:
    _apply_fallback_animal_palette()
    _refine_grass()
    _refine_watercourse()
    _refine_lily_pads()

func _apply_fallback_animal_palette() -> void:
    var hippo := scene_root.find_child("BabyHippo", true, false) as Node3D
    var pig := scene_root.find_child("PorkyPig", true, false) as Node3D
    var dog := scene_root.find_child("BaoSharPei", true, false) as Node3D
    _style_fallback_tree(hippo, "hippo")
    _style_fallback_tree(pig, "pig")
    _style_fallback_tree(dog, "dog")
    palette_applied = true

func _style_fallback_tree(root: Node3D, species: String) -> void:
    if root == null or root.find_child("ProductionVisual", false, false) != null:
        return
    _style_fallback_node(root, species)

func _style_fallback_node(node: Node, species: String) -> void:
    if node is MeshInstance3D:
        _style_fallback_mesh(node as MeshInstance3D, species)
    for child in node.get_children():
        _style_fallback_node(child, species)

func _style_fallback_mesh(mesh_instance: MeshInstance3D, species: String) -> void:
    var part := String(mesh_instance.name).to_lower()
    if "eye" in part or "nostril" in part or part == "nose" or "mouth" in part or "lip" in part or "toe" in part or "hoof" in part or "paw" in part:
        return

    var material := mesh_instance.material_override
    if not (material is ShaderMaterial):
        return
    var shader_material := material as ShaderMaterial
    if shader_material.shader == null or shader_material.shader.code.find("uniform vec4 base_color") < 0:
        return

    var natural := Color(0.22, 0.16, 0.18)
    match species:
        "hippo":
            natural = Color(0.205, 0.145, 0.170)
            if "snout" in part or "cheek" in part or "jowl" in part or "belly" in part or "chin" in part:
                natural = Color(0.295, 0.195, 0.215)
            elif "fold" in part or "brow" in part:
                natural = Color(0.185, 0.130, 0.155)
        "pig":
            natural = Color(0.48, 0.300, 0.285)
            if "snout" in part or "cheek" in part or "jaw" in part:
                natural = Color(0.615, 0.405, 0.385)
        "dog":
            natural = Color(0.43, 0.255, 0.135)
            if "fold" in part:
                natural = Color(0.34, 0.190, 0.100)
            elif "muzzle" in part or "cheek" in part or "jowl" in part or "chin" in part:
                natural = Color(0.315, 0.185, 0.115)
    shader_material.set_shader_parameter("base_color", natural)

func _refine_grass() -> void:
    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass == null or grass.multimesh == null:
        return

    var multi := grass.multimesh
    if not bool(grass.get_meta("natural_grass_scaled", false)):
        for i in range(multi.instance_count):
            var transform := multi.get_instance_transform(i)
            transform.basis = transform.basis.scaled(Vector3(0.58, 0.78, 0.58))
            multi.set_instance_transform(i, transform)
        grass.set_meta("natural_grass_scaled", true)

    if bool(grass.get_meta("natural_grass_material", false)):
        return
    if multi.mesh is QuadMesh:
        var quad := multi.mesh as QuadMesh
        var shader := Shader.new()
        shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
void vertex() {
    float phase = INSTANCE_CUSTOM.x * 6.28318;
    float sway = sin(TIME * 0.82 + phase + VERTEX.x * 5.0) * 0.018;
    VERTEX.x += sway * UV.y;
}
void fragment() {
    float taper = (1.0 - UV.y) * 0.34 + 0.018;
    if (abs(UV.x - 0.5) > taper) { discard; }
    float tip = smoothstep(0.0, 1.0, UV.y);
    vec3 deep = vec3(0.045, 0.095, 0.026);
    vec3 olive = vec3(0.145, 0.185, 0.055);
    vec3 dry = vec3(0.245, 0.225, 0.090);
    ALBEDO = mix(deep, olive, tip * 0.72);
    ALBEDO = mix(ALBEDO, dry, smoothstep(0.72, 1.0, tip) * 0.28);
    ROUGHNESS = 0.94;
    SPECULAR = 0.10;
}
"""
        var material := ShaderMaterial.new()
        material.shader = shader
        quad.material = material
        grass.set_meta("natural_grass_material", true)

func _refine_watercourse() -> void:
    var water := scene_root.find_child("ForegroundWatercourse", true, false) as MeshInstance3D
    if water == null or bool(water.get_meta("natural_water", false)):
        return

    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
void vertex() {
    float wave_a = sin((VERTEX.x + TIME * 0.22) * 1.65) * 0.010;
    float wave_b = cos((VERTEX.z - TIME * 0.17) * 2.10) * 0.007;
    VERTEX.y += wave_a + wave_b;
}
void fragment() {
    float broad = sin(UV.x * 8.0 + UV.y * 5.0 + TIME * 0.35) * 0.5 + 0.5;
    float fine = sin(UV.x * 28.0 - UV.y * 19.0 + TIME * 0.62) * 0.5 + 0.5;
    vec3 river_dark = vec3(0.055, 0.105, 0.095);
    vec3 river_mid = vec3(0.095, 0.185, 0.165);
    vec3 silt = vec3(0.145, 0.125, 0.080);
    vec3 water_color = mix(river_dark, river_mid, broad * 0.46);
    water_color = mix(water_color, silt, fine * 0.12);
    ALBEDO = water_color;
    ROUGHNESS = 0.28;
    METALLIC = 0.0;
    SPECULAR = 0.62;
    ALPHA = 0.88;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    water.material_override = material
    water.set_meta("natural_water", true)

func _refine_lily_pads() -> void:
    var pads := scene_root.find_children("LilyPad*", "MeshInstance3D", true, false)
    for pad_node in pads:
        if not (pad_node is MeshInstance3D):
            continue
        var pad := pad_node as MeshInstance3D
        if bool(pad.get_meta("natural_pad", false)):
            continue
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.065, 0.205, 0.070)
        material.roughness = 0.84
        material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
        pad.material_override = material
        pad.set_meta("natural_pad", true)
