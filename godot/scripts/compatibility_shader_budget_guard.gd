extends Node

# Early OpenGL/Compatibility safety net for Android emulators and low-end fallback
# devices. It deliberately does nothing on the production Mobile/Vulkan renderer.
#
# SwiftShader exposes a very small fragment-uniform budget. Godot's lit spatial
# material variants can exceed that budget before the later presentation/fallback
# directors get a chance to hide the production geometry. This autoload therefore
# watches nodes as they enter the SceneTree and replaces their visible material path
# with a texture-preserving unshaded StandardMaterial3D before the first useful draw.

const RESCAN_INTERVAL := 0.08
const ACTIVE_SECONDS := 45.0

var active := false
var elapsed := 0.0
var rescan_clock := 0.0
var converted := 0
var safe_material_cache: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = -100000
    active = _is_compatibility_renderer()
    if not active:
        set_process(false)
        return

    # node_added is emitted synchronously as runtime geometry is inserted, which lets
    # us harden dynamically constructed meshes before normal frame presentation.
    get_tree().node_added.connect(_on_node_added)
    _harden_tree(get_tree().root)
    print("HippoOS compatibility shader budget guard active")

func _process(delta: float) -> void:
    if not active:
        return
    elapsed += delta
    rescan_clock -= delta
    if rescan_clock <= 0.0:
        rescan_clock = RESCAN_INTERVAL
        var current := get_tree().current_scene
        if current != null:
            _harden_tree(current)
    if elapsed >= ACTIVE_SECONDS:
        set_process(false)
        print("HippoOS compatibility shader guard stabilized %d mesh instances" % converted)

func _on_node_added(node: Node) -> void:
    if not active:
        return
    if node is MeshInstance3D:
        _harden_mesh(node as MeshInstance3D)
    elif node is GeometryInstance3D:
        _harden_geometry(node as GeometryInstance3D)

func _harden_tree(root: Node) -> void:
    if root == null:
        return
    if root is MeshInstance3D:
        _harden_mesh(root as MeshInstance3D)
    elif root is GeometryInstance3D:
        _harden_geometry(root as GeometryInstance3D)
    for child in root.get_children():
        _harden_tree(child)

func _harden_geometry(geometry: GeometryInstance3D) -> void:
    geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _harden_mesh(mesh_instance: MeshInstance3D) -> void:
    if mesh_instance == null or not is_instance_valid(mesh_instance):
        return
    _harden_geometry(mesh_instance)

    # Do not repeatedly replace a material already prepared by this guard.
    if mesh_instance.has_meta("hippo_os_compat_safe_material"):
        return

    var source: Material = mesh_instance.material_override
    if source == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
        source = mesh_instance.mesh.surface_get_material(0)

    var safe := _safe_material(source, mesh_instance.name)
    mesh_instance.material_override = safe
    mesh_instance.set_meta("hippo_os_compat_safe_material", true)
    converted += 1

func _safe_material(source: Material, node_name: String) -> StandardMaterial3D:
    var key := "fallback"
    if source != null:
        key = "%s:%d" % [source.resource_path, source.get_instance_id()]
    if safe_material_cache.has(key):
        return safe_material_cache[key] as StandardMaterial3D

    var safe := StandardMaterial3D.new()
    safe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    safe.albedo_color = _fallback_color(node_name)
    safe.roughness = 1.0
    safe.metallic = 0.0

    if source is BaseMaterial3D:
        var base := source as BaseMaterial3D
        safe.albedo_color = base.albedo_color
        safe.albedo_texture = base.albedo_texture
        safe.uv1_scale = base.uv1_scale
        safe.uv1_offset = base.uv1_offset
        safe.texture_filter = base.texture_filter
        safe.transparency = base.transparency
        safe.cull_mode = base.cull_mode

    safe_material_cache[key] = safe
    return safe

func _fallback_color(node_name: String) -> Color:
    var lower := node_name.to_lower()
    if "water" in lower or "pond" in lower:
        return Color(0.12, 0.38, 0.48)
    if "mud" in lower or "ground" in lower or "bank" in lower:
        return Color(0.35, 0.31, 0.20)
    if "tree" in lower or "bush" in lower or "reed" in lower or "plant" in lower:
        return Color(0.22, 0.43, 0.20)
    if "rock" in lower or "mountain" in lower or "ridge" in lower:
        return Color(0.39, 0.38, 0.34)
    if "eye" in lower or "nostril" in lower:
        return Color(0.035, 0.025, 0.03)
    if "belly" in lower or "snout" in lower or "chin" in lower:
        return Color(0.66, 0.43, 0.50)
    return Color(0.46, 0.36, 0.42)

func _is_compatibility_renderer() -> bool:
    var method := String(RenderingServer.get_current_rendering_method()).to_lower()
    return "compatibility" in method or "gl_compatibility" in method
