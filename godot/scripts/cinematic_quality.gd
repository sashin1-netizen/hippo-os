extends Node

# Final mobile-conscious presentation pass for Hippo OS.
# Production GLBs remain authoritative when present. This pass improves the source-tree
# procedural fallback and enables high-quality edge treatment without forcing a phone
# to render a 3840x2160 framebuffer. 4K source art is expected to mip down naturally.

const BODY_NAMES := {
    "hippo": "BabyHippo",
    "pig": "PorkyPig",
    "dog": "BaoSharPei",
}

var scene_root: Node3D
var applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 360
    call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
    _configure_viewport()

    for _attempt in range(360):
        var current := get_tree().current_scene
        if current is Node3D:
            scene_root = current as Node3D
            if _all_bodies_present():
                break
        await get_tree().process_frame

    if scene_root == null or not _all_bodies_present():
        push_warning("CinematicQuality could not bind to all companion bodies")
        return

    for _frame in range(8):
        await get_tree().process_frame

    for species_value in BODY_NAMES.keys():
        var species := String(species_value)
        var body := scene_root.find_child(String(BODY_NAMES[species]), true, false) as Node3D
        if body == null:
            continue
        if body.find_child("ProductionVisual", false, false) != null:
            continue
        _upgrade_fallback_meshes(body)
        _add_optical_detail(body, species)

    applied = true

func _configure_viewport() -> void:
    var viewport := get_viewport()
    if viewport == null:
        return
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

func _all_bodies_present() -> bool:
    if scene_root == null:
        return false
    for body_name in BODY_NAMES.values():
        if scene_root.find_child(String(body_name), true, false) == null:
            return false
    return true

func _upgrade_fallback_meshes(body: Node3D) -> void:
    _upgrade_mesh_tree(body)

func _upgrade_mesh_tree(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh_instance := child as MeshInstance3D
            if mesh_instance.mesh is SphereMesh:
                var old_sphere := mesh_instance.mesh as SphereMesh
                var sphere := old_sphere.duplicate() as SphereMesh
                if sphere != null:
                    sphere.radial_segments = maxi(sphere.radial_segments, 48)
                    sphere.rings = maxi(sphere.rings, 24)
                    mesh_instance.mesh = sphere
            mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        _upgrade_mesh_tree(child)

func _add_optical_detail(body: Node3D, species: String) -> void:
    var visual := body.get_node_or_null("Visual") as Node3D
    if visual == null:
        for child in body.get_children():
            if child is Node3D and not child is CollisionShape3D:
                visual = child as Node3D
                break
    if visual == null or visual.find_child("CinematicOpticalDetail", false, false) != null:
        return

    var detail_root := Node3D.new()
    detail_root.name = "CinematicOpticalDetail"
    visual.add_child(detail_root)

    match species:
        "hippo":
            _build_hippo_optics(detail_root)
        "pig":
            _build_pig_optics(detail_root)
        "dog":
            _build_dog_optics(detail_root)

func _build_hippo_optics(root: Node3D) -> void:
    var cornea := _material(Color(0.040, 0.025, 0.030), 0.06)
    var catchlight := _material(Color(0.93, 0.96, 0.98), 0.04)
    var inner_ear := _material(Color(0.45, 0.245, 0.305), 0.48)
    var lip := _material(Color(0.22, 0.095, 0.115), 0.42)

    _sphere(root, "CorneaL", Vector3(1.555, 0.79, -0.495), Vector3(0.108, 0.104, 0.072), cornea)
    _sphere(root, "CorneaR", Vector3(1.555, 0.79, 0.495), Vector3(0.108, 0.104, 0.072), cornea)
    _sphere(root, "CatchlightL", Vector3(1.615, 0.835, -0.542), Vector3(0.022, 0.022, 0.012), catchlight)
    _sphere(root, "CatchlightR", Vector3(1.615, 0.835, 0.542), Vector3(0.022, 0.022, 0.012), catchlight)
    _sphere(root, "InnerEarL", Vector3(1.000, 1.045, -0.565), Vector3(0.125, 0.160, 0.055), inner_ear)
    _sphere(root, "InnerEarR", Vector3(1.000, 1.045, 0.565), Vector3(0.125, 0.160, 0.055), inner_ear)
    _sphere(root, "MouthCornerL", Vector3(1.885, 0.205, -0.335), Vector3(0.100, 0.038, 0.055), lip)
    _sphere(root, "MouthCornerR", Vector3(1.885, 0.205, 0.335), Vector3(0.100, 0.038, 0.055), lip)

func _build_pig_optics(root: Node3D) -> void:
    var cornea := _material(Color(0.035, 0.022, 0.018), 0.07)
    var catchlight := _material(Color(0.95, 0.97, 0.98), 0.04)
    var snout_pad := _material(Color(0.76, 0.43, 0.44), 0.50)
    var inner_ear := _material(Color(0.69, 0.36, 0.37), 0.56)

    _sphere(root, "CorneaL", Vector3(1.305, 0.765, -0.402), Vector3(0.082, 0.080, 0.052), cornea)
    _sphere(root, "CorneaR", Vector3(1.305, 0.765, 0.402), Vector3(0.082, 0.080, 0.052), cornea)
    _sphere(root, "CatchlightL", Vector3(1.350, 0.800, -0.438), Vector3(0.017, 0.017, 0.010), catchlight)
    _sphere(root, "CatchlightR", Vector3(1.350, 0.800, 0.438), Vector3(0.017, 0.017, 0.010), catchlight)
    _sphere(root, "SnoutPad", Vector3(1.665, 0.435, 0.0), Vector3(0.105, 0.205, 0.300), snout_pad)
    _sphere(root, "InnerEarL", Vector3(0.935, 1.040, -0.455), Vector3(0.115, 0.225, 0.045), inner_ear)
    _sphere(root, "InnerEarR", Vector3(0.935, 1.040, 0.455), Vector3(0.115, 0.225, 0.045), inner_ear)

func _build_dog_optics(root: Node3D) -> void:
    var cornea := _material(Color(0.028, 0.020, 0.014), 0.06)
    var catchlight := _material(Color(0.95, 0.97, 0.98), 0.04)
    var nose_highlight := _material(Color(0.055, 0.042, 0.035), 0.13)
    var inner_ear := _material(Color(0.45, 0.235, 0.185), 0.66)

    _sphere(root, "CorneaL", Vector3(1.330, 0.930, -0.410), Vector3(0.078, 0.073, 0.050), cornea)
    _sphere(root, "CorneaR", Vector3(1.330, 0.930, 0.410), Vector3(0.078, 0.073, 0.050), cornea)
    _sphere(root, "CatchlightL", Vector3(1.370, 0.963, -0.445), Vector3(0.016, 0.016, 0.010), catchlight)
    _sphere(root, "CatchlightR", Vector3(1.370, 0.963, 0.445), Vector3(0.016, 0.016, 0.010), catchlight)
    _sphere(root, "NoseMoisture", Vector3(1.805, 0.665, 0.0), Vector3(0.155, 0.105, 0.145), nose_highlight)
    _sphere(root, "InnerEarL", Vector3(0.955, 1.215, -0.448), Vector3(0.095, 0.190, 0.040), inner_ear)
    _sphere(root, "InnerEarR", Vector3(0.955, 1.215, 0.448), Vector3(0.095, 0.190, 0.040), inner_ear)

func _sphere(parent: Node3D, part_name: String, local_position: Vector3, local_scale: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 48
    mesh.rings = 24
    part.mesh = mesh
    part.position = local_position
    part.scale = local_scale
    part.material_override = material
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(part)
    return part

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.0
    return material
