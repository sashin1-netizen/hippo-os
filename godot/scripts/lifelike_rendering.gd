extends Node

# Mobile-conscious lifelike rendering pass.
# This does not pretend the procedural companions are final sculpted production rigs.
# It removes the flat/toy material look with layered skin/coat shading, micro detail,
# wet/mud response, glossy facial detail, richer ground/water/mud surfaces and
# stronger shadow/light defaults while staying on Godot's Compatibility renderer.

var scene_root: Node3D
var hippo: Node3D
var pig: Node3D
var dog: Node3D
var hippo_surface_materials: Array[ShaderMaterial] = []
var update_timer := 0.0
var applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 170
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(300):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            hippo = scene_root.find_child("BabyHippo", true, false) as Node3D
            pig = scene_root.find_child("PorkyPig", true, false) as Node3D
            dog = scene_root.find_child("BaoSharPei", true, false) as Node3D
            if hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null or hippo == null or pig == null or dog == null:
        push_warning("LifelikeRendering could not bind to all companions")
        return

    # Allow later visual autoloads to finish creating their world nodes first.
    await get_tree().process_frame
    await get_tree().process_frame
    _apply_animal_rendering()
    _apply_sanctuary_rendering()
    _tune_lighting()
    applied = true
    set_process(true)

func _process(delta: float) -> void:
    if not applied or scene_root == null:
        return
    update_timer -= delta
    if update_timer <= 0.0:
        update_timer = 0.12
        _sync_hippo_surface_state()

func _apply_animal_rendering() -> void:
    hippo_surface_materials.clear()
    _style_animal_tree(hippo, "hippo")
    _style_animal_tree(pig, "pig")
    _style_animal_tree(dog, "dog")

func _style_animal_tree(root: Node, species: String) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            _style_animal_mesh(child as MeshInstance3D, species)
        _style_animal_tree(child, species)

func _style_animal_mesh(mesh_instance: MeshInstance3D, species: String) -> void:
    var part_name := String(mesh_instance.name).to_lower()
    mesh_instance.set("cast_shadow", 1)

    if "eye" in part_name:
        mesh_instance.material_override = _make_gloss_detail_material(Color(0.018, 0.012, 0.014), 0.10, 0.72)
        return
    if "nostril" in part_name or part_name == "nose":
        mesh_instance.material_override = _make_gloss_detail_material(Color(0.055, 0.025, 0.030), 0.22, 0.48)
        return
    if "mouth" in part_name or "lip" in part_name or "chin" in part_name:
        mesh_instance.material_override = _make_soft_detail_material(Color(0.18, 0.075, 0.082), 0.48)
        return
    if "toe" in part_name or "hoof" in part_name or "paw" in part_name:
        var foot_color := Color(0.16, 0.105, 0.095) if species != "dog" else Color(0.30, 0.18, 0.11)
        mesh_instance.material_override = _make_soft_detail_material(foot_color, 0.66)
        return

    match species:
        "hippo":
            var hippo_color := Color(0.39, 0.285, 0.355)
            if "belly" in part_name or "snout" in part_name or "cheek" in part_name:
                hippo_color = Color(0.535, 0.345, 0.405)
            var material := _make_skin_material(hippo_color, 0.53, 20.0)
            mesh_instance.material_override = material
            hippo_surface_materials.append(material)
        "pig":
            var pig_color := Color(0.72, 0.405, 0.405)
            if "snout" in part_name or "cheek" in part_name:
                pig_color = Color(0.82, 0.515, 0.505)
            mesh_instance.material_override = _make_skin_material(pig_color, 0.67, 27.0)
        "dog":
            var dog_color := Color(0.60, 0.355, 0.19)
            if "fold" in part_name:
                dog_color = Color(0.50, 0.275, 0.14)
            elif "muzzle" in part_name or "cheek" in part_name:
                dog_color = Color(0.47, 0.265, 0.16)
            mesh_instance.material_override = _make_coat_material(dog_color)

func _make_skin_material(color: Color, roughness: float, detail_scale: float) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.45, 0.34, 0.42, 1.0);
uniform float rough_base = 0.55;
uniform float detail_scale = 20.0;
uniform float wetness = 0.0;
uniform float mud = 0.0;
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    for (int i = 0; i < 4; i++) {
        v += value_noise(p) * a;
        p = p * 2.03 + vec2(17.2, 9.7);
        a *= 0.48;
    }
    return v;
}
void fragment() {
    float broad = fbm(UV * detail_scale * 0.22);
    float pores = value_noise(UV * detail_scale * 2.8);
    float pores2 = value_noise(UV * detail_scale * 7.5 + vec2(2.1, 8.4));
    vec3 skin = base_color.rgb * mix(0.86, 1.08, broad);
    skin *= mix(0.94, 1.035, pores);
    float mud_mask = clamp(mud * (0.48 + broad * 0.62), 0.0, 0.86);
    skin = mix(skin, vec3(0.16, 0.095, 0.052), mud_mask);
    ALBEDO = skin;
    float micro = (pores - 0.5) * 0.030 + (pores2 - 0.5) * 0.012;
    NORMAL = normalize(NORMAL + vec3(micro, -micro * 0.72, 0.0));
    ROUGHNESS = clamp(mix(rough_base, 0.24, wetness) + mud * 0.16 + (pores2 - 0.5) * 0.08, 0.18, 0.98);
    SPECULAR = 0.34 + wetness * 0.22;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("base_color", color)
    material.set_shader_parameter("rough_base", roughness)
    material.set_shader_parameter("detail_scale", detail_scale)
    return material

func _make_coat_material(color: Color) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.62, 0.38, 0.20, 1.0);
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
    float broad = noise2(UV * 18.0);
    float fiber = noise2(vec2(UV.x * 115.0, UV.y * 32.0));
    float fold = smoothstep(0.38, 0.70, noise2(UV * 7.0 + vec2(3.0, 5.0)));
    vec3 coat = base_color.rgb * mix(0.80, 1.08, broad);
    coat *= mix(0.91, 1.02, fiber);
    coat *= mix(1.0, 0.88, fold * 0.20);
    ALBEDO = coat;
    float micro = (fiber - 0.5) * 0.025;
    NORMAL = normalize(NORMAL + vec3(micro, micro * 0.35, 0.0));
    ROUGHNESS = clamp(0.76 + (fiber - 0.5) * 0.10, 0.62, 0.90);
    SPECULAR = 0.28;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("base_color", color)
    return material

func _make_gloss_detail_material(color: Color, roughness: float, specular: float) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.02, 0.01, 0.01, 1.0);
uniform float rough_value = 0.12;
uniform float spec_value = 0.65;
void fragment() {
    ALBEDO = base_color.rgb;
    ROUGHNESS = rough_value;
    SPECULAR = spec_value;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("base_color", color)
    material.set_shader_parameter("rough_value", roughness)
    material.set_shader_parameter("spec_value", specular)
    return material

func _make_soft_detail_material(color: Color, roughness: float) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.2, 0.08, 0.08, 1.0);
uniform float rough_value = 0.5;
void fragment() {
    float variation = sin(UV.x * 49.0) * sin(UV.y * 37.0) * 0.025;
    ALBEDO = base_color.rgb * (1.0 + variation);
    ROUGHNESS = rough_value;
    SPECULAR = 0.30;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("base_color", color)
    material.set_shader_parameter("rough_value", roughness)
    return material

func _apply_sanctuary_rendering() -> void:
    var ground := scene_root.find_child("SanctuaryGroundFinish", true, false) as MeshInstance3D
    if ground != null:
        ground.material_override = _make_ground_material()
        ground.set("cast_shadow", 1)

    var water := scene_root.find_child("PremiumWaterSurface", true, false) as MeshInstance3D
    if water != null:
        water.material_override = _make_water_material()

    var mud_surface := scene_root.find_child("PremiumMudSurface", true, false) as MeshInstance3D
    if mud_surface != null:
        mud_surface.material_override = _make_mud_material()

    # Existing generated habitat geometry remains intentionally lightweight, but
    # enabling shadows on it removes the flat diorama appearance.
    var polish_world := scene_root.find_child("PremiumExperienceWorld", true, false)
    if polish_world != null:
        _enable_mesh_shadows(polish_world)
    var visual_world := scene_root.find_child("SanctuaryVisualPolish", true, false)
    if visual_world != null:
        _enable_mesh_shadows(visual_world)

func _enable_mesh_shadows(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            (child as MeshInstance3D).set("cast_shadow", 1)
        _enable_mesh_shadows(child)

func _make_ground_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    for (int i = 0; i < 5; i++) {
        v += noise2(p) * a;
        p = p * 2.07 + vec2(11.4, 4.9);
        a *= 0.47;
    }
    return v;
}
void vertex() {
    float broad = noise2(VERTEX.xz * 0.42);
    float fine = noise2(VERTEX.xz * 1.9 + vec2(7.0, 3.0));
    VERTEX.y += (broad - 0.5) * 0.050 + (fine - 0.5) * 0.014;
}
void fragment() {
    float organic = fbm(UV * 18.0);
    float moss = fbm(UV * 8.0 + vec2(8.0, 2.0));
    float debris = noise2(UV * 95.0);
    vec3 soil = vec3(0.115, 0.090, 0.052);
    vec3 green = vec3(0.055, 0.205, 0.080);
    vec3 lush = vec3(0.085, 0.285, 0.105);
    vec3 color = mix(soil, green, smoothstep(0.28, 0.72, organic));
    color = mix(color, lush, smoothstep(0.62, 0.90, moss) * 0.45);
    color *= mix(0.90, 1.05, debris);
    ALBEDO = color;
    float micro = (debris - 0.5) * 0.035;
    NORMAL = normalize(NORMAL + vec3(micro, -micro * 0.6, 0.0));
    ROUGHNESS = clamp(0.89 + (debris - 0.5) * 0.08, 0.78, 0.98);
    SPECULAR = 0.20;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _make_water_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled, diffuse_burley, specular_schlick_ggx;
float wave(vec2 p, float t) {
    return sin(p.x * 7.0 + t * 1.25) * 0.55 + cos(p.y * 8.5 - t * 0.95) * 0.45;
}
void vertex() {
    float w = wave(VERTEX.xz, TIME);
    float w2 = sin((VERTEX.x + VERTEX.z) * 12.0 + TIME * 1.8);
    VERTEX.y += w * 0.016 + w2 * 0.004;
}
void fragment() {
    float w = wave(UV * 4.0, TIME);
    float glint = sin((UV.x * 1.4 + UV.y) * 95.0 + TIME * 2.0) * 0.5 + 0.5;
    vec3 deep = vec3(0.018, 0.115, 0.145);
    vec3 shallow = vec3(0.055, 0.315, 0.345);
    ALBEDO = mix(deep, shallow, 0.42 + w * 0.055);
    ROUGHNESS = mix(0.11, 0.20, glint);
    SPECULAR = 0.72;
    ALPHA = 0.80;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _make_mud_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(71.3, 241.7))) * 43758.5453);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void vertex() {
    float soft = noise2(VERTEX.xz * 2.5 + vec2(TIME * 0.035, 0.0));
    VERTEX.y += (soft - 0.5) * 0.014;
}
void fragment() {
    float broad = noise2(UV * 13.0);
    float fine = noise2(UV * 70.0 + vec2(4.0, 9.0));
    vec3 dark = vec3(0.105, 0.058, 0.030);
    vec3 wet = vec3(0.225, 0.125, 0.055);
    ALBEDO = mix(dark, wet, broad * 0.72);
    NORMAL = normalize(NORMAL + vec3((fine - 0.5) * 0.03, (broad - 0.5) * 0.02, 0.0));
    ROUGHNESS = mix(0.72, 0.36, smoothstep(0.63, 0.92, broad));
    SPECULAR = 0.40;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _tune_lighting() -> void:
    _tune_lights_recursive(scene_root)
    # Compatibility renderer: use modest MSAA rather than expensive post effects.
    get_viewport().set("msaa_3d", 1)

func _tune_lights_recursive(root: Node) -> void:
    for child in root.get_children():
        if child is DirectionalLight3D:
            var light := child as DirectionalLight3D
            light.set("shadow_enabled", true)
            light.set("shadow_bias", 0.055)
            light.set("shadow_normal_bias", 0.72)
        _tune_lights_recursive(child)

func _sync_hippo_surface_state() -> void:
    var wetness := clampf(_scene_float("wetness", 0.0), 0.0, 1.0)
    var mud := clampf(_scene_float("mud_coat", 0.0), 0.0, 1.0)
    for material in hippo_surface_materials:
        if is_instance_valid(material):
            material.set_shader_parameter("wetness", wetness)
            material.set_shader_parameter("mud", mud)

func _scene_float(property_name: String, fallback: float) -> float:
    if scene_root == null:
        return fallback
    var value: Variant = scene_root.get(property_name)
    if value == null:
        return fallback
    return float(value)
