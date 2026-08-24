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
uniform vec4 base_color : source_color = vec4(0.5, 0.4, 0.4, 1.0);
uniform float roughness_base = 0.62;
uniform float moisture = 0.15;
uniform float pore_scale = 18.0;
uniform float wrinkle_strength = 0.05;
varying vec3 local_pos;
float hash31(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
void vertex() {
    local_pos = VERTEX;
}
void fragment() {
    float fine = hash31(floor(local_pos * pore_scale * 7.0));
    float broad = hash31(floor(local_pos * pore_scale));
    float pores = mix(broad, fine, 0.42) - 0.5;
    float fold_wave = sin(local_pos.y * 31.0 + sin(local_pos.z * 13.0) * 1.6 + local_pos.x * 4.0);
    float folds = smoothstep(0.63, 0.98, fold_wave * 0.5 + 0.5) * wrinkle_strength;
    vec3 shaded = base_color.rgb * (0.965 + pores * 0.075);
    shaded *= 1.0 - folds * 0.16;
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
    shaded += vec3(0.018, 0.014, 0.012) * fresnel * moisture;
    ALBEDO = clamp(shaded, vec3(0.0), vec3(1.0));
    ROUGHNESS = clamp(roughness_base - moisture * 0.20 + pores * 0.09 + folds * 0.08, 0.18, 0.96);
    SPECULAR = clamp(0.30 + moisture * 0.28 + fresnel * 0.12, 0.2, 0.75);
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
        material.set_shader_parameter("pore_scale", _species_pore_scale(species))
        material.set_shader_parameter("wrinkle_strength", _species_wrinkles(species, surface_name))
        mesh_instance.set_surface_override_material(surface_index, material)

func _eye_material(source):
    var material = StandardMaterial3D.new()
    var source_color = Color(0.055, 0.038, 0.028)
    if source is StandardMaterial3D:
        source_color = source.albedo_color
    material.albedo_color = source_color.darkened(0.30)
    material.roughness = 0.035
    material.metallic = 0.0
    return material

func _nose_material(source, species):
    var material = StandardMaterial3D.new()
    var source_color = Color(0.10, 0.075, 0.065)
    if source is StandardMaterial3D:
        source_color = source.albedo_color
    material.albedo_color = source_color
    material.roughness = 0.12 if species != "shar_pei" else 0.16
    material.metallic = 0.0
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
            return 0.48
        if "body" in surface_name:
            return 0.31
        return 0.22
    if species == "pygmy_hippo":
        return 0.06
    return 0.035

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
