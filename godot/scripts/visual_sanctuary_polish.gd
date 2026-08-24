extends Node

# Lightweight sanctuary art/VFX pass for the Compatibility renderer.

const POND_POS: Vector3 = Vector3(3.7, 0.8, 2.5)
const MUD_POS: Vector3 = Vector3(-3.7, 0.8, 2.8)

var scene_root: Node = null
var hippo: CharacterBody3D = null
var polish_root: Node3D = null
var fill_light: DirectionalLight3D = null
var water_surface: MeshInstance3D = null
var mud_surface: MeshInstance3D = null
var lily_pads: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var effect_timer: float = 0.0
var last_action: String = ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 80

func _process(delta: float) -> void:
    _ensure_binding()
    if not is_instance_valid(scene_root) or not is_instance_valid(hippo):
        return

    _update_light()
    _animate_lily_pads()
    _update_ripples(delta)
    effect_timer = maxf(0.0, effect_timer - delta)

    var action: String = str(scene_root.get("current_action"))
    if action == "drink" and hippo.global_position.distance_to(POND_POS) < 1.25 and effect_timer <= 0.0:
        _spawn_ripple(POND_POS + Vector3(randf_range(-0.55, 0.55), -0.66, randf_range(-0.38, 0.38)), Color(0.52, 0.86, 0.96, 0.58), false)
        effect_timer = randf_range(0.48, 0.85)
    elif action == "mud" and hippo.global_position.distance_to(MUD_POS) < 1.25 and effect_timer <= 0.0:
        _spawn_ripple(MUD_POS + Vector3(randf_range(-0.42, 0.42), -0.68, randf_range(-0.30, 0.30)), Color(0.30, 0.19, 0.10, 0.62), true)
        effect_timer = randf_range(0.42, 0.72)
    elif action != last_action and action == "play" and hippo.global_position.distance_to(POND_POS) < 2.0:
        _spawn_ripple(POND_POS + Vector3(0.0, -0.66, 0.0), Color(0.62, 0.90, 1.0, 0.54), false)
    last_action = action

func _ensure_binding() -> void:
    var current_scene: Node = get_tree().current_scene
    if current_scene == null:
        return
    if scene_root == current_scene and is_instance_valid(hippo):
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
    if hippo == null:
        return
    _build_visual_pass()

func _build_visual_pass() -> void:
    if is_instance_valid(polish_root):
        polish_root.queue_free()
    polish_root = Node3D.new()
    polish_root.name = "SanctuaryVisualPolish"
    scene_root.add_child(polish_root)
    lily_pads.clear()
    ripples.clear()
    _build_water()
    _build_mud()
    _build_vegetation()
    _build_lily_pads()
    _build_fill_light()

func _build_water() -> void:
    water_surface = MeshInstance3D.new()
    water_surface.name = "PremiumWaterSurface"
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.08
    water_surface.mesh = mesh
    water_surface.scale = Vector3(3.0, 0.08, 2.1)
    water_surface.position = Vector3(POND_POS.x, 0.07, POND_POS.z)

    var shader: Shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled;
void vertex() {
    float wave_a = sin(VERTEX.x * 5.0 + TIME * 1.35);
    float wave_b = cos(VERTEX.z * 6.0 - TIME * 1.05);
    VERTEX.y += (wave_a + wave_b) * 0.018;
}
void fragment() {
    float shimmer = sin((UV.x + UV.y) * 18.0 + TIME * 1.6) * 0.5 + 0.5;
    vec3 deep = vec3(0.035, 0.20, 0.27);
    vec3 light_water = vec3(0.09, 0.43, 0.52);
    ALBEDO = mix(deep, light_water, 0.30 + shimmer * 0.16);
    ROUGHNESS = 0.16;
    METALLIC = 0.04;
    ALPHA = 0.78;
}
"""
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    water_surface.material_override = material
    polish_root.add_child(water_surface)

func _build_mud() -> void:
    mud_surface = MeshInstance3D.new()
    mud_surface.name = "PremiumMudSurface"
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.07
    mud_surface.mesh = mesh
    mud_surface.scale = Vector3(2.0, 0.07, 1.5)
    mud_surface.position = Vector3(MUD_POS.x, 0.075, MUD_POS.z)

    var shader: Shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
    float soft = sin(VERTEX.x * 4.5 + TIME * 0.45) * cos(VERTEX.z * 4.0 - TIME * 0.35);
    VERTEX.y += soft * 0.008;
}
void fragment() {
    float mottled = sin(UV.x * 29.0) * cos(UV.y * 23.0) * 0.5 + 0.5;
    ALBEDO = mix(vec3(0.18, 0.105, 0.055), vec3(0.31, 0.20, 0.10), mottled * 0.35);
    ROUGHNESS = 0.82;
}
"""
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    mud_surface.material_override = material
    polish_root.add_child(mud_surface)

func _build_vegetation() -> void:
    var trunk_material: StandardMaterial3D = _material(Color(0.19, 0.12, 0.07), 0.96)
    var leaf_dark: StandardMaterial3D = _material(Color(0.045, 0.21, 0.09), 0.92)
    var leaf_mid: StandardMaterial3D = _material(Color(0.07, 0.31, 0.13), 0.88)

    for i: int in range(10):
        var angle: float = TAU * float(i) / 10.0 + 0.16
        var base: Vector3 = Vector3(cos(angle) * 7.8, 0.0, sin(angle) * 5.9)
        var trunk: MeshInstance3D = MeshInstance3D.new()
        var trunk_mesh: CylinderMesh = CylinderMesh.new()
        trunk_mesh.top_radius = 0.11
        trunk_mesh.bottom_radius = 0.18
        trunk_mesh.height = 2.6 + sin(float(i) * 1.7) * 0.35
        trunk.mesh = trunk_mesh
        trunk.position = base + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
        trunk.material_override = trunk_material
        polish_root.add_child(trunk)

        var canopy: MeshInstance3D = MeshInstance3D.new()
        canopy.mesh = SphereMesh.new()
        canopy.position = base + Vector3(0.0, trunk_mesh.height + 0.55, 0.0)
        canopy.scale = Vector3(1.05 + float(i % 3) * 0.12, 0.62 + float(i % 2) * 0.10, 0.92 + float((i + 1) % 3) * 0.10)
        canopy.material_override = leaf_dark if i % 2 == 0 else leaf_mid
        polish_root.add_child(canopy)

    for i: int in range(22):
        var angle: float = TAU * float(i) / 22.0 + 0.34
        var radius: float = 6.5 + sin(float(i) * 2.13) * 0.55
        var shrub: MeshInstance3D = MeshInstance3D.new()
        shrub.mesh = SphereMesh.new()
        shrub.position = Vector3(cos(angle) * radius, 0.46, sin(angle) * (radius * 0.76))
        shrub.scale = Vector3(0.58 + float(i % 4) * 0.09, 0.38 + float(i % 3) * 0.06, 0.52 + float((i + 2) % 4) * 0.07)
        shrub.material_override = leaf_mid if i % 3 != 0 else leaf_dark
        polish_root.add_child(shrub)

func _build_lily_pads() -> void:
    var pad_material: StandardMaterial3D = _material(Color(0.10, 0.37, 0.16), 0.74)
    for i: int in range(7):
        var pad: MeshInstance3D = MeshInstance3D.new()
        pad.name = "LilyPad%d" % i
        var mesh: CylinderMesh = CylinderMesh.new()
        mesh.top_radius = 0.25 + float(i % 3) * 0.05
        mesh.bottom_radius = mesh.top_radius
        mesh.height = 0.025
        pad.mesh = mesh
        var angle: float = TAU * float(i) / 7.0 + 0.2
        pad.position = Vector3(POND_POS.x + cos(angle) * (1.05 + float(i % 2) * 0.35), 0.135, POND_POS.z + sin(angle) * (0.72 + float(i % 3) * 0.12))
        pad.material_override = pad_material
        polish_root.add_child(pad)
        lily_pads.append({"node": pad, "base_y": pad.position.y, "phase": float(i) * 0.8})

func _build_fill_light() -> void:
    fill_light = DirectionalLight3D.new()
    fill_light.name = "SanctuaryFillLight"
    fill_light.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
    fill_light.light_energy = 0.24
    fill_light.shadow_enabled = false
    polish_root.add_child(fill_light)

func _update_light() -> void:
    if not is_instance_valid(fill_light):
        return
    var mode: String = "auto"
    var loaded_settings: Variant = scene_root.get("settings")
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        mode = str((loaded_settings as Dictionary).get("day_night_mode", "auto"))
    var daylight: float = 1.0
    if mode == "night":
        daylight = 0.0
    elif mode == "auto":
        var hour: float = float(Time.get_time_dict_from_system().get("hour", 12))
        daylight = clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
    fill_light.light_color = Color(0.36, 0.48, 0.82).lerp(Color(1.0, 0.78, 0.52), daylight)
    fill_light.light_energy = lerpf(0.12, 0.28, daylight)

func _animate_lily_pads() -> void:
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    for pad_data: Dictionary in lily_pads:
        var pad: MeshInstance3D = pad_data.get("node") as MeshInstance3D
        if not is_instance_valid(pad):
            continue
        var position: Vector3 = pad.position
        position.y = float(pad_data.get("base_y", 0.135)) + sin(now * 1.2 + float(pad_data.get("phase", 0.0))) * 0.012
        pad.position = position
        pad.rotation.y = sin(now * 0.35 + float(pad_data.get("phase", 0.0))) * 0.08

func _spawn_ripple(position: Vector3, color: Color, muddy: bool) -> void:
    var ring: MeshInstance3D = MeshInstance3D.new()
    var mesh: TorusMesh = TorusMesh.new()
    mesh.inner_radius = 0.28 if muddy else 0.36
    mesh.outer_radius = 0.34 if muddy else 0.42
    mesh.rings = 24
    mesh.ring_segments = 8
    ring.mesh = mesh
    ring.position = position
    ring.scale = Vector3(0.58, 0.30, 0.58)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.34 if muddy else 0.18
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring.material_override = material
    polish_root.add_child(ring)
    ripples.append({"node": ring, "material": material, "life": 1.0, "muddy": muddy})

func _update_ripples(delta: float) -> void:
    for i: int in range(ripples.size() - 1, -1, -1):
        var ripple: Dictionary = ripples[i]
        var node: MeshInstance3D = ripple.get("node") as MeshInstance3D
        var material: StandardMaterial3D = ripple.get("material") as StandardMaterial3D
        var decay: float = 1.25 if bool(ripple.get("muddy", false)) else 1.05
        var life: float = float(ripple.get("life", 0.0)) - delta * decay
        if life <= 0.0 or not is_instance_valid(node):
            if is_instance_valid(node):
                node.queue_free()
            ripples.remove_at(i)
            continue
        ripple["life"] = life
        ripples[i] = ripple
        var progress: float = 1.0 - life
        var end_radius: float = 2.1 if bool(ripple.get("muddy", false)) else 2.55
        var radius: float = lerpf(0.58, end_radius, progress)
        node.scale = Vector3(radius, 0.30, radius)
        if is_instance_valid(material):
            var color: Color = material.albedo_color
            color.a = clampf(life * 0.58, 0.0, 0.58)
            material.albedo_color = color

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
