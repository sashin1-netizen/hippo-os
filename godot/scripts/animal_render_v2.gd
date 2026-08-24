extends Node

var host
var animal_entries = []
var skin_shader

func _ready():
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _build_skin_shader()
    _prepare_animals()

func _process(delta):
    if animal_entries.is_empty():
        return
    var now = Time.get_ticks_msec() / 1000.0
    for entry in animal_entries:
        var model = entry.get("model", null)
        if model == null or not is_instance_valid(model):
            continue
        var base_y = float(entry.get("base_y", model.position.y))
        var phase = float(entry.get("phase", 0.0))
        var breath_speed = float(entry.get("breath_speed", 1.0))
        var breath_amp = float(entry.get("breath_amp", 0.006))
        var target_y = base_y + sin(now * breath_speed + phase) * breath_amp
        model.position.y = lerp(model.position.y, target_y, min(delta * 3.0, 1.0))

func _build_skin_shader():
    skin_shader = Shader.new()
    skin_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness_base = 0.62;
uniform float moisture = 0.15;
uniform float mud_amount = 0.0;
uniform float pore_scale = 18.0;
uniform float wrinkle_strength = 0.05;
uniform float fold_displacement = 0.001;
uniform float custom_warmth = 0.5;
uniform float pattern_strength = 0.25;
varying vec3 local_pos;
float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float fold_pattern(vec3 p) {
    float primary = sin(p.y * 31.0 + sin(p.z * 13.0) * 1.6 + p.x * 4.0);
    float secondary = sin(p.y * 18.0 - p.x * 10.0 + p.z * 3.2) * 0.35;
    return smoothstep(0.58, 0.98, (primary + secondary) * 0.5 + 0.5);
}
void vertex() {
    float fold = fold_pattern(VERTEX) * wrinkle_strength;
    VERTEX += NORMAL * fold * fold_displacement;
    local_pos = VERTEX;
}
void fragment() {
    float fine = hash31(floor(local_pos * pore_scale * 7.0));
    float broad = hash31(floor(local_pos * pore_scale));
    float pores = mix(broad, fine, 0.42) - 0.5;
    float folds = fold_pattern(local_pos) * wrinkle_strength;

    vec3 vertex_skin = clamp(COLOR.rgb, vec3(0.015), vec3(1.0));
    vec3 cool_tint = vec3(0.94, 0.97, 1.045);
    vec3 warm_tint = vec3(1.07, 1.01, 0.90);
    vec3 user_tint = mix(cool_tint, warm_tint, clamp(custom_warmth, 0.0, 1.0));
    float custom_pattern = (hash31(floor(local_pos * 4.8)) - 0.5) * pattern_strength * 0.14;
    vec3 shaded = base_color.rgb * vertex_skin * user_tint * (0.985 + pores * 0.055 + custom_pattern);
    shaded *= 1.0 - folds * 0.15;

    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
    shaded += vec3(0.018, 0.014, 0.012) * fresnel * moisture;

    float lower_body = 1.0 - smoothstep(-0.10, 0.72, local_pos.y);
    float mud_noise = 0.72 + hash31(floor(local_pos * 13.0)) * 0.28;
    float mud_mask = clamp(mud_amount * lower_body * mud_noise, 0.0, 0.92);
    shaded = mix(shaded, vec3(0.115, 0.066, 0.031), mud_mask * 0.82);

    ALBEDO = clamp(shaded, vec3(0.0), vec3(1.0));
    ROUGHNESS = clamp(
        roughness_base - moisture * 0.20 + pores * 0.09 + folds * 0.10 + mud_mask * 0.12,
        0.18,
        0.98
    );
    SPECULAR = clamp(0.30 + moisture * 0.28 + fresnel * 0.12 - mud_mask * 0.08, 0.18, 0.75);
}
"""

func _prepare_animals():
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    var index = 0
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor == null:
            continue
        var model = actor.get("production_model")
        if not model is Node3D:
            continue
        var species = str(actor.get("species_id"))
        _apply_model_materials(model, species)
        animal_entries.append({
            "actor": actor,
            "model": model,
            "base_y": model.position.y,
            "phase": float(index) * 1.91 + 0.4,
            "breath_speed": _breath_speed(species),
            "breath_amp": _breath_amplitude(species)
        })
        index += 1

func _apply_model_materials(node, species):
    if node is MeshInstance3D:
        _apply_mesh_materials(node, species)
    for child in node.get_children():
        _apply_model_materials(child, species)

func _apply_mesh_materials(mesh_instance, species):
    var count = mesh_instance.get_surface_override_material_count()
    for surface_index in range(count):
        var source = mesh_instance.get_active_material(surface_index)
        if source == null:
            continue
        var surface_name = (str(mesh_instance.name) + " " + str(source.resource_name)).to_lower()
        if "eye" in surface_name:
            mesh_instance.set_surface_override_material(surface_index, _eye_material(source))
            continue
        if "nose" in surface_name:
            mesh_instance.set_surface_override_material(surface_index, _nose_material(source, species))
            continue
        if not source is StandardMaterial3D:
            continue
        var material = ShaderMaterial.new()
        material.shader = skin_shader
        material.set_shader_parameter("base_color", source.albedo_color)
        material.set_shader_parameter("roughness_base", clamp(float(source.roughness), 0.28, 0.92))
        material.set_shader_parameter("moisture", _species_moisture(species, surface_name))
        material.set_shader_parameter("mud_amount", 0.0)
        material.set_shader_parameter("pore_scale", _species_pore_scale(species))
        material.set_shader_parameter("wrinkle_strength", _species_wrinkles(species, surface_name))
        material.set_shader_parameter("fold_displacement", _species_fold_displacement(species, surface_name))
        material.set_shader_parameter("custom_warmth", 0.5)
        material.set_shader_parameter("pattern_strength", 0.25)
        mesh_instance.set_surface_override_material(surface_index, material)

func _eye_material(_source):
    var material = StandardMaterial3D.new()
    # The creature compiler carries the authored eye colour in COLOR_0.
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.028
    material.metallic = 0.0
    material.clearcoat_enabled = true
    material.clearcoat_roughness = 0.06
    return material

func _nose_material(_source, species):
    var material = StandardMaterial3D.new()
    # Preserve the species-specific nose/snout palette from vertex colours.
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.10 if species != "shar_pei" else 0.14
    material.metallic = 0.0
    material.clearcoat_enabled = true
    material.clearcoat_roughness = 0.18
    return material

func _species_moisture(species, surface_name):
    if "muzzle" in surface_name:
        return 0.52
    if species == "pygmy_hippo":
        return 0.46
    if species == "pig":
        return 0.25
    return 0.10

func _species_pore_scale(species):
    if species == "pygmy_hippo":
        return 12.0
    if species == "pig":
        return 18.0
    return 23.0

func _species_wrinkles(species, surface_name):
    if species == "shar_pei":
        if "head" in surface_name or "neck" in surface_name:
            return 0.62
        if "body" in surface_name:
            return 0.42
        return 0.28
    if species == "pygmy_hippo":
        return 0.07
    return 0.04

func _species_fold_displacement(species, surface_name):
    if species == "shar_pei":
        if "head" in surface_name or "neck" in surface_name:
            return 0.022
        if "body" in surface_name:
            return 0.014
        return 0.006
    if species == "pygmy_hippo":
        return 0.004
    return 0.0025

func _breath_speed(species):
    if species == "pygmy_hippo":
        return 1.45
    if species == "pig":
        return 1.70
    return 1.95

func _breath_amplitude(species):
    if species == "pygmy_hippo":
        return 0.008
    if species == "pig":
        return 0.006
    return 0.005
